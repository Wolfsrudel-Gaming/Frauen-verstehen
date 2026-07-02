import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'data_service.dart';
import 'ble_service.dart';
import 'elm327_client.dart';
import 'obd2_adapter.dart';
import 'notification_service.dart';

// OBD fusion service:
// - Manages the BLE ↔ ELM327 lifecycle within an active trip
// - Polls PIDs on a configurable interval and batches readings to the backend
// - Reads DTCs after connection and fires local notifications for new codes
// - Tags the trip segment as 'obd' for the duration of connection
class ObdFusionService {
  static const Duration _pollInterval = Duration(seconds: 2);
  static const int _batchSize = 10;

  static Elm327Client? _elm;
  static Obd2Adapter? _obd;
  static Timer? _pollTimer;
  static String? _sessionId;
  static String? _activeTripId;
  static String? _elmProtocol;

  static final _readings = <Map<String, dynamic>>[];
  static ObdReading? _lastReading;
  static ObdReading? get lastReading => _lastReading;

  static final StreamController<ObdReading?> _readingController =
      StreamController<ObdReading?>.broadcast();
  static Stream<ObdReading?> get readingStream => _readingController.stream;

  static bool get isConnected => BleService.isConnected && _elm != null;
  static String? get elmProtocol => _elmProtocol;

  // -------------------------------------------------------------------------
  // Connect to a BLE device and start OBD polling for the given trip
  // -------------------------------------------------------------------------
  static Future<String> connect(BluetoothDevice device, String tripId) async {
    _activeTripId = tripId;

    // BLE connection + GATT profile discovery.
    // On failure the BLE link stays open so the BLE Inspector can enumerate
    // the device's services — do NOT disconnect here.
    final profile = await BleService.connect(device);
    if (profile == null) {
      throw Exception(
        'Could not find ELM327 characteristics on this device.\n'
        'Use the BLE Inspector to identify the correct UUIDs, then save them.',
      );
    }

    try {
      // Notify backend of session start
      final adapterName = device.platformName;
      final session = await DataService.startObdSession(
        tripId: tripId,
        adapterName: adapterName.isNotEmpty ? adapterName : null,
      );
      _sessionId = session['id'] as String;

      // ELM327 init + protocol detection
      _elm = Elm327Client();
      _obd = Obd2Adapter(_elm!);
      _elmProtocol = await _obd!.init();
    } catch (e) {
      // Init failed (ignition off, backend down, …) — roll back everything
      // so a retry starts from a clean state instead of leaking a session.
      await disconnect();
      rethrow;
    }

    // Read DTCs immediately after connect and notify user
    await _checkDtcs(tripId);

    // Start polling
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());

    return _elmProtocol!;
  }

  // -------------------------------------------------------------------------
  // Disconnect cleanly
  // -------------------------------------------------------------------------
  static Future<void> disconnect() async {
    _pollTimer?.cancel();
    _pollTimer = null;

    // Flush remaining buffered readings
    if (_readings.isNotEmpty && _activeTripId != null && _sessionId != null) {
      await _flush();
    }

    // Close ELM327 client
    await _elm?.dispose();
    _elm = null;
    _obd = null;

    // Tell backend session ended
    if (_sessionId != null && _activeTripId != null) {
      try {
        await DataService.endObdSession(
          tripId: _activeTripId!,
          sessionId: _sessionId!,
          elmProtocol: _elmProtocol,
        );
      } catch (_) {}
    }

    _sessionId = null;
    _elmProtocol = null;
    _lastReading = null;
    _readingController.add(null);

    await BleService.disconnect();
  }

  // -------------------------------------------------------------------------
  // Internal: poll one reading cycle
  // -------------------------------------------------------------------------
  static bool _polling = false;

  static Future<void> _poll() async {
    if (_obd == null) return;
    // A full PID cycle can exceed the poll interval — never overlap two
    // cycles, or their ELM327 commands would interleave on the wire.
    if (_polling) return;
    _polling = true;
    try {
      final reading = await _obd!.poll();
      _lastReading = reading;
      _readingController.add(reading);

      _readings.add(reading.toJson());
      if (_readings.length >= _batchSize) await _flush();
    } catch (e) {
      // BLE dropped — disconnect gracefully
      if (e.toString().contains('Not connected') || e.toString().contains('timeout')) {
        await disconnect();
      }
    } finally {
      _polling = false;
    }
  }

  static Future<void> _flush() async {
    if (_readings.isEmpty || _activeTripId == null) return;
    final batch = List<Map<String, dynamic>>.from(_readings);
    _readings.clear();
    try {
      await DataService.batchObdReadings(
        tripId: _activeTripId!,
        readings: batch,
        sessionId: _sessionId,
      );
    } catch (_) {
      // Re-queue on failure
      _readings.insertAll(0, batch);
    }
  }

  static Future<void> _checkDtcs(String tripId) async {
    if (_obd == null) return;
    try {
      final codes = await _obd!.readDtcs();
      if (codes.isEmpty) return;

      await DataService.reportDtcs(tripId: tripId, codes: codes);

      // Push a local notification — DTC alerts bypass quiet hours
      await NotificationService.showDtcAlert(codes);
    } catch (_) {}
  }
}
