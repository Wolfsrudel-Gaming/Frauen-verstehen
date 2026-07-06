import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/data_service.dart';
import '../services/obd_fusion_service.dart';
import '../services/obd2_adapter.dart';
import '../services/trip_detection_service.dart';
import 'ble_scanner_screen.dart';
import 'live_obd_screen.dart';

// Live view of the currently running trip: growing route on the map,
// current speed, distance, duration, plus OBD quick stats when connected.
class LiveTripScreen extends StatefulWidget {
  final String tripId;
  const LiveTripScreen({super.key, required this.tripId});

  @override
  State<LiveTripScreen> createState() => _LiveTripScreenState();
}

class _LiveTripScreenState extends State<LiveTripScreen> {
  final MapController _mapController = MapController();
  final List<LatLng> _route = [];

  LiveTripStats _stats = TripDetectionService.liveStats;
  ObdReading? _obd;
  bool _followPosition = true;
  Timer? _clockTimer;
  Duration _elapsed = Duration.zero;

  StreamSubscription<LiveTripStats>? _liveSub;
  StreamSubscription<ObdReading?>? _obdSub;

  @override
  void initState() {
    super.initState();
    _loadExistingRoute();

    _liveSub = TripDetectionService.liveStream.listen((s) {
      setState(() {
        _stats = s;
        if (s.lat != null && s.lon != null) {
          final p = LatLng(s.lat!, s.lon!);
          _route.add(p);
          if (_followPosition) {
            _mapController.move(p, _mapController.camera.zoom);
          }
        }
      });
    });

    _obdSub = ObdFusionService.readingStream.listen((r) {
      setState(() => _obd = r);
    });
    _obd = ObdFusionService.lastReading;

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final started = _stats.startedAt;
      if (started != null) {
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
                double.parse(p['lat'] as String),
                double.parse(p['lon'] as String),
              )),
        );
        if (_route.isNotEmpty) {
          _mapController.move(_route.last, 16);
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _obdSub?.cancel();
    _clockTimer?.cancel();
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
    final speed = _stats.speedKmh;
    final obdConnected = ObdFusionService.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live-Fahrt'),
        actions: [
          IconButton(
            icon: Icon(_followPosition ? Icons.gps_fixed : Icons.gps_not_fixed),
            tooltip: _followPosition ? 'Karte folgt Position' : 'Karte frei',
            onPressed: () => setState(() => _followPosition = !_followPosition),
          ),
        ],
      ),
      body: Column(
        children: [
          // ---- Big speed + key stats ----
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            color: Colors.black,
            child: Column(
              children: [
                Text(
                  speed != null ? speed.toStringAsFixed(0) : '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
                const Text('km/h', style: TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _miniStat('Distanz', '${_stats.distanceKm.toStringAsFixed(2)} km'),
                    _miniStat('Dauer', _fmtDuration(_elapsed)),
                    _miniStat('GPS-Punkte', '${_stats.points}'),
                  ],
                ),
              ],
            ),
          ),

          // ---- OBD strip ----
          Material(
            color: obdConnected ? Colors.green.shade50 : Colors.grey.shade100,
            child: InkWell(
              onTap: () {
                if (obdConnected) {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => LiveObdScreen(
                      tripId: widget.tripId,
                      protocol: ObdFusionService.elmProtocol ?? 'OBD',
                    ),
                  ));
                } else {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => BleScannerScreen(tripId: widget.tripId),
                  ));
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      obdConnected ? Icons.bluetooth_connected : Icons.bluetooth_searching,
                      size: 18,
                      color: obdConnected ? Colors.green.shade700 : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: obdConnected && _obd != null
                          ? Text(
                              '${_obd!.rpm != null ? '${_obd!.rpm!.toStringAsFixed(0)} U/min' : ''}'
                              '${_obd!.coolantTempC != null ? '  ·  ${_obd!.coolantTempC} °C' : ''}'
                              '${_obd!.fuelLevelPct != null ? '  ·  ⛽ ${_obd!.fuelLevelPct!.toStringAsFixed(0)} %' : ''}',
                              style: TextStyle(fontSize: 13, color: Colors.green.shade800, fontWeight: FontWeight.w600),
                            )
                          : Text(
                              obdConnected ? 'OBD verbunden — warte auf Daten…' : 'OBD verbinden (Carista)',
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),

          // ---- Live map ----
          Expanded(
            child: _route.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Warte auf GPS-Signal…', style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 4),
                        Text(
                          'Im Gebäude kann das dauern — freie Sicht zum Himmel hilft.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _route.last,
                      initialZoom: 16,
                      onPositionChanged: (pos, hasGesture) {
                        if (hasGesture && _followPosition) {
                          setState(() => _followPosition = false);
                        }
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
                            Polyline(points: List.of(_route), color: Colors.blue, strokeWidth: 5),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _route.first,
                            child: const Icon(Icons.play_circle, color: Colors.green, size: 26),
                          ),
                          Marker(
                            point: _route.last,
                            width: 22,
                            height: 22,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}
