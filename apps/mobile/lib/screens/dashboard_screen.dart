import 'package:flutter/material.dart';
import '../services/app_mode.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/charts.dart';
import 'trip_detail_screen.dart';

/// Home tab: how you are driving overall, at a glance.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _trips = [];
  List<Map<String, dynamic>> _leaderboard = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await DataService.getOverviewStats();
      final trips = await DataService.getTrips();
      List<Map<String, dynamic>> board = [];
      if (!AppMode.isOffline) {
        try {
          board = await DataService.getLeaderboard(range: 'month');
        } catch (_) {
          // optional — never fail the dashboard for it
        }
      }
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _trips = trips.where((t) => t['status'] == 'completed').toList();
        _leaderboard = board;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double? _num(dynamic v) => v == null
      ? null
      : (v is num ? v.toDouble() : double.tryParse(v.toString()));

  String _fmtDate(String iso) {
    final d = DateTime.parse(iso).toLocal();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.'
        ' ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  /// Kilometres per day for the last 7 days, oldest first.
  (List<double>, List<String>) _weekKm() {
    const dayNames = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    final today = DateTime.now();
    final values = <double>[];
    final labels = <String>[];
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(today.year, today.month, today.day).subtract(Duration(days: i));
      final next = day.add(const Duration(days: 1));
      double km = 0;
      for (final t in _trips) {
        final started = DateTime.parse(t['startedAt'] as String).toLocal();
        if (started.isAfter(day) && started.isBefore(next)) {
          km += _num(t['distanceKm']) ?? 0;
        }
      }
      values.add(km);
      labels.add(dayNames[day.weekday - 1]);
    }
    return (values, labels);
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    final avg = _num(s?['avgScore']);

    // Score trend: oldest → newest, last 12 scored trips
    final scored = _trips.where((t) => t['score'] != null).toList().reversed.toList();
    final trend = scored.map((t) => _num(t['score'])!).toList();
    final trendTail = trend.length > 12 ? trend.sublist(trend.length - 12) : trend;

    final (weekValues, weekLabels) = _weekKm();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Übersicht'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Aktualisieren',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  icon: Icons.cloud_off,
                  title: 'Daten nicht abrufbar',
                  message: _error,
                  action: FilledButton(onPressed: _load, child: const Text('Erneut versuchen')),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      // ---- Score hero ----
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: avg == null
                              ? const EmptyState(
                                  icon: Icons.emoji_events_outlined,
                                  title: 'Noch kein Score',
                                  message:
                                      'Zeichne eine Fahrt mit mindestens 300 m Strecke auf — '
                                      'danach erscheint hier deine Bewertung.',
                                )
                              : Row(
                                  children: [
                                    ScoreRing(score: avg, size: 104),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Dein Fahrstil',
                                              style: TextStyle(
                                                  fontSize: 13, color: AppTheme.muted)),
                                          Text(
                                            AppTheme.scoreLabel(avg),
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.scoreColor(avg),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${s?['scoredTrips'] ?? 0} bewertete Fahrten'
                                            '${s?['bestScore'] != null ? ' · Bestwert ${_num(s!['bestScore'])!.toStringAsFixed(0)}' : ''}',
                                            style: const TextStyle(
                                                fontSize: 12, color: AppTheme.muted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ---- Score trend ----
                      if (trendTail.length >= 2) ...[
                        const SectionHeader('Score-Entwicklung'),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
                            child: Column(
                              children: [
                                SeriesChart(
                                  xs: List.generate(trendTail.length, (i) => i.toDouble()),
                                  ys: trendTail,
                                  color: AppTheme.scoreColor(trendTail.last),
                                  unit: 'Punkte',
                                  maxYHint: 100,
                                  height: 150,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Die letzten ${trendTail.length} bewerteten Fahrten '
                                  '(älteste links)',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ---- Week kilometres ----
                      const SectionHeader('Kilometer diese Woche'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
                          child: LabelledBarChart(
                            values: weekValues,
                            labels: weekLabels,
                            unit: 'km',
                            color: AppTheme.brand,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ---- Totals ----
                      const SectionHeader('Gesamt'),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.85,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        children: [
                          StatTile(
                            icon: Icons.route,
                            label: 'Fahrten',
                            value: '${s?['tripCount'] ?? 0}',
                            color: AppTheme.brand,
                          ),
                          StatTile(
                            icon: Icons.straighten,
                            label: 'Kilometer',
                            value: (_num(s?['totalKm']) ?? 0).toStringAsFixed(1),
                            color: Colors.teal,
                          ),
                          StatTile(
                            icon: Icons.schedule,
                            label: 'Stunden',
                            value: (_num(s?['totalHours']) ?? 0).toStringAsFixed(1),
                            color: Colors.indigo,
                          ),
                          StatTile(
                            icon: Icons.directions_car,
                            label: 'Fahrzeuge',
                            value: '${s?['activeVehicles'] ?? 0}',
                            color: Colors.brown,
                          ),
                          StatTile(
                            icon: Icons.memory,
                            label: 'OBD-Messwerte',
                            value: '${s?['obdReadings'] ?? 0}',
                            color: Colors.purple,
                          ),
                          StatTile(
                            icon: Icons.warning_amber,
                            label: 'Offene Fehler',
                            value: '${s?['openDtcs'] ?? 0}',
                            color: ((s?['openDtcs'] as num?) ?? 0) > 0
                                ? AppTheme.bad
                                : AppTheme.muted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ---- Recent trips ----
                      const SectionHeader('Letzte Fahrten'),
                      if (_trips.isEmpty)
                        Card(
                          child: const EmptyState(
                            icon: Icons.route_outlined,
                            title: 'Noch keine Fahrten',
                            message:
                                'Starte im Tab „Fahrten" eine Aufzeichnung — oder aktiviere '
                                'die automatische Erkennung, die Fahrten selbst erkennt.',
                          ),
                        )
                      else
                        ..._trips.take(5).map(_tripTile),

                      // ---- Leaderboard ----
                      if (!AppMode.isOffline && _leaderboard.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const SectionHeader('Leaderboard (30 Tage)'),
                        Card(
                          child: Column(
                            children: [
                              for (int i = 0; i < _leaderboard.take(5).length; i++) ...[
                                if (i > 0) const Divider(height: 1),
                                _leaderboardRow(_leaderboard[i]),
                              ],
                            ],
                          ),
                        ),
                      ],

                      if (AppMode.isOffline) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.brand.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.cloud_off, size: 18, color: AppTheme.brand),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Offline-Modus: Alle Daten liegen nur auf diesem Gerät. '
                                  'Ein Leaderboard gibt es erst mit Server-Anbindung.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _tripTile(Map<String, dynamic> t) {
    final score = _num(t['score']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: score != null
              ? ScoreRing(score: score, size: 44)
              : Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                      color: AppTheme.surfaceAlt, shape: BoxShape.circle),
                  child: const Icon(Icons.route, size: 18, color: AppTheme.muted),
                ),
          title: Text(_fmtDate(t['startedAt'] as String),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text(
            t['distanceKm'] != null
                ? '${_num(t['distanceKm'])!.toStringAsFixed(1)} km'
                : 'ohne Streckendaten',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.muted),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TripDetailScreen(trip: t)),
          ),
        ),
      ),
    );
  }

  Widget _leaderboardRow(Map<String, dynamic> e) {
    final rank = e['rank'] as int? ?? 0;
    final score = _num(e['score']);
    return ListTile(
      dense: true,
      leading: SizedBox(
        width: 28,
        child: Text(
          rank == 1 ? '🥇' : (rank == 2 ? '🥈' : (rank == 3 ? '🥉' : '$rank')),
          style: const TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ),
      title: Text(e['username'] as String? ?? '—',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text('${e['tripCount']} Fahrten', style: const TextStyle(fontSize: 12)),
      trailing: score == null
          ? const Text('—')
          : Text(score.toStringAsFixed(0),
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: AppTheme.scoreColor(score))),
    );
  }
}
