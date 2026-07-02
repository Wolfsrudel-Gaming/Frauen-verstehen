import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/data_service.dart';

class TripMapScreen extends StatefulWidget {
  final String tripId;
  final String? tripDate;

  const TripMapScreen({super.key, required this.tripId, this.tripDate});

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  List<Map<String, dynamic>> _points = [];
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
      final pts = await DataService.getTripPoints(widget.tripId);
      setState(() { _points = pts; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final latlngs = _points
        .map((p) => LatLng(
              double.parse(p['lat'] as String),
              double.parse(p['lon'] as String),
            ))
        .toList();

    final realPoints = _points.where((p) => !(p['isEstimated'] as bool? ?? false)).toList();
    final estPoints = _points.where((p) => p['isEstimated'] as bool? ?? false).toList();

    final realLatLngs = realPoints
        .map((p) => LatLng(double.parse(p['lat'] as String), double.parse(p['lon'] as String)))
        .toList();
    final estLatLngs = estPoints
        .map((p) => LatLng(double.parse(p['lat'] as String), double.parse(p['lon'] as String)))
        .toList();

    double? maxSpeed;
    if (_points.any((p) => p['speedKmh'] != null)) {
      maxSpeed = _points
          .where((p) => p['speedKmh'] != null)
          .map((p) => double.parse(p['speedKmh'] as String))
          .reduce((a, b) => a > b ? a : b);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tripDate != null ? 'Trip: ${widget.tripDate}' : 'Trip Map'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : latlngs.isEmpty
                  ? const Center(child: Text('No GPS points recorded for this trip.'))
                  : Column(
                      children: [
                        // Stats bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _stat('Points', '${_points.length}'),
                              if (maxSpeed != null) _stat('Max Speed', '${maxSpeed.toStringAsFixed(0)} km/h'),
                              _stat('Estimated', '${estPoints.length}'),
                            ],
                          ),
                        ),
                        // Map
                        Expanded(
                          child: FlutterMap(
                            options: MapOptions(
                              initialCameraFit: latlngs.length > 1
                                  ? CameraFit.coordinates(
                                      coordinates: latlngs,
                                      padding: const EdgeInsets.all(32),
                                    )
                                  : null,
                              initialCenter: latlngs.isNotEmpty ? latlngs.first : const LatLng(0, 0),
                              initialZoom: 14,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.mobile',
                              ),
                              if (realLatLngs.length > 1)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: realLatLngs,
                                      color: Colors.blue,
                                      strokeWidth: 4,
                                    ),
                                  ],
                                ),
                              if (estLatLngs.length > 1)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: estLatLngs,
                                      color: Colors.orange,
                                      strokeWidth: 3,
                                      pattern: StrokePattern.dashed(segments: [10, 6]),
                                    ),
                                  ],
                                ),
                              if (latlngs.isNotEmpty)
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: latlngs.first,
                                      child: const Icon(Icons.play_circle, color: Colors.green, size: 28),
                                    ),
                                    if (latlngs.length > 1)
                                      Marker(
                                        point: latlngs.last,
                                        child: const Icon(Icons.stop_circle, color: Colors.red, size: 28),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        // Legend
                        if (estPoints.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(width: 24, height: 3, color: Colors.blue),
                                const SizedBox(width: 6),
                                const Text('GPS', style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 16),
                                Container(
                                  width: 24,
                                  height: 3,
                                  decoration: const BoxDecoration(
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text('Estimated', style: TextStyle(fontSize: 12, color: Colors.orange)),
                              ],
                            ),
                          ),
                      ],
                    ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
