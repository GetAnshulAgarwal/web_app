// services/warehouse/testing_warehouse_service.dart - UPDATED WITH HISAR COORDINATES
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Location/location_service.dart';
import '../../authentication/user_data.dart';
import '../../model/Login/user_model.dart';

class TestingWarehouseService {
  // 🧪 TEMPORARY: Hardcode the TESTING warehouse details with Hisar coordinates
  static const Map<String, dynamic> TEMP_TESTING_WAREHOUSE = {
    '_id': '689eb3be9a1a5e2058a6118f', // Use the actual ID from your warehouse list
    'warehouse': 'TESTING',
    'name': 'TESTING',
    'mobile': '9874543210',
    'coords': {
      'type': 'Point',
      'coordinates': [75.7217, 29.1492] // Hisar, Haryana coordinates
    },
    'isActive': true,
  };

  /// 🧪 TEMPORARY: Direct warehouse assignment without API call
  static Future<TestingServiceabilityResult> autoAssignTestingWarehouse() async {
    try {
      print('🧪 [TESTING] TEMP: Assigning hardcoded testing warehouse...');

      // Default to Hisar coordinates
      double latitude = 29.1492; // Hisar latitude
      double longitude = 75.7217; // Hisar longitude
      String address = "Hisar, Haryana, India";

      try {
        final position = await LocationService.getCurrentPosition();
        final userAddress = await LocationService.getFormattedAddress(
            position.latitude,
            position.longitude
        );

        latitude = position.latitude;
        longitude = position.longitude;
        address = userAddress;

        print('🧪 [TESTING] ✅ Got user location: $address');
        print('🧪 [TESTING] Coordinates: ($latitude, $longitude)');
      } catch (locationError) {
        print('🧪 [TESTING] ⚠️ Using default Hisar location: $locationError');
        print('🧪 [TESTING] Default coordinates: ($latitude, $longitude)');
      }

      // Use hardcoded warehouse
      final warehouse = TEMP_TESTING_WAREHOUSE;

      // Calculate distance from user location to warehouse (Hisar)
      final distance = LocationService.calculateDistance(
        latitude, longitude,
        warehouse['coords']['coordinates'][1], // Warehouse latitude
        warehouse['coords']['coordinates'][0], // Warehouse longitude
      );

      final deliveryTime = _calculateDeliveryTime(distance);

      print('🧪 [TESTING] TEMP: Using hardcoded warehouse: ${warehouse['warehouse']} (ID: ${warehouse['_id']})');
      print('🧪 [TESTING] Distance to warehouse: ${distance.round()}m');
      print('🧪 [TESTING] Estimated delivery: $deliveryTime minutes');

      // Save warehouse info to user data
      await _saveTestingWarehouseToUser(
        warehouseId: warehouse['_id'],
        warehouseName: warehouse['warehouse'],
        deliveryTime: deliveryTime,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );

      return TestingServiceabilityResult(
        isServiceable: true,
        message: "TEMP: Testing warehouse assigned (Hisar): ${warehouse['warehouse']}",
        deliveryTime: deliveryTime,
        userAddress: address,
      );

    } catch (e) {
      print('🧪 [TESTING] TEMP: Error: $e');
      return TestingServiceabilityResult(
        isServiceable: false,
        message: "TEMP: Failed to assign testing warehouse: $e",
        deliveryTime: null,
        userAddress: null,
      );
    }
  }

  /// 🧪 Calculate delivery time based on distance
  static int _calculateDeliveryTime(double distanceInMeters) {
    final distanceInKm = distanceInMeters / 1000;

    // Delivery time calculation for Hisar area
    if (distanceInKm <= 2) return 15;   // 15 mins for very close (within city)
    if (distanceInKm <= 5) return 25;   // 25 mins for nearby areas
    if (distanceInKm <= 10) return 35;  // 35 mins for city outskirts
    if (distanceInKm <= 20) return 45;  // 45 mins for nearby towns
    if (distanceInKm <= 50) return 60;  // 60 mins for district areas
    return 90; // 90 mins for far locations
  }

  /// 🧪 Save testing warehouse to user data
  static Future<void> _saveTestingWarehouseToUser({
    required String warehouseId,
    required String warehouseName,
    required int deliveryTime,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    final userData = UserData();
    final currentUser = userData.getCurrentUser();

    if (currentUser != null) {
      final updatedUser = UserModel(
        phone: currentUser.phone,
        name: currentUser.name,
        email: currentUser.email,
        city: currentUser.city,
        state: currentUser.state,
        country: currentUser.country,
        token: currentUser.token,
        isLoggedIn: currentUser.isLoggedIn,
        createdAt: currentUser.createdAt,
        id: currentUser.id,
        // TESTING warehouse info with Hisar location
        selectedWarehouseId: warehouseId,
        estimatedDeliveryTime: deliveryTime,
        isServiceable: true,
        userLatitude: latitude,
        userLongitude: longitude,
        userAddress: address,
      );

      await userData.saveUser(updatedUser);
      print('🧪 [TESTING] ✅ TEMP: Hisar warehouse saved: $warehouseName ($warehouseId)');

      // Verify it was saved
      final verifyUser = userData.getCurrentUser();
      print('🧪 [TESTING] 📋 VERIFICATION: Warehouse ID: ${verifyUser?.selectedWarehouseId}');
      print('🧪 [TESTING] 📍 VERIFICATION: User location: ${verifyUser?.userAddress}');
      print('🧪 [TESTING] 🚚 VERIFICATION: Delivery time: ${verifyUser?.estimatedDeliveryTime} mins');
    } else {
      print('🧪 [TESTING] ❌ Current user is null, cannot save warehouse');
    }
  }

  /// 🧪 Validate testing serviceability
  static Future<bool> validateTestingServiceability() async {
    print('🧪 [TESTING] Validating serviceability for Hisar area...');

    final userData = UserData();
    final user = userData.getCurrentUser();

    print('🧪 [TESTING] User warehouse ID: ${user?.selectedWarehouseId}');
    print('🧪 [TESTING] User location: ${user?.userAddress}');

    if (user?.selectedWarehouseId == null) {
      print('🧪 [TESTING] ❌ No warehouse assigned');
      return false;
    }

    print('🧪 [TESTING] ✅ Hisar serviceability validation passed');
    return true;
  }

  /// 🧪 Get current warehouse info for debugging
  static void printCurrentWarehouseInfo() {
    final userData = UserData();
    final user = userData.getCurrentUser();

    print('🧪 [TESTING] ==========================================');
    print('🧪 [TESTING] HISAR WAREHOUSE INFO:');
    print('🧪 [TESTING] ==========================================');
    print('🧪 [TESTING] 📦 Warehouse ID: ${user?.selectedWarehouseId ?? "❌ NOT ASSIGNED"}');
    print('🧪 [TESTING] 🚚 Delivery Time: ${user?.estimatedDeliveryTime ?? "N/A"} mins');
    print('🧪 [TESTING] ✅ Is Serviceable: ${user?.isServiceable ?? false}');
    print('🧪 [TESTING] 📍 User Address: ${user?.userAddress ?? "Not set"}');
    print('🧪 [TESTING] 🌍 Coordinates: ${user?.userLatitude}, ${user?.userLongitude}');
    print('🧪 [TESTING] ==========================================');
  }

  /// 🧪 Force assign warehouse for immediate testing
  static Future<void> forceAssignHisarWarehouse() async {
    print('🧪 [TESTING] 🚀 FORCE ASSIGNING HISAR WAREHOUSE...');

    try {
      await _saveTestingWarehouseToUser(
        warehouseId: '689eb3be9a1a5e2058a6118f',
        warehouseName: 'TESTING',
        deliveryTime: 25, // 25 mins for Hisar
        latitude: 29.1492, // Hisar coordinates
        longitude: 75.7217,
        address: "Hisar, Haryana, India",
      );

      print('🧪 [TESTING] ✅ HISAR WAREHOUSE FORCE ASSIGNED SUCCESSFULLY!');
      printCurrentWarehouseInfo();
    } catch (e) {
      print('🧪 [TESTING] ❌ Force assign failed: $e');
    }
  }
}

/// 🧪 Testing result model
class TestingServiceabilityResult {
  final bool isServiceable;
  final String message;
  final int? deliveryTime;
  final String? userAddress;

  TestingServiceabilityResult({
    required this.isServiceable,
    required this.message,
    this.deliveryTime,
    this.userAddress,
  });
}