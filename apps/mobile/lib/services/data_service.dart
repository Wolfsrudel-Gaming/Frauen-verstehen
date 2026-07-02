import 'api_service.dart';
import 'app_mode.dart';
import 'local_store.dart';

// Routes every data operation either to the backend (online) or to the
// local SQLite store (offline mode). Screens and services call this facade
// instead of ApiService so offline mode works everywhere.
class DataService {
  // ---------------------------------------------------------------------
  // Vehicles
  // ---------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> getVehicles() =>
      AppMode.isOffline ? LocalStore.getVehicles() : ApiService.getVehicles();

  static Future<Map<String, dynamic>> createVehicle({
    required String make,
    required String model,
    int? year,
    String? licensePlate,
    String category = 'car',
    String protocolSupport = 'obd2',
    String? notes,
  }) =>
      AppMode.isOffline
          ? LocalStore.createVehicle(
              make: make,
              model: model,
              year: year,
              licensePlate: licensePlate,
              category: category,
              protocolSupport: protocolSupport,
              notes: notes,
            )
          : ApiService.createVehicle(
              make: make,
              model: model,
              year: year,
              licensePlate: licensePlate,
              category: category,
              protocolSupport: protocolSupport,
              notes: notes,
            );

  // ---------------------------------------------------------------------
  // Trips
  // ---------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> getTrips() =>
      AppMode.isOffline ? LocalStore.getTrips() : ApiService.getTrips();

  static Future<Map<String, dynamic>> startTrip({
    String? vehicleId,
    int? startOdometer,
    String? notes,
    String startTrigger = 'manual',
  }) =>
      AppMode.isOffline
          ? LocalStore.startTrip(
              vehicleId: vehicleId,
              startOdometer: startOdometer,
              notes: notes,
              startTrigger: startTrigger,
            )
          : ApiService.startTrip(
              vehicleId: vehicleId,
              startOdometer: startOdometer,
              notes: notes,
              startTrigger: startTrigger,
            );

  static Future<Map<String, dynamic>> endTrip(
    String tripId, {
    int? endOdometer,
    String endTrigger = 'manual',
  }) =>
      AppMode.isOffline
          ? LocalStore.endTrip(tripId, endOdometer: endOdometer, endTrigger: endTrigger)
          : ApiService.endTrip(tripId, endOdometer: endOdometer, endTrigger: endTrigger);

  static Future<void> discardTrip(String tripId) =>
      AppMode.isOffline ? LocalStore.discardTrip(tripId) : ApiService.discardTrip(tripId);

  // ---------------------------------------------------------------------
  // GPS points
  // ---------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> getTripPoints(String tripId) =>
      AppMode.isOffline ? LocalStore.getTripPoints(tripId) : ApiService.getTripPoints(tripId);

  // Upload-only: offline mode keeps points in the local pending_points
  // buffer (TripDetectionService skips syncing entirely).
  static Future<Map<String, dynamic>> batchPoints({
    required String tripId,
    required List<Map<String, dynamic>> points,
    String? segmentId,
    String sourceType = 'smartphone_gps',
  }) =>
      ApiService.batchPoints(
        tripId: tripId,
        points: points,
        segmentId: segmentId,
        sourceType: sourceType,
      );

  // ---------------------------------------------------------------------
  // OBD — offline sessions are synthesised locally; readings and DTCs go
  // into the local store.
  // ---------------------------------------------------------------------
  static Future<Map<String, dynamic>> startObdSession({
    required String tripId,
    String? adapterName,
    String? adapterMac,
  }) async {
    if (AppMode.isOffline) return {'id': LocalStore.uuid()};
    return ApiService.startObdSession(tripId: tripId, adapterName: adapterName, adapterMac: adapterMac);
  }

  static Future<void> endObdSession({
    required String tripId,
    required String sessionId,
    String? elmProtocol,
  }) async {
    if (AppMode.isOffline) return;
    return ApiService.endObdSession(tripId: tripId, sessionId: sessionId, elmProtocol: elmProtocol);
  }

  static Future<void> batchObdReadings({
    required String tripId,
    required List<Map<String, dynamic>> readings,
    String? sessionId,
  }) async {
    if (AppMode.isOffline) return LocalStore.saveObdReadings(tripId, readings);
    return ApiService.batchObdReadings(tripId: tripId, readings: readings, sessionId: sessionId);
  }

  static Future<void> reportDtcs({
    required String tripId,
    required List<String> codes,
    String? vehicleId,
  }) async {
    if (AppMode.isOffline) return LocalStore.reportDtcs(tripId, codes, vehicleId: vehicleId);
    return ApiService.reportDtcs(tripId: tripId, codes: codes, vehicleId: vehicleId);
  }
}
