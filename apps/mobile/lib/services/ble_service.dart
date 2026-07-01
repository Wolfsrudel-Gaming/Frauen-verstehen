import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Known ELM327 BLE GATT service/characteristic UUIDs.
// Carista's real UUIDs must be confirmed by scanning (use BLE inspector in app).
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

// Represents a discovered BLE device with advertised services
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
  static bool get isConnected => _connectedDevice != null;

  // -------------------------------------------------------------------------
  // Scan for BLE devices (returns a stream of discovered devices)
  // -------------------------------------------------------------------------
  static Stream<DiscoveredDevice> scan({Duration timeout = const Duration(seconds: 10)}) {
    final controller = StreamController<DiscoveredDevice>();

    FlutterBluePlus.startScan(timeout: timeout).then((_) {
      controller.close();
    }).catchError(controller.addError);

    FlutterBluePlus.scanResults.listen((results) {
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

    return controller.stream;
  }

  static Future<void> stopScan() => FlutterBluePlus.stopScan();

  // -------------------------------------------------------------------------
  // Connect to a device and discover the ELM327 characteristics
  // -------------------------------------------------------------------------
  static Future<_BleProfile?> connect(BluetoothDevice device) async {
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

    // Profile not found — disconnect and signal failure so BLE inspector can run
    await disconnect();
    return null;
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
  // List all services+characteristics of the connected device (BLE inspector)
  // -------------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> inspectServices() async {
    if (_connectedDevice == null) return [];
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
  }

  // -------------------------------------------------------------------------
  // Send raw bytes / string to the ELM327
  // -------------------------------------------------------------------------
  static Future<void> write(String command) async {
    if (_writeChar == null) throw Exception('Not connected');
    final bytes = utf8.encode('$command\r');
    final withoutResponse = _writeChar!.properties.writeWithoutResponse;
    await _writeChar!.write(bytes, withoutResponse: withoutResponse);
  }

  static Future<void> disconnect() async {
    await _notifyChar?.setNotifyValue(false);
    await _connectedDevice?.disconnect();
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
