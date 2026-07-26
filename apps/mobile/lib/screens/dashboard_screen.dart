import 'package:flutter/material.dart';
import '../services/app_mode.dart';
import '../services/data_service.dart';
import 'trip_detail_screen.dart';

// Overview tab: totals, average score, open faults, recent trips.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _recentTrips = [];
  List<Map<String, dynamic>> _leaderboard = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final stats = await DataService.getOverviewStats();
      final trips = await DataService.getTrips();
      List<Map<String, dynamic>> board = [];
      try {
        board = await DataService.getLeaderboard(range: 'month');
      } catch (_) {
        // leaderboard is optional — never fail the dashboard for it
      }
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _recentTrips =
            trips.where((t) => t['status'] == 'completed').take(5).toList();
        _leaderboard = board;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  String _fmtDate(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}. '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _scoreColor(double s) =>
      s >= 80 ? Colors.green : (s >= 60 ? Colors.orange : Colors.red);

  @override
  Widget build(BuildContext context) {
    final s = _stats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Übersicht'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ---- Average score hero ----
                      if (s?['avgScore'] != null) ...[
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _scoreColor((s!['avgScore'] as num).toDouble()),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      (s['avgScore'] as num).toStringAsFixed(0),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 44,
                                        fontWeight: FontWeight.w800,
                                        height: 1,
                                      ),
                                    ),
                                    const Text('Ø Score',
                                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'aus ${s['scoredTrips']} bewerteten Fahrten'
                                '${s['bestScore'] != null ? '  ·  Bestwert ${(s['bestScore'] as num).toStringAsFixed(0)}' : ''}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ---- Stat tiles ----
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.9,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        children: [
                          _tile(Icons.route, 'Fahrten', '${s?['tripCount'] ?? 0}', Colors.blue),
                          _tile(Icons.straighten, 'Kilometer',
                              '${(s?['totalKm'] as num?)?.toStringAsFixed(1) ?? '0'}', Colors.teal),
                          _tile(Icons.schedule, 'Stunden',
                              '${(s?['totalHours'] as num?)?.toStringAsFixed(1) ?? '0'}', Colors.indigo),
                          _tile(Icons.directions_car, 'Fahrzeuge',
                              '${s?['activeVehicles'] ?? 0}', Colors.brown),
                          _tile(Icons.memory, 'OBD-Werte',
                              '${s?['obdReadings'] ?? 0}', Colors.purple),
                          _tile(
                            Icons.warning_amber,
                            'Offene Fehler',
                            '${s?['openDtcs'] ?? 0}',
                            (s?['openDtcs'] as num?) != null && (s!['openDtcs'] as num) > 0
                                ? Colors.red
                                : Colors.grey,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ---- Recent trips ----
                      const Text('Letzte Fahrten',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      if (_recentTrips.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Noch keine abgeschlossenen Fahrten.',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ..._recentTrips.map((t) {
                        final scoreStr = t['score'] as String?;
                        final score = scoreStr != null ? double.tryParse(scoreStr) : null;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: score != null
                                ? CircleAvatar(
                                    backgroundColor: _scoreColor(score),
                                    radius: 18,
                                    child: Text(score.toStringAsFixed(0),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                  )
                                : const CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.grey,
                                    child: Icon(Icons.route, size: 16, color: Colors.white),
                                  ),
                            title: Text(_fmtDate(t['startedAt'] as String),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              t['distanceKm'] != null
                                  ? '${double.parse(t['distanceKm'] as String).toStringAsFixed(1)} km'
                                  : 'ohne Streckendaten',
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => TripDetailScreen(trip: t),
                            )),
                          ),
                        );
                      }),

                      // ---- Leaderboard (online only) ----
                      if (!AppMode.isOffline && _leaderboard.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Leaderboard (30 Tage)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        ..._leaderboard.take(5).map((e) => ListTile(
                              dense: true,
                              leading: Text(
                                e['rank'] == 1
                                    ? '🥇'
                                    : e['rank'] == 2
                                        ? '🥈'
                                        : e['rank'] == 3
                                            ? '🥉'
                                            : '${e['rank']}',
                                style: const TextStyle(fontSize: 18),
                              ),
                              title: Text(e['username'] as String? ?? '—'),
                              subtitle: Text('${e['tripCount']} Fahrten',
                                  style: const TextStyle(fontSize: 12)),
                              trailing: Text(
                                '${(e['score'] as num?)?.toStringAsFixed(0) ?? '—'}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            )),
                      ],

                      if (AppMode.isOffline) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Offline-Modus: Alle Daten liegen nur auf diesem Gerät. '
                            'Ein Leaderboard gibt es erst mit Server-Anbindung.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _tile(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
