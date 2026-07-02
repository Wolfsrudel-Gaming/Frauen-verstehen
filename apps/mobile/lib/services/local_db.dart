import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// Offline buffer — stores GPS points that haven't been synced yet.
class LocalDb {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'driver_analytics.db'),
      version: 2,
      onCreate: (db, version) => _createTables(db),
      onUpgrade: (db, oldVersion, newVersion) => _createTables(db),
    );
  }

  // All CREATE TABLE statements are idempotent so onCreate and onUpgrade
  // can share this method.
  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id TEXT NOT NULL,
        segment_id TEXT,
        lat REAL NOT NULL,
        lon REAL NOT NULL,
        altitude_m REAL,
        accuracy_m REAL,
        speed_kmh REAL,
        heading_deg REAL,
        is_estimated INTEGER NOT NULL DEFAULT 0,
        recorded_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // ---- Offline-mode tables (v2) ----
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_vehicles (
        id TEXT PRIMARY KEY,
        make TEXT NOT NULL,
        model TEXT NOT NULL,
        year INTEGER,
        license_plate TEXT,
        category TEXT NOT NULL DEFAULT 'car',
        protocol_support TEXT NOT NULL DEFAULT 'obd2',
        notes TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_trips (
        id TEXT PRIMARY KEY,
        vehicle_id TEXT,
        status TEXT NOT NULL DEFAULT 'in_progress',
        start_trigger TEXT NOT NULL DEFAULT 'manual',
        end_trigger TEXT,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        start_odometer INTEGER,
        end_odometer INTEGER,
        distance_km REAL,
        notes TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_obd_readings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id TEXT NOT NULL,
        recorded_at TEXT NOT NULL,
        rpm_x4 INTEGER,
        speed_kmh INTEGER,
        coolant_temp_c INTEGER,
        throttle_pos REAL,
        fuel_level_pct REAL,
        intake_air_temp_c INTEGER,
        maf_gps REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_dtc_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id TEXT,
        trip_id TEXT,
        code TEXT NOT NULL,
        severity TEXT NOT NULL DEFAULT 'warning',
        detected_at TEXT NOT NULL,
        cleared_at TEXT
      )
    ''');
  }

  static Future<void> insertPoint({
    required String tripId,
    String? segmentId,
    required double lat,
    required double lon,
    double? altitudeM,
    double? accuracyM,
    double? speedKmh,
    double? headingDeg,
    bool isEstimated = false,
    required DateTime recordedAt,
  }) async {
    final database = await db;
    await database.insert('pending_points', {
      'trip_id': tripId,
      'segment_id': segmentId,
      'lat': lat,
      'lon': lon,
      'altitude_m': altitudeM,
      'accuracy_m': accuracyM,
      'speed_kmh': speedKmh,
      'heading_deg': headingDeg,
      'is_estimated': isEstimated ? 1 : 0,
      'recorded_at': recordedAt.toIso8601String(),
      'synced': 0,
    });
  }

  static Future<List<Map<String, dynamic>>> getPendingPoints(String tripId) async {
    final database = await db;
    return database.query(
      'pending_points',
      where: 'trip_id = ? AND synced = 0',
      whereArgs: [tripId],
      orderBy: 'recorded_at ASC',
    );
  }

  static Future<void> markSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final database = await db;
    final placeholders = ids.map((_) => '?').join(',');
    await database.rawUpdate(
      'UPDATE pending_points SET synced = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  static Future<void> deleteOldSynced() async {
    final database = await db;
    // Keep only last 30 days of synced points
    final cutoff = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    await database.delete(
      'pending_points',
      where: 'synced = 1 AND recorded_at < ?',
      whereArgs: [cutoff],
    );
  }
}
