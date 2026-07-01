import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Known ELM327 BLE GATT service/characteristic UUIDs.
// Carista's real UUIDs must be confirmed via the BLE Inspector in the app.
// Most generic ELM327 dongles use one of these two profiles.
const _kKnownProfiles = [
  _BleProfile(service: 'fff0', write: 'fff2', notify: 'fff1'), // profile A (most common)
  _BleProfile(service: 'ffe0', write: 'ffe1', notify: 'ffe1'), // profile B (single char)
];

const _kCustomServiceKey = 'ble_custom_service';
const _kCustomWriteKey = 'ble_custom_write';
const _kCustomNotifyKey = 'ble_custom_notify';

class _BleProfile {
  final String service;
  final String write;
  final String notify;
  const _BleProfile({required this.service, required this.write, required this.notify});
}

// Represents a discovered BLE device with advertised name + signal strength
class DiscoveredDevice {
  final BluetoothDevice device;
  final String name;
  final int rssi;
  final List<String> serviceUuids;

  const DiscoveredDevice({
    required this.device,
    required this.name,
    required this.rssi,
    required this.serviceUuids,
  });
}

class BleService {
  static BluetoothDevice? _connectedDevice;
  static BluetoothCharacteristic? _writeChar;
  static BluetoothCharacteristic? _notifyChar;

  static final StreamController<List<int>> _rxController =
      StreamController<List<int>>.broadcast();
  static Stream<List<int>> get rxStream => _rxController.stream;

  static BluetoothDevice? get connectedDevice => _connectedDevice;

  // true when the BLE link is up AND ELM327 characteristics are resolved
  static bool get isConnected => _connectedDevice != null && _writeChar != null;

  // true when physically connected to a BLE device (even without OBD profile)
  static bool get isBleConnected => _connectedDevice != null;

  // -------------------------------------------------------------------------
  // Scan for BLE devices (returns a stream of discovered devices).
  // Shows ALL named devices; the user can filter/pick in the UI.
  // -------------------------------------------------------------------------
  static Stream<DiscoveredDevice> scan({Duration timeout = const Duration(seconds: 12)}) {
    final controller = StreamController<DiscoveredDevice>();
    StreamSubscription? innerSub;

    FlutterBluePlus.startScan(timeout: timeout).then((_) {
      innerSub?.cancel();
      if (!controller.isClosed) controller.close();
    }).catchError((Object e) {
      if (!controller.isClosed) controller.addError(e);
    });

    innerSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.device.platformName.isNotEmpty) {
          controller.add(DiscoveredDevice(
            device: r.device,
            name: r.device.platformName,
            rssi: r.rssi,
            serviceUuids: r.advertisementData.serviceUuids
                .map((u) => u.str128.toLowerCase())
                .toList(),
          ));
        }
      }
    });

    controller.onCancel = () {
      innerSub?.cancel();
      FlutterBluePlus.stopScan();
    };

    return controller.stream;
  }

  static Future<void> stopScan() => FlutterBluePlus.stopScan();

  // -------------------------------------------------------------------------
  // Connect to a device and discover ELM327 characteristics.
  //
  // Returns the matched profile, or null if no ELM327 profile was found.
  // IMPORTANT: the BLE connection is kept alive even when null is returned so
  // the BLE Inspector can enumerate services and identify the correct UUIDs.
  // -------------------------------------------------------------------------
  static Future<_BleProfile?> connect(BluetoothDevice device) async {
    // Disconnect any existing connection first
    if (_connectedDevice != null && _connectedDevice!.remoteId != device.remoteId) {
      await disconnect();
    }

    await device.connect(autoConnect: false, timeout: const Duration(seconds: 15));
    _connectedDevice = device;

    final services = await device.discoverServices();
    final customProfile = await _loadCustomProfile();

    // Try custom profile first, then known profiles
    final profilesToTry = [
      if (customProfile != null) customProfile,
      ..._kKnownProfiles,
    ];

    for (final profile in profilesToTry) {
      final svcUuid = Guid(profile.service);
      final svc = _findService(services, svcUuid);
      if (svc == null) continue;

      final writeChar = _findChar(svc, Guid(profile.write));
      final notifyChar = _findChar(svc, Guid(profile.notify));
      if (writeChar == null || notifyChar == null) continue;

      _writeChar = writeChar;
      _notifyChar = notifyChar;

      await notifyChar.setNotifyValue(true);
      notifyChar.lastValueStream.listen(_rxController.add);

      return profile;
    }

    // No ELM327 profile found — leave BLE connection open so the BLE
    // Inspector screen can call inspectServices() on this device.
    return null;
  }

  // -------------------------------------------------------------------------
  // Connect purely for BLE inspection (no ELM327 profile discovery).
  // Used by the BLE Inspector screen to enumerate GATT services.
  // -------------------------------------------------------------------------
  static Future<void> connectRaw(BluetoothDevice device) async {
    if (_connectedDevice != null && _connectedDevice!.remoteId != device.remoteId) {
      await disconnect();
    }
    if (_connectedDevice?.remoteId == device.remoteId) return; // already connected
    await device.connect(autoConnect: false, timeout: const Duration(seconds: 15));
    _connectedDevice = device;
  }

  // -------------------------------------------------------------------------
  // Manually specify GATT UUIDs (for Carista or unknown adapters)
  // -------------------------------------------------------------------------
  static Future<void> saveCustomProfile(String service, String write, String notify) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCustomServiceKey, service);
    await prefs.setString(_kCustomWriteKey, write);
    await prefs.setString(_kCustomNotifyKey, notify);
  }

  static Future<_BleProfile?> _loadCustomProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final svc = prefs.getString(_kCustomServiceKey);
    final wr = prefs.getString(_kCustomWriteKey);
    final nt = prefs.getString(_kCustomNotifyKey);
    if (svc == null || wr == null || nt == null) return null;
    return _BleProfile(service: svc, write: wr, notify: nt);
  }

  // -------------------------------------------------------------------------
  // List all GATT services+characteristics of the currently connected device.
  // Used by the BLE Inspector to identify the adapter's custom UUIDs.
  // -------------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> inspectServices() async {
    if (_connectedDevice == null) return [];
    try {
      final services = await _connectedDevice!.discoverServices();
      return services.map((s) => {
        'serviceUuid': s.uuid.str128,
        'characteristics': s.characteristics.map((c) => {
          'uuid': c.uuid.str128,
          'properties': {
            'read': c.properties.read,
            'write': c.properties.write,
            'writeWithoutResponse': c.properties.writeWithoutResponse,
            'notify': c.properties.notify,
            'indicate': c.properties.indicate,
          },
        }).toList(),
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // -------------------------------------------------------------------------
  // Send raw AT command string to the ELM327
  // -------------------------------------------------------------------------
  static Future<void> write(String command) async {
    if (_writeChar == null) throw Exception('Not connected');
    final bytes = utf8.encode('$command\r');
    final withoutResponse = _writeChar!.properties.writeWithoutResponse;
    await _writeChar!.write(bytes, withoutResponse: withoutResponse);
  }

  static Future<void> disconnect() async {
    try {
      await _notifyChar?.setNotifyValue(false);
    } catch (_) {}
    try {
      await _connectedDevice?.disconnect();
    } catch (_) {}
    _connectedDevice = null;
    _writeChar = null;
    _notifyChar = null;
  }

  static BluetoothService? _findService(List<BluetoothService> services, Guid uuid) {
    try {
      return services.firstWhere((s) => s.uuid == uuid);
    } catch (_) {
      return null;
    }
  }

  static BluetoothCharacteristic? _findChar(BluetoothService svc, Guid uuid) {
    try {
      return svc.characteristics.firstWhere((c) => c.uuid == uuid);
    } catch (_) {
      return null;
    }
  }
}
