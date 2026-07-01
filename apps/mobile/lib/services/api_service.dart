import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Change this to point at your backend instance
const String _baseUrl = 'http://10.0.2.2:3001';

class ApiService {
  static const _tokenKey = 'auth_token';
  static const _orgIdKey = 'active_org_id';

  // -------------------------------------------------------------------------
  // Token management
  // -------------------------------------------------------------------------

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveToken(String token, String orgId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_orgIdKey, orgId);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_orgIdKey);
  }

  // -------------------------------------------------------------------------
  // Auth helpers
  // -------------------------------------------------------------------------

  static Future<Map<String, String>> _authedHeaders() async {
    final token = await getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  static Future<dynamic> _handleResponse(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return Future.value(null);
      return Future.value(jsonDecode(res.body));
    }
    final body = jsonDecode(res.body);
    throw Exception(body['error'] ?? 'Request failed (${res.statusCode})');
  }

  // -------------------------------------------------------------------------
  // Auth endpoints
  // -------------------------------------------------------------------------

  static Future<Map<String, dynamic>> login(
    String username,
    String password, {
    String? totpToken,
  }) async {
    final body = <String, dynamic>{'username': username, 'password': password};
    if (totpToken != null && totpToken.isNotEmpty) body['totpToken'] = totpToken;

    final res = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final data = await _handleResponse(res) as Map<String, dynamic>;
    await saveToken(data['token'] as String, data['orgId'] as String);
    return data;
  }

  static Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/auth/me'),
      headers: await _authedHeaders(),
    );
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  // -------------------------------------------------------------------------
  // Vehicles
  // -------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getVehicles() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/vehicles'),
      headers: await _authedHeaders(),
    );
    final list = await _handleResponse(res) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> createVehicle({
    required String make,
    required String model,
    int? year,
    String? licensePlate,
    String category = 'car',
    String protocolSupport = 'obd2',
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'make': make,
      'model': model,
      'category': category,
      'protocolSupport': protocolSupport,
      if (year != null) 'year': year,
      if (licensePlate != null && licensePlate.isNotEmpty) 'licensePlate': licensePlate,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final res = await http.post(
      Uri.parse('$_baseUrl/vehicles'),
      headers: await _authedHeaders(),
      body: jsonEncode(body),
    );
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  // -------------------------------------------------------------------------
  // Trips
  // -------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getTrips() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/trips'),
      headers: await _authedHeaders(),
    );
    final list = await _handleResponse(res) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> startTrip({
    String? vehicleId,
    int? startOdometer,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'startTrigger': 'manual',
      if (vehicleId != null) 'vehicleId': vehicleId,
      if (startOdometer != null) 'startOdometer': startOdometer,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final res = await http.post(
      Uri.parse('$_baseUrl/trips/start'),
      headers: await _authedHeaders(),
      body: jsonEncode(body),
    );
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> endTrip(
    String tripId, {
    int? endOdometer,
  }) async {
    final body = <String, dynamic>{
      'endTrigger': 'manual',
      if (endOdometer != null) 'endOdometer': endOdometer,
    };
    final res = await http.post(
      Uri.parse('$_baseUrl/trips/$tripId/end'),
      headers: await _authedHeaders(),
      body: jsonEncode(body),
    );
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  static Future<void> discardTrip(String tripId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/trips/$tripId/discard'),
      headers: await _authedHeaders(),
    );
    await _handleResponse(res);
  }
}
