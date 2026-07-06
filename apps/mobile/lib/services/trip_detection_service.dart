import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'app_mode.dart';
import 'data_service.dart';
import 'local_db.dart';
import 'location_service.dart';

enum TripState { idle, detecting, inTrip, stopping }

// Live metrics for the in-trip UI, emitted on every recorded GPS point.
class LiveTripStats {
  final double? speedKmh;
  final double distanceKm;
  final int points;
  final double? lat;
  final double? lon;
  final double? headingDeg;
  final DateTime? startedAt;

  const LiveTripStats({
    this.speedKmh,
    required this.distanceKm,
    required this.points,
    this.lat,
    this.lon,
    this.headingDeg,
    this.startedAt,
  });
}

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

  // Live stats for the in-trip UI (speed, distance, route growth)
  static int _pointCount = 0;
  static DateTime? _tripStartedAt;
  static final StreamController<LiveTripStats> _liveController =
      StreamController<LiveTripStats>.broadcast();
  static Stream<LiveTripStats> get liveStream => _liveController.stream;
  static LiveTripStats get liveStats => LiveTripStats(
        speedKmh: _lastPos != null && _lastPos!.speed >= 0 ? _lastPos!.speed * 3.6 : null,
        distanceKm: _totalDistanceM / 1000.0,
        points: _pointCount,
        lat: _lastPos?.latitude,
        lon: _lastPos?.longitude,
        startedAt: _tripStartedAt,
      );

  // ---------------------------------------------------------------------
  // Manual recording: attaches the GPS recorder to a trip the user started
  // by hand. No auto start/stop — the user ends the trip explicitly.
  // ---------------------------------------------------------------------
  static bool _manualMode = false;
  static StreamSubscription<Position>? _manualSub;
  static bool get isManualRecording => _manualMode;

  static Future<void> attachManual(String tripId) async {
    if (_manualMode) return;
    final granted = await LocationService.requestPermission();
    if (!granted) {
      throw Exception(
        'Standort-Berechtigung fehlt oder GPS ist aus — Fahrt wird ohne Route aufgezeichnet.',
      );
    }
    _manualMode = true;
    _activeTripId = tripId;
    _activeSegmentId = null;
    _totalDistanceM = 0;
    _pointCount = 0;
    _lastPos = null;
    _tripStartedAt = DateTime.now();
    await LocationService.startTracking();
    _manualSub = LocationService.positionStream.listen(_onManualPosition);
    _setState(TripState.inTrip);
  }

  static Future<void> detachManual() async {
    if (!_manualMode) return;
    await _manualSub?.cancel();
    _manualSub = null;
    _manualMode = false;
    // Flush whatever is still buffered before letting go of the trip id
    await _syncBatch();
    _activeTripId = null;
    _activeSegmentId = null;
    _totalDistanceM = 0;
    _pointCount = 0;
    _tripStartedAt = null;
    // Keep the location stream alive if auto-detection is also running
    if (_sub == null) await LocationService.stopTracking();
    _setState(TripState.idle);
  }

  static Future<void> _onManualPosition(Position pos) async {
    if (_lastPos != null) {
      _totalDistanceM += Geolocator.distanceBetween(
        _lastPos!.latitude, _lastPos!.longitude,
        pos.latitude, pos.longitude,
      );
    }
    _lastPos = pos;
    await _recordPoint(pos);
  }

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
    if (!_manualMode) await LocationService.stopTracking();
  }

  static Future<void> _onPosition(Position pos) async {
    // Manual recording owns the trip — the auto state machine stays out
    if (_manualMode) return;

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
      final trip = await DataService.startTrip(startTrigger: 'auto_gps');
      _activeTripId = trip['id'] as String;
      _activeSegmentId = null;
      _pointCount = 0;
      _tripStartedAt = DateTime.now();
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
        await DataService.discardTrip(_activeTripId!);
      } catch (_) {}
    } else {
      try {
        await DataService.endTrip(_activeTripId!, endTrigger: 'auto_gps');
      } catch (_) {}
    }
    _activeTripId = null;
    _activeSegmentId = null;
    _totalDistanceM = 0;
    _pointCount = 0;
    _tripStartedAt = null;
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

    // Notify the live UI
    _pointCount++;
    _liveController.add(LiveTripStats(
      speedKmh: pos.speed >= 0 ? speedKmh : null,
      distanceKm: _totalDistanceM / 1000.0,
      points: _pointCount,
      lat: pos.latitude,
      lon: pos.longitude,
      headingDeg: pos.heading >= 0 ? pos.heading : null,
      startedAt: _tripStartedAt,
    ));
  }

  static Future<void> _syncBatch() async {
    if (_activeTripId == null) return;
    // Offline mode: points stay in pending_points and are read locally for
    // the map — never mark them synced without a real upload.
    if (AppMode.isOffline) return;
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

      final result = await DataService.batchPoints(
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
