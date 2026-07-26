import 'dart:convert';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'local_db.dart';
import 'scoring_service.dart';

// Local persistence for offline mode. Returns maps in the exact same shape
// as the backend API (including numeric values as strings where Postgres
// numeric columns would produce strings) so the screens work unchanged.
class LocalStore {
  // ---------------------------------------------------------------------
  // UUID v4 (no external dependency)
  // ---------------------------------------------------------------------
  static final _rng = Random.secure();

  static String uuid() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  // ---------------------------------------------------------------------
  // Vehicles
  // ---------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> getVehicles() async {
    final db = await LocalDb.db;
    final rows = await db.query('local_vehicles', orderBy: 'created_at DESC');
    return rows.map(_vehicleToApi).toList();
  }

  static Future<Map<String, dynamic>> createVehicle({
    required String make,
    required String model,
    int? year,
    String? licensePlate,
    String category = 'car',
    String protocolSupport = 'obd2',
    String? notes,
  }) async {
    final db = await LocalDb.db;
    final id = uuid();
    final row = {
      'id': id,
      'make': make,
      'model': model,
      'year': year,
      'license_plate': (licensePlate != null && licensePlate.isNotEmpty) ? licensePlate : null,
      'category': category,
      'protocol_support': protocolSupport,
      'notes': notes,
      'is_active': 1,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    await db.insert('local_vehicles', row);
    return _vehicleToApi(row);
  }

  static Map<String, dynamic> _vehicleToApi(Map<String, dynamic> r) => {
        'id': r['id'],
        'make': r['make'],
        'model': r['model'],
        'year': r['year'],
        'licensePlate': r['license_plate'],
        'category': r['category'],
        'protocolSupport': r['protocol_support'],
        'notes': r['notes'],
        'isActive': (r['is_active'] as int) == 1,
      };

  // ---------------------------------------------------------------------
  // Trips
  // ---------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> getTrips() async {
    final db = await LocalDb.db;
    final rows = await db.query('local_trips', orderBy: 'started_at DESC');
    return rows.map(_tripToApi).toList();
  }

  static Future<Map<String, dynamic>> startTrip({
    String? vehicleId,
    int? startOdometer,
    String? notes,
    String startTrigger = 'manual',
  }) async {
    final db = await LocalDb.db;
    final id = uuid();
    final row = {
      'id': id,
      'vehicle_id': vehicleId,
      'status': 'in_progress',
      'start_trigger': startTrigger,
      'started_at': DateTime.now().toUtc().toIso8601String(),
      'start_odometer': startOdometer,
      'notes': notes,
    };
    await db.insert('local_trips', row);
    return _tripToApi(row);
  }

  static Future<Map<String, dynamic>> endTrip(
    String tripId, {
    int? endOdometer,
    String endTrigger = 'manual',
  }) async {
    final db = await LocalDb.db;
    final distanceKm = await _tripDistanceKm(tripId);

    // Score the trip locally — same algorithm as the backend engine
    final score = await _computeScore(tripId, distanceKm ?? 0);

    await db.update(
      'local_trips',
      {
        'status': 'completed',
        'end_trigger': endTrigger,
        'ended_at': DateTime.now().toUtc().toIso8601String(),
        'end_odometer': endOdometer,
        'distance_km': distanceKm,
        if (score != null) 'score': score.totalScore,
        if (score != null) 'score_breakdown': jsonEncode(score.breakdown),
        if (score != null) 'score_confidence': score.confidenceWeight,
        if (score != null) 'score_source': score.sourceType,
      },
      where: 'id = ?',
      whereArgs: [tripId],
    );
    final rows = await db.query('local_trips', where: 'id = ?', whereArgs: [tripId]);
    return _tripToApi(rows.first);
  }

  static Future<TripScoreResult?> _computeScore(String tripId, double distanceKm) async {
    try {
      final pointRows = await _pointRows(tripId);
      final gps = pointRows
          .map((r) => GpsSample(
                speedKmh: r['speed_kmh'] as double?,
                recordedAt: DateTime.parse(r['recorded_at'] as String),
              ))
          .toList();

      final db = await LocalDb.db;
      final obdRows = await db.query(
        'local_obd_readings',
        where: 'trip_id = ?',
        whereArgs: [tripId],
        orderBy: 'recorded_at ASC',
      );
      final obd = obdRows
          .map((r) => ObdSample(
                rpmX4: r['rpm_x4'] as int?,
                coolantTempC: r['coolant_temp_c'] as int?,
                recordedAt: DateTime.parse(r['recorded_at'] as String),
              ))
          .toList();

      return ScoringService.computeTripScore(gps, obd, distanceKm);
    } catch (_) {
      return null; // scoring must never break trip end
    }
  }

  static Future<void> discardTrip(String tripId) async {
    final db = await LocalDb.db;
    await db.update(
      'local_trips',
      {'status': 'discarded', 'ended_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [tripId],
    );
  }

  static Future<double?> _tripDistanceKm(String tripId) async {
    final points = await _pointRows(tripId);
    if (points.length < 2) return null;
    double meters = 0;
    for (int i = 1; i < points.length; i++) {
      meters += Geolocator.distanceBetween(
        points[i - 1]['lat'] as double,
        points[i - 1]['lon'] as double,
        points[i]['lat'] as double,
        points[i]['lon'] as double,
      );
    }
    return meters / 1000.0;
  }

  static Map<String, dynamic> _tripToApi(Map<String, dynamic> r) => {
        'id': r['id'],
        'vehicleId': r['vehicle_id'],
        'status': r['status'],
        'startTrigger': r['start_trigger'],
        'endTrigger': r['end_trigger'],
        'startedAt': r['started_at'],
        'endedAt': r['ended_at'],
        'startOdometer': r['start_odometer'],
        'endOdometer': r['end_odometer'],
        // The backend serialises Postgres numeric as string — mirror that.
        'distanceKm': r['distance_km'] != null ? (r['distance_km'] as double).toStringAsFixed(3) : null,
        'notes': r['notes'],
        'score': r['score'] != null ? (r['score'] as double).toStringAsFixed(1) : null,
        'scoreBreakdown': r['score_breakdown'] != null
            ? jsonDecode(r['score_breakdown'] as String)
            : null,
        'scoreConfidence': r['score_confidence'],
        'scoreSource': r['score_source'],
      };

  // ---------------------------------------------------------------------
  // GPS points — stored in pending_points by TripDetectionService; offline
  // mode reads them back for the map regardless of sync state.
  // ---------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> _pointRows(String tripId) async {
    final db = await LocalDb.db;
    return db.query(
      'pending_points',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'recorded_at ASC',
    );
  }

  static Future<List<Map<String, dynamic>>> getTripPoints(String tripId) async {
    final rows = await _pointRows(tripId);
    return rows
        .map((r) => {
              'lat': (r['lat'] as double).toString(),
              'lon': (r['lon'] as double).toString(),
              'altitudeM': r['altitude_m']?.toString(),
              'accuracyM': r['accuracy_m']?.toString(),
              'speedKmh': r['speed_kmh']?.toString(),
              'headingDeg': r['heading_deg']?.toString(),
              'isEstimated': (r['is_estimated'] as int) == 1,
              'recordedAt': r['recorded_at'],
            })
        .toList();
  }

  // ---------------------------------------------------------------------
  // OBD readings & DTCs
  // ---------------------------------------------------------------------
  static Future<void> saveObdReadings(String tripId, List<Map<String, dynamic>> readings) async {
    final db = await LocalDb.db;
    final batch = db.batch();
    for (final r in readings) {
      batch.insert('local_obd_readings', {
        'trip_id': tripId,
        'recorded_at': r['recordedAt'],
        'rpm_x4': r['rpmX4'],
        'speed_kmh': r['speedKmh'],
        'coolant_temp_c': r['coolantTempC'],
        'throttle_pos': r['throttlePos'],
        'fuel_level_pct': r['fuelLevelPct'],
        'intake_air_temp_c': r['intakeAirTempC'],
        'maf_gps': r['mafGps'],
      });
    }
    await batch.commit(noResult: true);
  }

  // ---------------------------------------------------------------------
  // Reads for the detail/stats screens
  // ---------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> getTripObdReadings(String tripId) async {
    final db = await LocalDb.db;
    final rows = await db.query(
      'local_obd_readings',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'recorded_at ASC',
    );
    return rows
        .map((r) => {
              'recordedAt': r['recorded_at'],
              'rpmX4': r['rpm_x4'],
              'speedKmh': r['speed_kmh'],
              'coolantTempC': r['coolant_temp_c'],
              // Backend returns numerics as strings — mirror that
              'throttlePos': r['throttle_pos']?.toString(),
              'fuelLevelPct': r['fuel_level_pct']?.toString(),
              'intakeAirTempC': r['intake_air_temp_c'],
              'mafGps': r['maf_gps']?.toString(),
            })
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getTripDtcs(String tripId) async {
    final db = await LocalDb.db;
    final rows = await db.query(
      'local_dtc_events',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'detected_at ASC',
    );
    return rows.map(_dtcToApi).toList();
  }

  static Future<List<Map<String, dynamic>>> getVehicleDtcs(String vehicleId) async {
    final db = await LocalDb.db;
    final rows = await db.query(
      'local_dtc_events',
      where: 'vehicle_id = ? AND cleared_at IS NULL',
      whereArgs: [vehicleId],
      orderBy: 'detected_at DESC',
    );
    return rows.map(_dtcToApi).toList();
  }

  static Future<int> clearVehicleDtcs(String vehicleId) async {
    final db = await LocalDb.db;
    return db.update(
      'local_dtc_events',
      {'cleared_at': DateTime.now().toUtc().toIso8601String()},
      where: 'vehicle_id = ? AND cleared_at IS NULL',
      whereArgs: [vehicleId],
    );
  }

  static Map<String, dynamic> _dtcToApi(Map<String, dynamic> r) => {
        'code': r['code'],
        'severity': r['severity'],
        'detectedAt': r['detected_at'],
        'clearedAt': r['cleared_at'],
        'vehicleId': r['vehicle_id'],
        'tripId': r['trip_id'],
        'description': null,
      };

  static Future<Map<String, dynamic>> getTrip(String tripId) async {
    final db = await LocalDb.db;
    final rows = await db.query('local_trips', where: 'id = ?', whereArgs: [tripId]);
    if (rows.isEmpty) throw Exception('Fahrt nicht gefunden');
    return _tripToApi(rows.first);
  }

  // ---------------------------------------------------------------------
  // Aggregate stats — mirrors GET /stats/overview
  // ---------------------------------------------------------------------
  static Future<Map<String, dynamic>> getOverviewStats() async {
    final db = await LocalDb.db;

    final tripAgg = await db.rawQuery('''
      SELECT COUNT(*) AS c,
             COALESCE(SUM(distance_km), 0) AS km,
             COALESCE(SUM(
               (julianday(ended_at) - julianday(started_at)) * 24
             ), 0) AS hours
      FROM local_trips WHERE status = 'completed'
    ''');

    final scoreAgg = await db.rawQuery('''
      SELECT SUM(score * score_confidence) AS weighted,
             SUM(score_confidence) AS conf,
             COUNT(*) AS c,
             MAX(score) AS best
      FROM local_trips WHERE score IS NOT NULL
    ''');

    final vehicleAgg =
        await db.rawQuery('SELECT COUNT(*) AS c FROM local_vehicles WHERE is_active = 1');
    final dtcAgg = await db
        .rawQuery('SELECT COUNT(*) AS c FROM local_dtc_events WHERE cleared_at IS NULL');
    final obdAgg = await db.rawQuery('SELECT COUNT(*) AS c FROM local_obd_readings');

    final weighted = (scoreAgg.first['weighted'] as num?)?.toDouble();
    final conf = (scoreAgg.first['conf'] as num?)?.toDouble();
    final avgScore = (weighted != null && conf != null && conf > 0) ? weighted / conf : null;

    double round1(num v) => (v * 10).round() / 10;

    return {
      'tripCount': (tripAgg.first['c'] as num).toInt(),
      'totalKm': round1((tripAgg.first['km'] as num).toDouble()),
      'totalHours': round1((tripAgg.first['hours'] as num).toDouble()),
      'avgScore': avgScore != null ? round1(avgScore) : null,
      'bestScore': (scoreAgg.first['best'] as num?) != null
          ? round1((scoreAgg.first['best'] as num).toDouble())
          : null,
      'scoredTrips': (scoreAgg.first['c'] as num).toInt(),
      'activeVehicles': (vehicleAgg.first['c'] as num).toInt(),
      'openDtcs': (dtcAgg.first['c'] as num).toInt(),
      'obdReadings': (obdAgg.first['c'] as num).toInt(),
    };
  }

  static Future<Map<String, dynamic>> getVehicleStats(String vehicleId) async {
    final db = await LocalDb.db;
    final agg = await db.rawQuery('''
      SELECT COUNT(*) AS c,
             COALESCE(SUM(distance_km), 0) AS km,
             MAX(started_at) AS last_at,
             SUM(score * score_confidence) AS weighted,
             SUM(score_confidence) AS conf
      FROM local_trips
      WHERE vehicle_id = ? AND status = 'completed'
    ''', [vehicleId]);
    final dtcAgg = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM local_dtc_events WHERE vehicle_id = ? AND cleared_at IS NULL',
      [vehicleId],
    );

    final weighted = (agg.first['weighted'] as num?)?.toDouble();
    final conf = (agg.first['conf'] as num?)?.toDouble();
    final avgScore = (weighted != null && conf != null && conf > 0) ? weighted / conf : null;

    return {
      'tripCount': (agg.first['c'] as num).toInt(),
      'totalKm': ((agg.first['km'] as num).toDouble() * 10).round() / 10,
      'lastTripAt': agg.first['last_at'],
      'avgScore': avgScore != null ? (avgScore * 10).round() / 10 : null,
      'openDtcs': (dtcAgg.first['c'] as num).toInt(),
    };
  }

  static Future<List<Map<String, dynamic>>> getVehicleTrips(String vehicleId) async {
    final db = await LocalDb.db;
    final rows = await db.query(
      'local_trips',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'started_at DESC',
      limit: 50,
    );
    return rows.map(_tripToApi).toList();
  }

  static Future<void> reportDtcs(String tripId, List<String> codes, {String? vehicleId}) async {
    final db = await LocalDb.db;
    final now = DateTime.now().toUtc().toIso8601String();
    final batch = db.batch();
    for (final code in codes) {
      batch.insert('local_dtc_events', {
        'trip_id': tripId,
        'vehicle_id': vehicleId,
        'code': code,
        'severity': 'warning',
        'detected_at': now,
      });
    }
    await batch.commit(noResult: true);
  }
}
