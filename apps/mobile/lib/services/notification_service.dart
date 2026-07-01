import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// DTC push notifications are quiet-hours-exempt — they always get shown
// because they indicate a vehicle fault that the driver needs to know about.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<void> showDtcAlert(List<String> codes) async {
    await init();
    final codeList = codes.join(', ');
    const androidDetails = AndroidNotificationDetails(
      'dtc_alerts',
      'DTC Alerts',
      channelDescription: 'Vehicle trouble code notifications',
      importance: Importance.high,
      priority: Priority.high,
      // DTC alerts bypass Do Not Disturb — critical vehicle health info
      category: AndroidNotificationCategory.alarm,
    );
    const darwinDetails = DarwinNotificationDetails(
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    const details = NotificationDetails(android: androidDetails, iOS: darwinDetails);

    await _plugin.show(
      0,
      'Vehicle Fault Detected',
      'DTC codes: $codeList — connect to a workshop for diagnosis.',
      details,
    );
  }
}
