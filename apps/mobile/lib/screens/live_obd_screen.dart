import 'dart:async';
import 'package:flutter/material.dart';
import '../services/obd_fusion_service.dart';
import '../services/obd2_adapter.dart';

class LiveObdScreen extends StatefulWidget {
  final String tripId;
  final String protocol;
  const LiveObdScreen({super.key, required this.tripId, required this.protocol});

  @override
  State<LiveObdScreen> createState() => _LiveObdScreenState();
}

class _LiveObdScreenState extends State<LiveObdScreen> {
  ObdReading? _reading;
  StreamSubscription<ObdReading?>? _sub;
  bool _disconnecting = false;

  @override
  void initState() {
    super.initState();
    _sub = ObdFusionService.readingStream.listen((r) {
      setState(() => _reading = r);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _disconnect() async {
    setState(() => _disconnecting = true);
    await ObdFusionService.disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final r = _reading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live OBD'),
        actions: [
          TextButton.icon(
            onPressed: _disconnecting ? null : _disconnect,
            icon: const Icon(Icons.bluetooth_disabled, color: Colors.white),
            label: const Text('Disconnect', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Protocol badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Protocol: ${widget.protocol}',
                style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 20),

            if (r == null) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 12),
              const Center(child: Text('Initialising OBD connection…')),
            ] else ...[
              // Large RPM + Speed display
              Row(
                children: [
                  Expanded(child: _bigGauge('RPM', r.rpm != null ? r.rpm!.toStringAsFixed(0) : '—', '')),
                  const SizedBox(width: 16),
                  Expanded(child: _bigGauge('Speed', r.speedKmh?.toString() ?? '—', 'km/h')),
                ],
              ),
              const SizedBox(height: 20),

              // Secondary stats grid
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (r.coolantTempC != null)
                    _statCard('Coolant', '${r.coolantTempC}°C',
                        color: r.coolantTempC! > 100 ? Colors.red.shade100 : null),
                  if (r.throttlePosPct != null)
                    _statCard('Throttle', '${r.throttlePosPct!.toStringAsFixed(1)}%'),
                  if (r.fuelLevelPct != null)
                    _statCard('Fuel', '${r.fuelLevelPct!.toStringAsFixed(1)}%',
                        color: r.fuelLevelPct! < 10 ? Colors.orange.shade100 : null),
                  if (r.intakeAirTempC != null)
                    _statCard('Air Temp', '${r.intakeAirTempC}°C'),
                  if (r.mafGps != null)
                    _statCard('MAF', '${r.mafGps!.toStringAsFixed(1)} g/s'),
                ],
              ),
              const SizedBox(height: 20),

              // Timestamp
              Text(
                'Last update: ${_formatTime(r.recordedAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),

              // Throttle bar
              if (r.throttlePosPct != null) ...[
                const SizedBox(height: 16),
                const Text('Throttle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: r.throttlePosPct! / 100.0,
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                      r.throttlePosPct! > 80 ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              ],

              // Fuel bar
              if (r.fuelLevelPct != null) ...[
                const SizedBox(height: 12),
                const Text('Fuel Level', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: r.fuelLevelPct! / 100.0,
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                      r.fuelLevelPct! < 10 ? Colors.red : Colors.blue,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _bigGauge(String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
          ),
          if (unit.isNotEmpty) Text(unit, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, {Color? color}) {
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}:${l.second.toString().padLeft(2, '0')}';
  }
}
