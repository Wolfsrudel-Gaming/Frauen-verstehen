import 'package:flutter/material.dart';
import '../services/data_service.dart';
import 'trip_map_screen.dart';

// Full detail of a completed trip: score breakdown, OBD summary, fault
// codes and a shortcut to the route map.
class TripDetailScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  List<Map<String, dynamic>> _obd = [];
  List<Map<String, dynamic>> _dtcs = [];
  int _pointCount = 0;
  bool _loading = true;

  static const _penaltyLabels = {
    'harshAccel': 'Starkes Beschleunigen',
    'harshBrake': 'Starkes Bremsen',
    'smoothness': 'Unruhige Fahrweise',
    'overRev': 'Hohe Drehzahlen',
    'overheat': 'Überhitzung',
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
        _pointCount = results[2].length;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String _fmtDate(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}'
        ' ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _duration() {
    final start = widget.trip['startedAt'] as String?;
    final end = widget.trip['endedAt'] as String?;
    if (start == null || end == null) return '—';
    final d = DateTime.parse(end).difference(DateTime.parse(start));
    return d.inMinutes < 60
        ? '${d.inMinutes} min'
        : '${d.inHours} h ${(d.inMinutes % 60)} min';
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final score = _num(t['score']);
    final breakdown = t['scoreBreakdown'] as Map<String, dynamic>?;
    final penalties = (breakdown?['penalties'] as Map<String, dynamic>?) ?? {};
    final activePenalties = penalties.entries.where((e) => (e.value as num) > 0).toList();

    // OBD aggregates
    final rpms = _obd.map((r) => _num(r['rpmX4'])).whereType<double>().toList();
    final speeds = _obd.map((r) => _num(r['speedKmh'])).whereType<double>().toList();
    final coolants = _obd.map((r) => _num(r['coolantTempC'])).whereType<double>().toList();
    final maxRpm = rpms.isNotEmpty ? rpms.reduce((a, b) => a > b ? a : b) / 4 : null;
    final maxSpeed = speeds.isNotEmpty ? speeds.reduce((a, b) => a > b ? a : b) : null;
    final maxCoolant = coolants.isNotEmpty ? coolants.reduce((a, b) => a > b ? a : b) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fahrt-Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'Route auf Karte',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => TripMapScreen(
                tripId: t['id'] as String,
                tripDate: _fmtDate(t['startedAt'] as String),
              ),
            )),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(_fmtDate(t['startedAt'] as String),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                // ---- Key figures ----
                Row(
                  children: [
                    Expanded(
                      child: _stat(
                        'Strecke',
                        t['distanceKm'] != null
                            ? '${double.parse(t['distanceKm'] as String).toStringAsFixed(2)} km'
                            : '—',
                      ),
                    ),
                    Expanded(child: _stat('Dauer', _duration())),
                    Expanded(child: _stat('GPS-Punkte', '$_pointCount')),
                  ],
                ),
                const Divider(height: 28),

                // ---- Score ----
                if (score != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: score >= 80
                              ? Colors.green
                              : (score >= 60 ? Colors.orange : Colors.red),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(score.toStringAsFixed(0),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    height: 1)),
                            const Text('/ 100',
                                style: TextStyle(color: Colors.white70, fontSize: 10)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Fahr-Score',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 6),
                            if (activePenalties.isEmpty)
                              const Text('Keine Auffälligkeiten — saubere Fahrt!',
                                  style: TextStyle(color: Colors.green, fontSize: 13)),
                            ...activePenalties.map((e) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_penaltyLabels[e.key] ?? e.key,
                                          style: const TextStyle(fontSize: 13)),
                                      Text('−${(e.value as num).toStringAsFixed(1)}',
                                          style: const TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13)),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                ] else ...[
                  const Text('Keine Bewertung — zu wenig GPS-Daten für diese Fahrt.',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const Divider(height: 28),
                ],

                // ---- OBD summary ----
                const Text('OBD-Daten',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                if (_obd.isEmpty)
                  const Text('Keine OBD-Daten aufgezeichnet (kein Adapter verbunden).',
                      style: TextStyle(color: Colors.grey, fontSize: 13))
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _chip('Messwerte', '${_obd.length}'),
                      if (maxRpm != null) _chip('Max. Drehzahl', '${maxRpm.toStringAsFixed(0)} U/min'),
                      if (maxSpeed != null) _chip('Max. Tempo (OBD)', '${maxSpeed.toStringAsFixed(0)} km/h'),
                      if (maxCoolant != null)
                        _chip('Max. Kühlmittel', '${maxCoolant.toStringAsFixed(0)} °C',
                            warn: maxCoolant > 105),
                    ],
                  ),
                const SizedBox(height: 20),

                // ---- DTCs ----
                const Text('Fehlercodes',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                if (_dtcs.isEmpty)
                  const Text('Keine Fehlercodes während dieser Fahrt.',
                      style: TextStyle(color: Colors.green, fontSize: 13))
                else
                  ..._dtcs.map((d) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: d['clearedAt'] != null ? Colors.grey.shade100 : Colors.red.shade50,
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
                            const SizedBox(width: 10),
                            if (d['severity'] != null)
                              Text(d['severity'] as String,
                                  style: const TextStyle(fontSize: 11, color: Colors.red)),
                            const Spacer(),
                            Text(
                              d['clearedAt'] != null ? 'behoben' : 'offen',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: d['clearedAt'] != null ? Colors.grey : Colors.red),
                            ),
                          ],
                        ),
                      )),

                if (t['notes'] != null) ...[
                  const Divider(height: 28),
                  const Text('Notizen', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(t['notes'] as String),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _stat(String label, String value) => Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );

  Widget _chip(String label, String value, {bool warn = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: warn ? Colors.red.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(value,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: warn ? Colors.red : null)),
          ],
        ),
      );
}
