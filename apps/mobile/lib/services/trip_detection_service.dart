import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';
import 'local_db.dart';
import 'location_service.dart';

enum TripState { idle, detecting, inTrip, stopping }

// Auto trip detection state machine.
//
// IDLE       -> DETECTING  : first point with speed > kStartSpeedKmh
// DETECTING  -> IN_TRIP    : sustained movement for kDetectDurationSec OR distance > kMinDetectM
// IN_TRIP    -> STOPPING   : speed < kStopSpeedKmh for kStopDebounceSec
// STOPPING   -> IN_TRIP    : speed rises again
// STOPPING   -> IDLE       : slow for kFinalizeDelaySec → finalize if distance > kMinTripM
class TripDetectionService {
  static const double kStartSpeedKmh = 5.0;
  static const double kStopSpeedKmh = 2.0;
  static const int kDetectDurationSec = 30;
  static const int kStopDebounceSec = 60;
  static const int kFinalizeDelaySec = 120;
  static const double kMinDetectM = 200;
  static const double kMinTripM = 300;

  static TripState _state = TripState.idle;
  static TripState get state => _state;

  static String? _activeTripId;
  static String? _activeSegmentId;
  static String? get activeTripId => _activeTripId;

  static Position? _detectingStart;
  static DateTime? _slowSince;
  static double _totalDistanceM = 0;
  static Position? _lastPos;

  static StreamSubscription<Position>? _sub;

  // Notified on state changes so UI can react without polling
  static final StreamController<TripState> _stateController =
      StreamController<TripState>.broadcast();
  static Stream<TripState> get stateStream => _stateController.stream;

  static Future<void> start() async {
    if (_sub != null) return;
    final granted = await LocationService.requestPermission();
    if (!granted) return;
    await LocationService.startTracking();
    _sub = LocationService.positionStream.listen(_onPosition);
  }

  static Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await LocationService.stopTracking();
  }

  static Future<void> _onPosition(Position pos) async {
    final speedKmh = (pos.speed * 3.6).clamp(0, 300).toDouble();

    // Only accumulate distance while a trip candidate is running — otherwise
    // idle wandering counts toward kMinDetectM/kMinTripM.
    if (_state != TripState.idle && _lastPos != null) {
      _totalDistanceM += Geolocator.distanceBetween(
        _lastPos!.latitude, _lastPos!.longitude,
        pos.latitude, pos.longitude,
      );
    }
    _lastPos = pos;

    switch (_state) {
      case TripState.idle:
        if (speedKmh >= kStartSpeedKmh) {
          _setState(TripState.detecting);
          _detectingStart = pos;
          _totalDistanceM = 0;
        }

      case TripState.detecting:
        if (speedKmh < kStartSpeedKmh) {
          _setState(TripState.idle);
          _detectingStart = null;
          _totalDistanceM = 0;
          break;
        }
        final elapsed = pos.timestamp.difference(_detectingStart!.timestamp).inSeconds;
        if (elapsed >= kDetectDurationSec || _totalDistanceM >= kMinDetectM) {
          await _autoStart(pos);
        }

      case TripState.inTrip:
        await _recordPoint(pos);
        if (speedKmh < kStopSpeedKmh) {
          _slowSince ??= DateTime.now();
          final slowSecs = DateTime.now().difference(_slowSince!).inSeconds;
          if (slowSecs >= kStopDebounceSec) {
            _setState(TripState.stopping);
          }
        } else {
          _slowSince = null;
        }

      case TripState.stopping:
        await _recordPoint(pos);
        if (speedKmh >= kStartSpeedKmh) {
          _setState(TripState.inTrip);
          _slowSince = null;
        } else {
          final slowSecs = DateTime.now().difference(_slowSince!).inSeconds;
          if (slowSecs >= kFinalizeDelaySec) {
            await _autoEnd();
          }
        }
    }
  }

  static Future<void> _autoStart(Position pos) async {
    try {
      final trip = await ApiService.startTrip(startTrigger: 'auto_gps');
      _activeTripId = trip['id'] as String;
      _activeSegmentId = null;
      _setState(TripState.inTrip);
      _slowSince = null;
      await _recordPoint(pos);
    } catch (_) {
      // Will retry on next position if backend unreachable
    }
  }

  static Future<void> _autoEnd() async {
    if (_activeTripId == null) return;
    if (_totalDistanceM < kMinTripM) {
      // Trip too short — discard
      try {
        await ApiService.discardTrip(_activeTripId!);
      } catch (_) {}
    } else {
      try {
        await ApiService.endTrip(_activeTripId!, endTrigger: 'auto_gps');
      } catch (_) {}
    }
    _activeTripId = null;
    _activeSegmentId = null;
    _totalDistanceM = 0;
    _slowSince = null;
    _setState(TripState.idle);
  }

  static Future<void> _recordPoint(Position pos) async {
    if (_activeTripId == null) return;

    final speedKmh = (pos.speed * 3.6).clamp(0, 300).toDouble();

    // Buffer locally first
    await LocalDb.insertPoint(
      tripId: _activeTripId!,
      segmentId: _activeSegmentId,
      lat: pos.latitude,
      lon: pos.longitude,
      altitudeM: pos.altitude > 0 ? pos.altitude : null,
      accuracyM: pos.accuracy > 0 ? pos.accuracy : null,
      speedKmh: pos.speed >= 0 ? speedKmh : null,
      headingDeg: pos.heading >= 0 ? pos.heading : null,
      recordedAt: pos.timestamp,
    );

    // Try sync immediately; if it fails the next _syncBatch call will pick it up
    await _syncBatch();
  }

  static Future<void> _syncBatch() async {
    if (_activeTripId == null) return;
    final rows = await LocalDb.getPendingPoints(_activeTripId!);
    if (rows.isEmpty) return;

    try {
      final points = rows.map((r) => {
        'lat': r['lat'],
        'lon': r['lon'],
        if (r['altitude_m'] != null) 'altitudeM': r['altitude_m'],
        if (r['accuracy_m'] != null) 'accuracyM': r['accuracy_m'],
        if (r['speed_kmh'] != null) 'speedKmh': r['speed_kmh'],
        if (r['heading_deg'] != null) 'headingDeg': r['heading_deg'],
        'isEstimated': (r['is_estimated'] as int) == 1,
        'recordedAt': r['recorded_at'],
      }).toList();

      final result = await ApiService.batchPoints(
        tripId: _activeTripId!,
        points: points,
        sourceType: 'smartphone_gps',
      );

      // After sync, store the segment ID for subsequent points
      if (_activeSegmentId == null && result['segmentId'] != null) {
        _activeSegmentId = result['segmentId'] as String;
      }

      final ids = rows.map((r) => r['id'] as int).toList();
      await LocalDb.markSynced(ids);
    } catch (_) {
      // Offline — will retry on next point
    }
  }

  static void _setState(TripState s) {
    _state = s;
    _stateController.add(s);
  }
}
