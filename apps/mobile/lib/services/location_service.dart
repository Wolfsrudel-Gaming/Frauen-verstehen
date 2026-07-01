import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static StreamSubscription<Position>? _sub;
  static final StreamController<Position> _controller =
      StreamController<Position>.broadcast();

  static Stream<Position> get positionStream => _controller.stream;

  static Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  static Future<void> startTracking() async {
    if (_sub != null) return;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // emit every 5+ metres moved
    );

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _controller.add,
      onError: _controller.addError,
    );
  }

  static Future<void> stopTracking() async {
    await _sub?.cancel();
    _sub = null;
  }

  static bool get isTracking => _sub != null;
}
