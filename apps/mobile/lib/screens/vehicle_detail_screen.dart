import 'package:flutter/material.dart';
import '../services/data_service.dart';
import 'trip_detail_screen.dart';

// Per-vehicle view: totals, open fault codes (clearable) and trip history.
class VehicleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> vehicle;
  const VehicleDetailScreen({super.key, required this.vehicle});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _dtcs = [];
  List<Map<String, dynamic>> _trips = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.vehicle['id'] as String;
    setState(() { _loading = true; _error = null; });
    try {
      final stats = await DataService.getVehicleStats(id);
      final dtcs = await DataService.getVehicleDtcs(id).catchError((_) => <Map<String, dynamic>>[]);
      final trips =
          await DataService.getVehicleTrips(id).catchError((_) => <Map<String, dynamic>>[]);
      if (!mounted) return;
      setState(() { _stats = stats; _dtcs = dtcs; _trips = trips; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clearDtcs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fehlercodes als behoben markieren?'),
        content: const Text(
          'Das markiert die Codes nur in dieser App als erledigt. '
          'Der Fehlerspeicher im Steuergerät wird NICHT gelöscht.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Markieren')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await DataService.clearVehicleDtcs(widget.vehicle['id'] as String);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  String _fmtDate(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vehicle;
    final s = _stats;
    final title = '${v['make']} ${v['model']}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ---- Header ----
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: v['protocolSupport'] == 'obd2'
                                ? Colors.blue
                                : (v['protocolSupport'] == 'gps_only' ? Colors.green : Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(v['protocolSupport'] as String? ?? '?',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Text(v['category'] as String? ?? '',
                            style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        if (v['year'] != null) ...[
                          const SizedBox(width: 8),
                          Text('${v['year']}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                        if (v['licensePlate'] != null) ...[
                          const SizedBox(width: 8),
                          Text(v['licensePlate'] as String,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ---- Stats ----
                    Row(
                      children: [
                        Expanded(child: _stat('Fahrten', '${s?['tripCount'] ?? 0}')),
                        Expanded(
                            child: _stat('Kilometer',
                                '${(s?['totalKm'] as num?)?.toStringAsFixed(1) ?? '0'}')),
                        Expanded(
                          child: _stat(
                            'Ø Score',
                            s?['avgScore'] != null
                                ? (s!['avgScore'] as num).toStringAsFixed(0)
                                : '—',
                          ),
                        ),
                      ],
                    ),
                    if (s?['lastTripAt'] != null) ...[
                      const SizedBox(height: 10),
                      Center(
                        child: Text('Letzte Fahrt: ${_fmtDate(s!['lastTripAt'] as String)}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                    ],
                    const Divider(height: 32),

                    // ---- Fault codes ----
                    Row(
                      children: [
                        const Text('Offene Fehlercodes',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Spacer(),
                        if (_dtcs.isNotEmpty)
                          TextButton(onPressed: _clearDtcs, child: const Text('Als behoben markieren')),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (_dtcs.isEmpty)
                      const Text('Keine offenen Fehler.',
                          style: TextStyle(color: Colors.green, fontSize: 13))
                    else
                      ..._dtcs.map((d) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.red.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Text(d['code'] as String,
                                    style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                const Spacer(),
                                Text(
                                  d['detectedAt'] != null
                                      ? _fmtDate(d['detectedAt'] as String)
                                      : '',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          )),
                    const Divider(height: 32),

                    // ---- Trips ----
                    const Text('Fahrten mit diesem Fahrzeug',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (_trips.isEmpty)
                      const Text('Noch keine Fahrten aufgezeichnet.',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ..._trips.map((t) {
                      final scoreStr = t['score']?.toString();
                      final score = scoreStr != null ? double.tryParse(scoreStr) : null;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          leading: score != null
                              ? CircleAvatar(
                                  radius: 16,
                                  backgroundColor: score >= 80
                                      ? Colors.green
                                      : (score >= 60 ? Colors.orange : Colors.red),
                                  child: Text(score.toStringAsFixed(0),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                )
                              : const CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.grey,
                                  child: Icon(Icons.route, size: 14, color: Colors.white)),
                          title: Text(_fmtDate(t['startedAt'] as String),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            t['distanceKm'] != null
                                ? '${double.parse(t['distanceKm'].toString()).toStringAsFixed(1)} km'
                                : '—',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 18),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => TripDetailScreen(trip: t),
                          )),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  Widget _stat(String label, String value) => Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );
}
