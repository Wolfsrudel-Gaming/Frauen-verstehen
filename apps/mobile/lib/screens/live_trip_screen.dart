import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/data_service.dart';
import '../services/obd_fusion_service.dart';
import '../services/obd2_adapter.dart';
import '../services/trip_detection_service.dart';
import '../theme/app_theme.dart';
import '../widgets/charts.dart';
import 'ble_scanner_screen.dart';

/// Live cockpit for the running trip: gauges, live charts, and the route
/// growing on a map. Dark by design — it sits in a car mount while driving.
class LiveTripScreen extends StatefulWidget {
  final String tripId;
  const LiveTripScreen({super.key, required this.tripId});

  @override
  State<LiveTripScreen> createState() => _LiveTripScreenState();
}

class _LiveTripScreenState extends State<LiveTripScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final List<LatLng> _route = [];

  late final TabController _tabs;
  LiveTripStats _stats = TripDetectionService.liveStats;
  ObdReading? _obd;
  bool _follow = true;
  Duration _elapsed = Duration.zero;
  Timer? _clock;

  StreamSubscription<LiveTripStats>? _liveSub;
  StreamSubscription<ObdReading?>? _obdSub;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _obd = ObdFusionService.lastReading;
    _loadExistingRoute();

    _liveSub = TripDetectionService.liveStream.listen((s) {
      if (!mounted) return;
      setState(() {
        _stats = s;
        if (s.lat != null && s.lon != null) {
          final p = LatLng(s.lat!, s.lon!);
          _route.add(p);
          if (_follow) _mapController.move(p, _mapController.camera.zoom);
        }
      });
    });

    _obdSub = ObdFusionService.readingStream.listen((r) {
      if (mounted) setState(() => _obd = r);
    });

    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      final started = _stats.startedAt;
      if (started != null && mounted) {
        setState(() => _elapsed = DateTime.now().difference(started));
      }
    });
  }

  Future<void> _loadExistingRoute() async {
    try {
      final pts = await DataService.getTripPoints(widget.tripId);
      if (!mounted) return;
      setState(() {
        _route.insertAll(
          0,
          pts.map((p) => LatLng(
                double.parse(p['lat'].toString()),
                double.parse(p['lon'].toString()),
              )),
        );
        if (_route.isNotEmpty) _mapController.move(_route.last, 16);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _obdSub?.cancel();
    _clock?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cockpitBg,
      appBar: AppBar(
        backgroundColor: AppTheme.cockpitBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Live-Cockpit', style: TextStyle(color: Colors.white)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.brand,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.speed), text: 'Cockpit'),
            Tab(icon: Icon(Icons.map_outlined), text: 'Karte'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildCockpit(), _buildMap()],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Cockpit tab
  // -------------------------------------------------------------------------
  Widget _buildCockpit() {
    final obdOn = ObdFusionService.isConnected;
    final speed = _stats.speedKmh;
    final rpm = _obd?.rpm;
    final speedHistory = TripDetectionService.speedHistory;
    final obdHistory = ObdFusionService.history;
    final rpmHistory =
        obdHistory.map((r) => r.rpm).whereType<double>().toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        // ---- Gauges ----
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            CockpitGauge(
              value: speed,
              max: 180,
              label: 'TEMPO',
              unit: 'km/h',
              color: AppTheme.brand,
              size: 152,
            ),
            CockpitGauge(
              value: rpm,
              max: 7000,
              label: 'DREHZAHL',
              unit: 'U/min',
              color: rpm != null && rpm > 4000 ? AppTheme.bad : AppTheme.good,
              size: 152,
            ),
          ],
        ),
        const SizedBox(height: 22),

        // ---- Trip counters ----
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.cockpitCard,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _counter('Strecke', '${_stats.distanceKm.toStringAsFixed(2)} km'),
              _counter('Dauer', _fmtDuration(_elapsed)),
              _counter('Ø Tempo', _avgSpeedText()),
              _counter('Max', '${TripDetectionService.maxSpeedKmh.toStringAsFixed(0)} km/h'),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // ---- Speed curve ----
        _chartCard(
          'Geschwindigkeitsverlauf',
          SeriesChart(
            xs: List.generate(speedHistory.length, (i) => i.toDouble()),
            ys: speedHistory,
            color: AppTheme.brand,
            unit: 'km/h',
            dark: true,
            height: 140,
          ),
        ),

        // ---- OBD section ----
        const SizedBox(height: 18),
        if (!obdOn)
          _obdConnectCard()
        else ...[
          _chartCard(
            'Drehzahlverlauf',
            SeriesChart(
              xs: List.generate(rpmHistory.length, (i) => i.toDouble()),
              ys: rpmHistory,
              color: AppTheme.good,
              unit: 'U/min',
              dark: true,
              height: 140,
              maxYHint: 5000,
            ),
          ),
          const SizedBox(height: 18),
          _obdVitals(),
        ],
      ],
    );
  }

  String _avgSpeedText() {
    final secs = _elapsed.inSeconds;
    if (secs < 5 || _stats.distanceKm <= 0) return '—';
    return '${(_stats.distanceKm / (secs / 3600)).toStringAsFixed(0)} km/h';
  }

  Widget _counter(String label, String value) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      );

  Widget _chartCard(String title, Widget chart) => Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        decoration: BoxDecoration(
          color: AppTheme.cockpitCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            chart,
          ],
        ),
      );

  Widget _obdVitals() {
    final r = _obd;
    final coolant = r?.coolantTempC;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cockpitCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bluetooth_connected, size: 16, color: AppTheme.good),
              const SizedBox(width: 6),
              const Text('Motordaten',
                  style: TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(ObdFusionService.elmProtocol ?? '',
                  style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 14),
          MeterBar(
            label: 'Gaspedal',
            percent: r?.throttlePosPct,
            color: AppTheme.brand,
            dark: true,
          ),
          const SizedBox(height: 12),
          MeterBar(
            label: 'Tankfüllung',
            percent: r?.fuelLevelPct,
            color: (r?.fuelLevelPct ?? 100) < 15 ? AppTheme.bad : AppTheme.good,
            dark: true,
          ),
          const SizedBox(height: 12),
          MeterBar(
            label: 'Kühlmitteltemperatur',
            percent: coolant != null ? (coolant / 120 * 100).clamp(0, 100).toDouble() : null,
            valueText: coolant != null ? '$coolant °C' : '—',
            color: coolant != null && coolant > 105 ? AppTheme.bad : AppTheme.warn,
            dark: true,
          ),
          if (r?.intakeAirTempC != null || r?.mafGps != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (r?.intakeAirTempC != null)
                  Expanded(child: _miniVital('Ansaugluft', '${r!.intakeAirTempC} °C')),
                if (r?.mafGps != null)
                  Expanded(
                      child: _miniVital('Luftmasse', '${r!.mafGps!.toStringAsFixed(1)} g/s')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniVital(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      );

  Widget _obdConnectCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.cockpitCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            const Icon(Icons.bluetooth_searching, color: Colors.white38, size: 30),
            const SizedBox(height: 10),
            const Text('Kein OBD-Adapter verbunden',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              'Verbinde deinen Carista, um Drehzahl, Temperatur und Tankstand live zu sehen.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(
                    builder: (_) => BleScannerScreen(tripId: widget.tripId),
                  ))
                  .then((_) => mounted ? setState(() {}) : null),
              icon: const Icon(Icons.bluetooth),
              label: const Text('OBD verbinden'),
            ),
          ],
        ),
      );

  // -------------------------------------------------------------------------
  // Map tab
  // -------------------------------------------------------------------------
  Widget _buildMap() {
    if (_route.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.brand),
              SizedBox(height: 16),
              Text('Warte auf GPS-Signal…',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              SizedBox(height: 6),
              Text(
                'Im Gebäude oder in der Tiefgarage kann das dauern — '
                'freie Sicht zum Himmel hilft.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _route.last,
            initialZoom: 16,
            onPositionChanged: (pos, hasGesture) {
              if (hasGesture && _follow) setState(() => _follow = false);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.frauenverstehen.mobile',
            ),
            if (_route.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(points: List.of(_route), color: AppTheme.brand, strokeWidth: 6),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _route.first,
                  child: const Icon(Icons.trip_origin, color: AppTheme.good, size: 22),
                ),
                Marker(
                  point: _route.last,
                  width: 24,
                  height: 24,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.brand,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black45)],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        // Speed overlay
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.cockpitBg.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _stats.speedKmh?.toStringAsFixed(0) ?? '—',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 4),
                const Text('km/h', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(width: 14),
                Text('${_stats.distanceKm.toStringAsFixed(2)} km',
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: FloatingActionButton.small(
            heroTag: 'follow',
            backgroundColor: _follow ? AppTheme.brand : Colors.white,
            foregroundColor: _follow ? Colors.white : AppTheme.ink,
            onPressed: () {
              setState(() => _follow = !_follow);
              if (_follow && _route.isNotEmpty) _mapController.move(_route.last, 16);
            },
            child: Icon(_follow ? Icons.gps_fixed : Icons.gps_not_fixed),
          ),
        ),
      ],
    );
  }
}
