import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_service.dart';
import '../services/obd_fusion_service.dart';
import 'live_obd_screen.dart';

class BleScannerScreen extends StatefulWidget {
  final String tripId;
  const BleScannerScreen({super.key, required this.tripId});

  @override
  State<BleScannerScreen> createState() => _BleScannerScreenState();
}

class _BleScannerScreenState extends State<BleScannerScreen> {
  final List<DiscoveredDevice> _devices = [];
  bool _scanning = false;
  String? _connecting;
  String? _error;
  StreamSubscription<DiscoveredDevice>? _scanSub;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    BleService.stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() { _scanning = true; _devices.clear(); _error = null; });
    _scanSub = BleService.scan(timeout: const Duration(seconds: 12)).listen(
      (d) {
        if (!_devices.any((e) => e.device.remoteId == d.device.remoteId)) {
          setState(() => _devices.add(d));
        }
      },
      onDone: () => setState(() => _scanning = false),
      onError: (e) => setState(() { _scanning = false; _error = e.toString(); }),
    );
  }

  Future<void> _connect(DiscoveredDevice discovered) async {
    setState(() { _connecting = discovered.device.remoteId.str; _error = null; });
    try {
      final protocol = await ObdFusionService.connect(discovered.device, widget.tripId);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LiveObdScreen(tripId: widget.tripId, protocol: protocol),
        ),
      );
    } catch (e) {
      setState(() {
        _connecting = null;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect OBD Adapter'),
        actions: [
          if (_scanning)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            )
          else
            IconButton(icon: const Icon(Icons.refresh), onPressed: _startScan),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              color: Colors.red.shade50,
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: TextStyle(color: Colors.red.shade800)),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Select your Carista / ELM327 adapter below.\nIf it doesn\'t appear, make sure Bluetooth is on and the adapter is plugged in.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: _scanning
                        ? const Text('Scanning for BLE devices…')
                        : const Text('No devices found. Tap refresh to scan again.'),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (ctx, i) {
                      final d = _devices[i];
                      final isConnecting = _connecting == d.device.remoteId.str;
                      return ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('RSSI: ${d.rssi} dBm  ·  ${d.device.remoteId.str}'),
                        trailing: isConnecting
                            ? const SizedBox(
                                width: 24, height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: _connecting != null ? null : () => _connect(d),
                      );
                    },
                  ),
          ),
          // BLE Inspector tile
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings_ethernet, color: Colors.blue),
            title: const Text('BLE Inspector / Custom UUID Setup'),
            subtitle: const Text('Identify Carista GATT UUIDs after connecting'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const _BleInspectorScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BLE Inspector — shows raw services+characteristics after connecting.
// Use this to identify Carista's proprietary GATT UUIDs.
// ---------------------------------------------------------------------------
class _BleInspectorScreen extends StatefulWidget {
  const _BleInspectorScreen();

  @override
  State<_BleInspectorScreen> createState() => _BleInspectorScreenState();
}

class _BleInspectorScreenState extends State<_BleInspectorScreen> {
  List<Map<String, dynamic>> _services = [];
  bool _loading = false;

  final _svcCtrl = TextEditingController();
  final _writeCtrl = TextEditingController();
  final _notifyCtrl = TextEditingController();

  Future<void> _inspect() async {
    setState(() { _loading = true; });
    final svcs = await BleService.inspectServices();
    setState(() { _services = svcs; _loading = false; });
  }

  Future<void> _save() async {
    if (_svcCtrl.text.trim().isEmpty) return;
    await BleService.saveCustomProfile(
      _svcCtrl.text.trim(),
      _writeCtrl.text.trim(),
      _notifyCtrl.text.trim(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Custom UUIDs saved. Reconnect to use them.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE Inspector')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'After connecting to your adapter in the scanner, tap "Inspect" to see available GATT services. '
            'Find the service with write + notify characteristics — those are the ELM327 UUIDs to paste below.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _inspect, child: const Text('Inspect Connected Device')),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          ..._services.map((svc) => ExpansionTile(
                title: Text(svc['serviceUuid'] as String, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                children: (svc['characteristics'] as List).map((c) {
                  final props = c['properties'] as Map<String, dynamic>;
                  final flags = props.entries.where((e) => e.value == true).map((e) => e.key).join(', ');
                  return ListTile(
                    dense: true,
                    title: Text(c['uuid'] as String, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                    subtitle: Text(flags, style: const TextStyle(fontSize: 11)),
                  );
                }).toList(),
              )),
          const Divider(height: 32),
          const Text('Custom UUID Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(controller: _svcCtrl, decoration: const InputDecoration(labelText: 'Service UUID', isDense: true, border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _writeCtrl, decoration: const InputDecoration(labelText: 'Write Characteristic UUID', isDense: true, border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _notifyCtrl, decoration: const InputDecoration(labelText: 'Notify Characteristic UUID', isDense: true, border: OutlineInputBorder())),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _save, child: const Text('Save Custom UUIDs')),
        ],
      ),
    );
  }
}
