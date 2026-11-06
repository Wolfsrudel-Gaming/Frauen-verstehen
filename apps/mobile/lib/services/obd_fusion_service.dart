import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'data_service.dart';
import 'ble_service.dart';
import 'elm327_client.dart';
import 'obd2_adapter.dart';
import 'notification_service.dart';

enum ObdStatus { disconnected, connecting, connected, reconnecting }

// OBD fusion service:
// - Manages the BLE ↔ ELM327 lifecycle within an active trip
// - Polls PIDs on a fixed interval and batches readings to the store
// - Reads DTCs after connection and fires local notifications for new codes
// - Reconnects automatically when the BLE link drops mid-trip (bumpy
//   adapters and parking-garage walls are normal life in a car)
class ObdFusionService {
  static const Duration _pollInterval = Duration(seconds: 2);
  static const int _batchSize = 10;
  static const int _maxReconnectAttempts = 3;

  static Elm327Client? _elm;
  static Obd2Adapter? _obd;
  static Timer? _pollTimer;
  static String? _sessionId;
  static String? _activeTripId;
  static String? _elmProtocol;
  static BluetoothDevice? _device;

  static final _readings = <Map<String, dynamic>>[];
  static ObdReading? _lastReading;
  static ObdReading? get lastReading => _lastReading;

  // Rolling in-memory history for the live charts (~5 min at 2 s interval).
  // Separate from _readings, which is drained on every upload.
  static const int _historyLimit = 150;
  static final List<ObdReading> _history = [];
  static List<ObdReading> get history => List.unmodifiable(_history);

  static final StreamController<ObdReading?> _readingController =
      StreamController<ObdReading?>.broadcast();
  static Stream<ObdReading?> get readingStream => _readingController.stream;

  static ObdStatus _status = ObdStatus.disconnected;
  static ObdStatus get status => _status;
  static final StreamController<ObdStatus> _statusController =
      StreamController<ObdStatus>.broadcast();
  static Stream<ObdStatus> get statusStream => _statusController.stream;

  static void _setStatus(ObdStatus s) {
    _status = s;
    _statusController.add(s);
  }

  static bool get isConnected => _status == ObdStatus.connected;
  static String? get elmProtocol => _elmProtocol;

  // -------------------------------------------------------------------------
  // Connect to a BLE device and start OBD polling for the given trip
  // -------------------------------------------------------------------------
  static Future<String> connect(BluetoothDevice device, String tripId) async {
    _setStatus(ObdStatus.connecting);

    // BLE connection + GATT profile discovery.
    // On failure the BLE link stays open so the BLE Inspector can enumerate
    // the device's services — do NOT disconnect here.
    final profile = await BleService.connect(device);
    if (profile == null) {
      _setStatus(ObdStatus.disconnected);
      throw Exception(
        'Keine ELM327-Schnittstelle auf diesem Gerät gefunden — auch die '
        'automatische Erkennung blieb erfolglos.\n'
        'Prüfe, ob die Zündung an ist, und versuche es erneut.',
      );
    }

    _activeTripId = tripId;
    _device = device;

    try {
      // Register the session (offline: synthesised locally)
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
      // Init failed (ignition off, …) — roll back everything so a retry
      // starts from a clean state instead of leaking a session.
      await disconnect();
      rethrow;
    }

    _setStatus(ObdStatus.connected);

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

    // Close the session record
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
    _device = null;
    _history.clear();
    _readingController.add(null);
    _setStatus(ObdStatus.disconnected);

    await BleService.disconnect();
  }

  // -------------------------------------------------------------------------
  // Internal: poll one reading cycle
  // -------------------------------------------------------------------------
  static bool _polling = false;

  static Future<void> _poll() async {
    if (_obd == null || _status != ObdStatus.connected) return;
    // A full PID cycle can exceed the poll interval — never overlap two
    // cycles, or their ELM327 commands would interleave on the wire.
    if (_polling) return;
    _polling = true;
    try {
      final reading = await _obd!.poll();
      _lastReading = reading;
      _readingController.add(reading);

      _history.add(reading);
      if (_history.length > _historyLimit) _history.removeAt(0);

      _readings.add(reading.toJson());
      if (_readings.length >= _batchSize) await _flush();
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Not connected') || msg.contains('timeout')) {
        await _handleDrop();
      }
    } finally {
      _polling = false;
    }
  }

  // -------------------------------------------------------------------------
  // BLE drop mid-trip: try to get the adapter back before giving up.
  // -------------------------------------------------------------------------
  static Future<void> _handleDrop() async {
    if (_status != ObdStatus.connected) return;
    final device = _device;
    final tripId = _activeTripId;
    if (device == null || tripId == null) {
      await disconnect();
      return;
    }

    _pollTimer?.cancel();
    _pollTimer = null;
    _setStatus(ObdStatus.reconnecting);

    await _elm?.dispose();
    _elm = null;
    _obd = null;
    try {
      await BleService.disconnect();
    } catch (_) {}

    for (var attempt = 1; attempt <= _maxReconnectAttempts; attempt++) {
      await Future.delayed(Duration(seconds: 2 * attempt));
      if (_status != ObdStatus.reconnecting) return; // user disconnected
      try {
        final profile = await BleService.connect(device);
        if (profile == null) continue;
        _elm = Elm327Client();
        _obd = Obd2Adapter(_elm!);
        _elmProtocol = await _obd!.init();
        _setStatus(ObdStatus.connected);
        _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
        return;
      } catch (_) {
        await _elm?.dispose();
        _elm = null;
        _obd = null;
      }
    }

    // Could not get it back — close down cleanly.
    await disconnect();
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
