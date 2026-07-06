import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
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

  static LocationSettings _settings() {
    if (!kIsWeb && Platform.isAndroid) {
      // Foreground service keeps GPS updates flowing with the screen off /
      // app in background — essential for recording real trips.
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Fahrt wird aufgezeichnet',
          notificationText: 'GPS-Tracking aktiv',
          notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (!kIsWeb && Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5);
  }

  static Future<void> startTracking() async {
    if (_sub != null) return;

    _sub = Geolocator.getPositionStream(locationSettings: _settings()).listen(
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
