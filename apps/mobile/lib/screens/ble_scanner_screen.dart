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
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _connecting = null;
        _error = msg;
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_error!, style: TextStyle(color: Colors.red.shade800)),
                  const SizedBox(height: 6),
                  Text(
                    'If this is a Carista adapter, use "BLE Inspector" below to find its UUIDs.',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Select your Carista / ELM327 adapter below.\n'
              'Make sure Bluetooth is enabled and the adapter is plugged into the OBD port.',
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
          // BLE Inspector tile — scan+connect flow is self-contained in the inspector
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings_ethernet, color: Colors.blue),
            title: const Text('BLE Inspector / Custom UUID Setup'),
            subtitle: const Text('Identify Carista GATT UUIDs (use when adapter connects but OBD fails)'),
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
// BLE Inspector — scan, connect, enumerate raw GATT services.
// Self-contained: has its own scan so it does not depend on the OBD connect flow.
// ---------------------------------------------------------------------------
class _BleInspectorScreen extends StatefulWidget {
  const _BleInspectorScreen();

  @override
  State<_BleInspectorScreen> createState() => _BleInspectorScreenState();
}

class _BleInspectorScreenState extends State<_BleInspectorScreen> {
  // Scan state
  final List<DiscoveredDevice> _devices = [];
  bool _scanning = false;
  StreamSubscription<DiscoveredDevice>? _scanSub;

  // Inspect state
  List<Map<String, dynamic>> _services = [];
  bool _inspecting = false;
  String? _connectedName;
  String? _error;

  // Custom UUID input
  final _svcCtrl = TextEditingController();
  final _writeCtrl = TextEditingController();
  final _notifyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // If already BLE-connected (e.g., after a failed OBD connect attempt), auto-inspect
    if (BleService.isBleConnected) {
      _connectedName = BleService.connectedDevice?.platformName;
      _inspect();
    } else {
      _startScan();
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    BleService.stopScan();
    _svcCtrl.dispose();
    _writeCtrl.dispose();
    _notifyCtrl.dispose();
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

  Future<void> _connectAndInspect(DiscoveredDevice d) async {
    setState(() { _inspecting = true; _error = null; });
    try {
      await BleService.connectRaw(d.device);
      _connectedName = d.name;
      await _inspect();
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      setState(() { _inspecting = false; });
    }
  }

  Future<void> _inspect() async {
    setState(() { _inspecting = true; });
    final svcs = await BleService.inspectServices();
    setState(() { _services = svcs; _inspecting = false; });
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
        const SnackBar(content: Text('Custom UUIDs saved. Return to scanner and reconnect.')),
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
            'Step 1: Connect to your adapter below to enumerate its GATT services.\n'
            'Step 2: Find the service with write + notify characteristics.\n'
            'Step 3: Paste those UUIDs into the fields at the bottom and tap Save.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // --- Already connected indicator ---
          if (_connectedName != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.bluetooth_connected, color: Colors.green.shade700, size: 18),
                  const SizedBox(width: 8),
                  Text('Connected to $_connectedName', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(onPressed: _inspect, child: const Text('Re-Inspect')),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // --- Device scanner (shown when not yet connected) ---
          if (_connectedName == null) ...[
            Row(
              children: [
                const Text('Nearby BLE Devices', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_scanning)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  TextButton.icon(
                    onPressed: _startScan,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Rescan'),
                  ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            if (_devices.isEmpty && !_scanning)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('No devices found.', style: TextStyle(color: Colors.grey))),
              ),
            ..._devices.map((d) => ListTile(
              dense: true,
              leading: const Icon(Icons.bluetooth, size: 18),
              title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('RSSI ${d.rssi} dBm  ·  ${d.device.remoteId.str}', style: const TextStyle(fontSize: 11)),
              trailing: _inspecting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chevron_right),
              onTap: _inspecting ? null : () => _connectAndInspect(d),
            )),
            const SizedBox(height: 12),
          ],

          // --- GATT service tree ---
          if (_inspecting && _services.isEmpty)
            const LinearProgressIndicator(),
          if (_services.isNotEmpty) ...[
            const Text('GATT Services', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            ..._services.map((svc) => ExpansionTile(
              dense: true,
              title: Text(
                svc['serviceUuid'] as String,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              children: (svc['characteristics'] as List).map((c) {
                final props = c['properties'] as Map<String, dynamic>;
                final flags = props.entries
                    .where((e) => e.value == true)
                    .map((e) => e.key)
                    .join(', ');
                final hasWrite = (props['write'] == true || props['writeWithoutResponse'] == true);
                final hasNotify = (props['notify'] == true || props['indicate'] == true);
                final isCandidate = hasWrite && hasNotify;
                return ListTile(
                  dense: true,
                  tileColor: isCandidate ? Colors.blue.shade50 : null,
                  title: Text(
                    c['uuid'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: isCandidate ? Colors.blue.shade800 : null,
                      fontWeight: isCandidate ? FontWeight.bold : null,
                    ),
                  ),
                  subtitle: Text(flags, style: const TextStyle(fontSize: 11)),
                  trailing: isCandidate
                      ? Tooltip(
                          message: 'Has both write and notify — likely the OBD characteristic',
                          child: Icon(Icons.star, size: 14, color: Colors.blue.shade600),
                        )
                      : null,
                );
              }).toList(),
            )),
            const SizedBox(height: 4),
            Text(
              '★ = has write + notify — these are the UUIDs to use',
              style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
            ),
          ],

          const Divider(height: 32),
          const Text('Custom UUID Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
            'Copy the service UUID and the write + notify characteristic UUIDs from above.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _svcCtrl,
            decoration: const InputDecoration(
              labelText: 'Service UUID',
              isDense: true,
              border: OutlineInputBorder(),
              hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _writeCtrl,
            decoration: const InputDecoration(
              labelText: 'Write Characteristic UUID',
              isDense: true,
              border: OutlineInputBorder(),
              hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notifyCtrl,
            decoration: const InputDecoration(
              labelText: 'Notify Characteristic UUID',
              isDense: true,
              border: OutlineInputBorder(),
              hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _save, child: const Text('Save Custom UUIDs')),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
