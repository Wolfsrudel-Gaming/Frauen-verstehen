import 'dart:async';
import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../services/obd_fusion_service.dart';
import '../services/trip_detection_service.dart';
import 'ble_scanner_screen.dart';
import 'live_obd_screen.dart';
import 'live_trip_screen.dart';
import 'trip_detail_screen.dart';
import 'trip_map_screen.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  List<Map<String, dynamic>> _trips = [];
  List<Map<String, dynamic>> _vehicles = [];
  bool _loading = true;
  String? _error;
  bool _actionLoading = false;

  String? _selectedVehicleId;
  final _odoCtrl = TextEditingController();
  final _endOdoCtrl = TextEditingController();

  TripState _autoState = TripDetectionService.state;
  StreamSubscription<TripState>? _stateSub;
  bool _autoDetect = false;

  @override
  void initState() {
    super.initState();
    _stateSub = TripDetectionService.stateStream.listen((s) {
      setState(() { _autoState = s; });
      // Auto-refresh trip list when a trip auto-starts or auto-ends
      if (s == TripState.inTrip || s == TripState.idle) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        DataService.getTrips(),
        DataService.getVehicles(),
      ]);
      setState(() {
        _trips = results[0];
        _vehicles = results[1].where((v) => v['isActive'] == true).toList();
      });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Map<String, dynamic>? get _activeTrip {
    try {
      return _trips.firstWhere((t) => t['status'] == 'in_progress');
    } catch (_) {
      return null;
    }
  }

  Future<void> _toggleAutoDetect(bool enabled) async {
    if (enabled) {
      await TripDetectionService.start();
    } else {
      await TripDetectionService.stop();
    }
    setState(() { _autoDetect = enabled; });
  }

  Future<void> _startTrip() async {
    setState(() { _actionLoading = true; });
    try {
      final trip = await DataService.startTrip(
        vehicleId: _selectedVehicleId,
        startOdometer: _odoCtrl.text.isNotEmpty ? int.tryParse(_odoCtrl.text) : null,
      );
      _odoCtrl.clear();
      final tripId = trip['id'] as String;

      // Start GPS recording for the manual trip and jump to the live view
      String? gpsWarning;
      try {
        await TripDetectionService.attachManual(tripId);
      } catch (e) {
        gpsWarning = e.toString().replaceFirst('Exception: ', '');
      }

      await _load();
      if (!mounted) return;
      if (gpsWarning != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(gpsWarning)));
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LiveTripScreen(tripId: tripId)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      setState(() { _actionLoading = false; });
    }
  }

  Future<void> _openLiveView(String tripId) async {
    // After an app restart the recorder may not be attached anymore —
    // re-attach so the live view has data again.
    if (!TripDetectionService.isManualRecording &&
        !(_autoDetect && _autoState == TripState.inTrip)) {
      try {
        await TripDetectionService.attachManual(tripId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
          );
        }
      }
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LiveTripScreen(tripId: tripId)),
    );
  }

  Future<void> _endTrip(String tripId) async {
    setState(() { _actionLoading = true; });
    try {
      // Stop GPS recording first so the final buffer is flushed
      await TripDetectionService.detachManual();
      await DataService.endTrip(
        tripId,
        endOdometer: _endOdoCtrl.text.isNotEmpty ? int.tryParse(_endOdoCtrl.text) : null,
      );
      _endOdoCtrl.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      setState(() { _actionLoading = false; });
    }
  }

  Future<void> _discardTrip(String tripId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Trip?'),
        content: const Text('This will mark the trip as discarded.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() { _actionLoading = true; });
    try {
      await TripDetectionService.detachManual();
      await DataService.discardTrip(tripId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      setState(() { _actionLoading = false; });
    }
  }

  String _formatDate(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _duration(String start, String? end) {
    if (end == null) return 'in progress';
    final ms = DateTime.parse(end).difference(DateTime.parse(start));
    final mins = ms.inMinutes;
    if (mins < 60) return '$mins min';
    return '${ms.inHours}h ${mins % 60}min';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'in_progress': return Colors.orange;
      case 'completed': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _autoStateLabel() {
    switch (_autoState) {
      case TripState.idle: return 'Watching for movement…';
      case TripState.detecting: return 'Movement detected — confirming…';
      case TripState.inTrip: return 'Auto-trip in progress';
      case TripState.stopping: return 'Stopped — waiting to finalize…';
    }
  }

  // Score badge: colored circle with the driving score, grey dot when unscored
  Widget _scoreBadge(Map<String, dynamic> t) {
    final scoreStr = t['score'] as String?;
    if (scoreStr == null || t['status'] == 'discarded') {
      return CircleAvatar(
        backgroundColor: _statusColor(t['status'] as String),
        radius: 8,
      );
    }
    final score = double.parse(scoreStr);
    final color = score >= 80
        ? Colors.green
        : score >= 60
            ? Colors.orange
            : Colors.red;
    return CircleAvatar(
      backgroundColor: color,
      radius: 20,
      child: Text(
        score.toStringAsFixed(0),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final active = _activeTrip;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trips'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ---- Auto-detection toggle ----
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Auto Trip Detection', style: TextStyle(fontWeight: FontWeight.bold)),
                                    if (_autoDetect)
                                      Text(_autoStateLabel(), style: TextStyle(fontSize: 12, color: _autoState == TripState.inTrip ? Colors.green : Colors.grey)),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _autoDetect,
                                onChanged: _toggleAutoDetect,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ---- Active trip control ----
                      if (active != null && !(_autoDetect && _autoState == TripState.inTrip)) ...[
                        Card(
                          color: Colors.orange.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Active Trip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text('Started: ${_formatDate(active['startedAt'] as String)}', style: const TextStyle(fontSize: 13)),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _openLiveView(active['id'] as String),
                                    icon: const Icon(Icons.navigation),
                                    label: const Text('Live-Ansicht (Karte, Tacho, OBD)'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black87,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _endOdoCtrl,
                                  decoration: const InputDecoration(labelText: 'End Odometer (km)', isDense: true, border: OutlineInputBorder()),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _actionLoading ? null : () => _endTrip(active['id'] as String),
                                        icon: const Icon(Icons.stop_circle),
                                        label: const Text('End Trip'),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: _actionLoading ? null : () => _discardTrip(active['id'] as String),
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      label: const Text('Discard', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _ObdConnectButton(tripId: active['id'] as String),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ---- Start trip form ----
                      if (active == null && !_autoDetect) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Start New Trip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 12),
                                if (_vehicles.isNotEmpty)
                                  DropdownButtonFormField<String?>(
                                    value: _selectedVehicleId,
                                    decoration: const InputDecoration(labelText: 'Vehicle', isDense: true, border: OutlineInputBorder()),
                                    items: [
                                      const DropdownMenuItem(value: null, child: Text('— no vehicle —')),
                                      ..._vehicles.map((v) => DropdownMenuItem(value: v['id'] as String, child: Text('${v['make']} ${v['model']}'))),
                                    ],
                                    onChanged: (v) => setState(() => _selectedVehicleId = v),
                                  ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _odoCtrl,
                                  decoration: const InputDecoration(labelText: 'Start Odometer (km, optional)', isDense: true, border: OutlineInputBorder()),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _actionLoading ? null : _startTrip,
                                    icon: const Icon(Icons.play_circle),
                                    label: const Text('Start Trip'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ---- Trip history ----
                      const Text('Trip History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      ...(_trips.where((t) => t['status'] != 'in_progress').map((t) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: _scoreBadge(t),
                              title: Text(_formatDate(t['startedAt'] as String), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '${_duration(t['startedAt'] as String, t['endedAt'] as String?)}${t['distanceKm'] != null ? ' · ${double.parse(t['distanceKm'] as String).toStringAsFixed(1)} km' : ''}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => TripDetailScreen(trip: t),
                              )),
                              trailing: IconButton(
                                icon: const Icon(Icons.map, color: Colors.blue),
                                tooltip: 'View on map',
                                onPressed: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => TripMapScreen(
                                      tripId: t['id'] as String,
                                      tripDate: _formatDate(t['startedAt'] as String),
                                    ),
                                  ));
                                },
                              ),
                            ),
                          ))),
                    ],
                  ),
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// OBD Connect button — shown on an active trip card.
// Navigates to BLE scanner if not connected; shows live screen if already connected.
// ---------------------------------------------------------------------------
class _ObdConnectButton extends StatefulWidget {
  final String tripId;
  const _ObdConnectButton({required this.tripId});

  @override
  State<_ObdConnectButton> createState() => _ObdConnectButtonState();
}

class _ObdConnectButtonState extends State<_ObdConnectButton> {
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _connected = ObdFusionService.isConnected;
  }

  @override
  Widget build(BuildContext context) {
    if (_connected) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            final protocol = ObdFusionService.elmProtocol ?? 'OBD';
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LiveObdScreen(tripId: widget.tripId, protocol: protocol),
              ),
            );
          },
          icon: const Icon(Icons.bluetooth_connected),
          label: const Text('View Live OBD'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BleScannerScreen(tripId: widget.tripId),
            ),
          );
        },
        icon: const Icon(Icons.bluetooth_searching),
        label: const Text('Connect OBD Adapter'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
