import 'package:shared_preferences/shared_preferences.dart';

// Offline mode: the app runs fully standalone — no login, all data stored
// in the local SQLite database. Meant for testing without a reachable
// backend; a later sync feature can upload local data once online.
class AppMode {
  static const _offlineKey = 'offline_mode';

  static bool _offline = false;
  static bool get isOffline => _offline;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _offline = prefs.getBool(_offlineKey) ?? false;
  }

  static Future<void> setOffline(bool value) async {
    _offline = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_offlineKey, value);
  }
}
