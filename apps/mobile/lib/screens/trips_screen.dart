import 'package:flutter/material.dart';
import '../services/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiService.getTrips(),
        ApiService.getVehicles(),
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

  Future<void> _startTrip() async {
    setState(() { _actionLoading = true; });
    try {
      await ApiService.startTrip(
        vehicleId: _selectedVehicleId,
        startOdometer: _odoCtrl.text.isNotEmpty ? int.tryParse(_odoCtrl.text) : null,
      );
      _odoCtrl.clear();
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

  Future<void> _endTrip(String tripId) async {
    setState(() { _actionLoading = true; });
    try {
      await ApiService.endTrip(
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
        content: const Text('This will mark the trip as discarded. This cannot be undone.'),
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
      await ApiService.discardTrip(tripId);
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
                      // ---- Active trip control ----
                      if (active != null) ...[
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
                                TextField(
                                  controller: _endOdoCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'End Odometer (km)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
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
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ---- Start trip form (if no active trip) ----
                      if (active == null) ...[
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
                                      ..._vehicles.map((v) => DropdownMenuItem(
                                            value: v['id'] as String,
                                            child: Text('${v['make']} ${v['model']}'),
                                          )),
                                    ],
                                    onChanged: (v) => setState(() => _selectedVehicleId = v),
                                  ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _odoCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Start Odometer (km, optional)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
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
                              leading: CircleAvatar(
                                backgroundColor: _statusColor(t['status'] as String),
                                radius: 6,
                              ),
                              title: Text(_formatDate(t['startedAt'] as String), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '${_duration(t['startedAt'] as String, t['endedAt'] as String?)}${t['distanceKm'] != null ? ' · ${double.parse(t['distanceKm'] as String).toStringAsFixed(1)} km' : ''}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              trailing: Text(
                                t['status'] as String,
                                style: TextStyle(color: _statusColor(t['status'] as String), fontSize: 12),
                              ),
                            ),
                          ))),
                    ],
                  ),
                ),
    );
  }
}
