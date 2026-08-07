import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/charts.dart';
import 'trip_map_screen.dart';

/// Everything recorded for one finished trip: score with its breakdown,
/// speed and engine curves, fault codes, and the route.
class TripDetailScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  List<Map<String, dynamic>> _obd = [];
  List<Map<String, dynamic>> _dtcs = [];
  List<Map<String, dynamic>> _points = [];
  bool _loading = true;

  static const _penaltyInfo = {
    'harshAccel': ('Starkes Beschleunigen', Icons.trending_up),
    'harshBrake': ('Starkes Bremsen', Icons.trending_down),
    'smoothness': ('Unruhige Fahrweise', Icons.show_chart),
    'overRev': ('Hohe Drehzahlen', Icons.speed),
    'overheat': ('Überhitzung', Icons.local_fire_department),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.trip['id'] as String;
    try {
      final results = await Future.wait([
        DataService.getTripObdReadings(id).catchError((_) => <Map<String, dynamic>>[]),
        DataService.getTripDtcs(id).catchError((_) => <Map<String, dynamic>>[]),
        DataService.getTripPoints(id).catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _obd = results[0];
        _dtcs = results[1];
        _points = results[2];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double? _num(dynamic v) => v == null
      ? null
      : (v is num ? v.toDouble() : double.tryParse(v.toString()));

  String _fmtDateTime(String iso) {
    final d = DateTime.parse(iso).toLocal();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}'
        ' · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} Uhr';
  }

  String _durationText() {
    final s = widget.trip['startedAt'] as String?;
    final e = widget.trip['endedAt'] as String?;
    if (s == null || e == null) return '—';
    final d = DateTime.parse(e).difference(DateTime.parse(s));
    return d.inMinutes < 60
        ? '${d.inMinutes} min'
        : '${d.inHours} h ${d.inMinutes % 60} min';
  }

  /// Seconds from trip start for each sample, used as the chart x-axis.
  List<double> _secondsSince(List<Map<String, dynamic>> rows, String key) {
    if (rows.isEmpty) return [];
    final t0 = DateTime.parse(rows.first[key] as String);
    return rows
        .map((r) =>
            DateTime.parse(r[key] as String).difference(t0).inSeconds.toDouble())
        .toList();
  }

  String _xLabel(double seconds) {
    final m = seconds ~/ 60;
    return m < 60 ? '${m}m' : '${m ~/ 60}h${(m % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final score = _num(t['score']);
    final breakdown = t['scoreBreakdown'] as Map<String, dynamic>?;
    final penalties = (breakdown?['penalties'] as Map<String, dynamic>?) ?? {};
    final metrics = (breakdown?['metrics'] as Map<String, dynamic>?) ?? {};
    final active = penalties.entries.where((e) => (e.value as num) > 0).toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));

    // Chart series
    final speedRows = _points.where((p) => p['speedKmh'] != null).toList();
    final speeds = speedRows.map((p) => _num(p['speedKmh'])!).toList();
    final speedXs = _secondsSince(speedRows, 'recordedAt');

    final rpmRows = _obd.where((r) => r['rpmX4'] != null).toList();
    final rpms = rpmRows.map((r) => _num(r['rpmX4'])! / 4).toList();
    final rpmXs = _secondsSince(rpmRows, 'recordedAt');

    final coolantRows = _obd.where((r) => r['coolantTempC'] != null).toList();
    final coolants = coolantRows.map((r) => _num(r['coolantTempC'])!).toList();
    final coolantXs = _secondsSince(coolantRows, 'recordedAt');

    final maxSpeed = speeds.isEmpty ? null : speeds.reduce((a, b) => a > b ? a : b);
    final avgSpeed =
        speeds.isEmpty ? null : speeds.reduce((a, b) => a + b) / speeds.length;
    final maxRpm = rpms.isEmpty ? null : rpms.reduce((a, b) => a > b ? a : b);
    final maxCoolant = coolants.isEmpty ? null : coolants.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fahrt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Route auf Karte',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => TripMapScreen(
                tripId: t['id'] as String,
                tripDate: _fmtDateTime(t['startedAt'] as String),
              ),
            )),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(_fmtDateTime(t['startedAt'] as String),
                    style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
                const SizedBox(height: 16),

                // ---- Score hero ----
                if (score != null) _scoreCard(score, active, metrics) else _noScoreCard(),
                const SizedBox(height: 20),

                // ---- Key figures ----
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.0,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    StatTile(
                      icon: Icons.straighten,
                      label: 'Strecke',
                      value: t['distanceKm'] != null
                          ? '${double.parse(t['distanceKm'].toString()).toStringAsFixed(2)} km'
                          : '—',
                      color: AppTheme.brand,
                    ),
                    StatTile(
                      icon: Icons.schedule,
                      label: 'Dauer',
                      value: _durationText(),
                      color: Colors.indigo,
                    ),
                    StatTile(
                      icon: Icons.speed,
                      label: 'Höchsttempo',
                      value: maxSpeed != null ? '${maxSpeed.toStringAsFixed(0)} km/h' : '—',
                      color: AppTheme.warn,
                    ),
                    StatTile(
                      icon: Icons.trending_flat,
                      label: 'Ø Tempo',
                      value: avgSpeed != null ? '${avgSpeed.toStringAsFixed(0)} km/h' : '—',
                      color: Colors.teal,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ---- Speed curve ----
                const SectionHeader('Geschwindigkeitsverlauf'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                    child: speeds.length < 2
                        ? const EmptyState(
                            icon: Icons.show_chart,
                            title: 'Kein Geschwindigkeitsverlauf',
                            message: 'Für diese Fahrt wurden zu wenige GPS-Punkte aufgezeichnet.',
                          )
                        : SeriesChart(
                            xs: speedXs,
                            ys: speeds,
                            color: AppTheme.brand,
                            unit: 'km/h',
                            xLabel: _xLabel,
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // ---- Engine data ----
                SectionHeader('Motordaten',
                    action: _obd.isNotEmpty
                        ? Text('${_obd.length} Messwerte',
                            style: const TextStyle(fontSize: 12, color: AppTheme.muted))
                        : null),
                if (_obd.isEmpty)
                  Card(
                    child: const EmptyState(
                      icon: Icons.bluetooth_disabled,
                      title: 'Keine OBD-Daten',
                      message:
                          'Für diese Fahrt war kein Adapter verbunden. Verbinde den Carista '
                          'vor der Fahrt, um Drehzahl und Temperaturen mit aufzuzeichnen.',
                    ),
                  )
                else ...[
                  if (rpms.length >= 2) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('Drehzahl',
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                const Spacer(),
                                if (maxRpm != null)
                                  Text('max. ${maxRpm.toStringAsFixed(0)} U/min',
                                      style: const TextStyle(
                                          fontSize: 12, color: AppTheme.muted)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SeriesChart(
                              xs: rpmXs,
                              ys: rpms,
                              color: AppTheme.good,
                              unit: 'U/min',
                              xLabel: _xLabel,
                              maxYHint: 5000,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (coolants.length >= 2)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('Kühlmitteltemperatur',
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                const Spacer(),
                                if (maxCoolant != null)
                                  Text('max. ${maxCoolant.toStringAsFixed(0)} °C',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight:
                                              maxCoolant > 105 ? FontWeight.w700 : null,
                                          color: maxCoolant > 105
                                              ? AppTheme.bad
                                              : AppTheme.muted)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SeriesChart(
                              xs: coolantXs,
                              ys: coolants,
                              color: AppTheme.warn,
                              unit: '°C',
                              xLabel: _xLabel,
                              maxYHint: 120,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 24),

                // ---- Fault codes ----
                const SectionHeader('Fehlercodes'),
                if (_dtcs.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppTheme.good, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text('Keine Fehlercodes während dieser Fahrt.',
                                style: TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._dtcs.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            leading: Icon(
                              d['clearedAt'] != null
                                  ? Icons.check_circle_outline
                                  : Icons.warning_amber,
                              color: d['clearedAt'] != null ? AppTheme.muted : AppTheme.bad,
                            ),
                            title: Text(d['code'] as String,
                                style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15)),
                            subtitle: Text(
                              d['clearedAt'] != null ? 'als behoben markiert' : 'offen',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: d['severity'] != null
                                ? StatusPill(d['severity'] as String, color: AppTheme.bad)
                                : null,
                          ),
                        ),
                      )),

                if (t['notes'] != null) ...[
                  const SizedBox(height: 24),
                  const SectionHeader('Notizen'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(t['notes'] as String),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _scoreCard(
    double score,
    List<MapEntry<String, dynamic>> active,
    Map<String, dynamic> metrics,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                ScoreRing(score: score, size: 96),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppTheme.scoreLabel(score),
                          style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.scoreColor(score))),
                      const SizedBox(height: 4),
                      Text(
                        active.isEmpty
                            ? 'Keine Auffälligkeiten in dieser Fahrt.'
                            : '${active.length} ${active.length == 1 ? 'Auffälligkeit' : 'Auffälligkeiten'} erkannt',
                        style: const TextStyle(fontSize: 13, color: AppTheme.muted),
                      ),
                      if (metrics['points'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${metrics['points']} GPS-Punkte · ${metrics['obdReadings'] ?? 0} OBD-Werte',
                          style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (active.isNotEmpty) ...[
              const Divider(height: 28),
              ...active.map((e) {
                final info = _penaltyInfo[e.key];
                final penalty = (e.value as num).toDouble();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Icon(info?.$2 ?? Icons.remove_circle_outline,
                          size: 17, color: AppTheme.bad),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(info?.$1 ?? e.key, style: const TextStyle(fontSize: 14)),
                      ),
                      SizedBox(
                        width: 90,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (penalty / 40).clamp(0.05, 1.0),
                            minHeight: 6,
                            backgroundColor: AppTheme.line,
                            valueColor: const AlwaysStoppedAnimation(AppTheme.bad),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 42,
                        child: Text('−${penalty.toStringAsFixed(1)}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                color: AppTheme.bad,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _noScoreCard() => Card(
        child: const EmptyState(
          icon: Icons.speed,
          title: 'Keine Bewertung',
          message:
              'Für eine Bewertung braucht diese Fahrt mehr GPS-Punkte und mindestens '
              '300 m Strecke.',
        ),
      );
}
