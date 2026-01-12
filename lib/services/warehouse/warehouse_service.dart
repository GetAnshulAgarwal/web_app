import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../authentication/user_data.dart';
import '../../model/Login/user_model.dart';
import '../Location/location_service.dart';
import '../stock_service.dart';

class ZoneWarehouseService {
  static const String baseUrl = 'https://pos.inspiredgrow.in/vps/zone';

  /// Auto-detect and assign warehouse based on delivery zone
  static Future<ServiceabilityResult> autoAssignWarehouse(String userToken) async {
    try {
      print('ðŸ” Checking delivery zone for user...');

      // 1. Get user's current location
      final position = await LocationService.getCurrentPosition();
      final address = await LocationService.getFormattedAddress(
          position.latitude,
          position.longitude
      );

      print('ðŸ“ User location: $address');
      print('ðŸ“ Coordinates: (${position.latitude}, ${position.longitude})');

      // 2. Check if location is inside a delivery zone
      final zoneResult = await _checkLocationInZone(
          position.latitude,
          position.longitude,
          userToken
      );

      if (!zoneResult.inside) {
        print('âŒ Location outside delivery zones');
        return ServiceabilityResult(
          isServiceable: false,
          message: "We're not delivering to your area yet",
          deliveryTime: null,
          userAddress: address,
        );
      }

      // 3. Calculate delivery time based on zone (you can customize this)
      final deliveryTime = _calculateDeliveryTimeForZone(zoneResult);

      print('âœ… Zone assigned: ${zoneResult.zoneName} (${deliveryTime} mins delivery)');
      print('ðŸª Store ID: ${zoneResult.storeId}');
      print('ðŸ’° Delivery fee: â‚¹${zoneResult.deliveryFee}');
      print('ðŸ“¦ Min order: â‚¹${zoneResult.minOrder}');

      // 4. Save zone info to user data
      await _saveZoneToUser(
        zoneId: zoneResult.zoneId ?? '',
        zoneName: zoneResult.zoneName ?? 'Unknown Zone',
        storeId: zoneResult.storeId ?? '',
        deliveryTime: deliveryTime,
        deliveryFee: zoneResult.deliveryFee ?? 0,
        minOrder: zoneResult.minOrder ?? 0,
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
      );

      return ServiceabilityResult(
        isServiceable: true,
        message: "Great! We deliver to your area",
        deliveryTime: deliveryTime,
        userAddress: address,
        zoneName: zoneResult.zoneName,
        deliveryFee: zoneResult.deliveryFee,
        minOrder: zoneResult.minOrder,
      );

    } catch (e) {
      print('âŒ Error checking delivery zone: $e');
      return ServiceabilityResult(
        isServiceable: false,
        message: "Unable to check serviceability",
        deliveryTime: null,
        userAddress: null,
      );
    }
  }

  /// Check if user's current location is still within a delivery zone
  static Future<bool> validateServiceability({int retryCount = 2}) async {
    for (int attempt = 0; attempt <= retryCount; attempt++) {
      try {
        final userData = UserData();
        final user = userData.getCurrentUser();

        if (user == null || !user.hasWarehouseInfo) {
          print('âš ï¸ No zone info found for user');
          return false;
        }

        // Get current position
        final currentPosition = await LocationService.getCurrentPosition();
        final savedLat = user.userLatitude;
        final savedLng = user.userLongitude;

        if (savedLat == null || savedLng == null) {
          print('âš ï¸ No saved location found');
          return false;
        }

        // Check if user moved significantly (more than 1km)
        final distance = LocationService.calculateDistance(
          currentPosition.latitude,
          currentPosition.longitude,
          savedLat,
          savedLng,
        );

        // If user moved more than 1km, re-check zone
        if (distance > 1000) {
          print('ðŸ“ User moved ${distance.round()}m, re-checking zone...');

          final token = user.token;
          if (token != null) {
            final zoneResult = await _checkLocationInZone(
                currentPosition.latitude,
                currentPosition.longitude,
                token
            );

            return zoneResult.inside;
          }
          return false;
        }

        // User hasn't moved much, use saved serviceability status
        return user.isServiceable ?? false;

      } catch (e) {
        print('âš ï¸ Serviceability check attempt ${attempt + 1} failed: $e');
        if (attempt < retryCount) {
          await Future.delayed(Duration(seconds: 2));
          continue;
        }
        return false;
      }
    }
    return false;
  }

  /// Check if item is available in user's assigned store
  static Future<bool> checkItemAvailability(String itemId, int quantity) async {
    try {
      final userData = UserData();
      final user = userData.getCurrentUser();

      if (user?.selectedWarehouseId == null) {
        print('âŒ No store/warehouse assigned to check stock');
        return false;
      }

      final stock = await StockService.getItemStockFromWarehouse(
          itemId,
          user!.selectedWarehouseId!
      );

      final isAvailable = stock != null && stock.currentStock >= quantity;

      print('ðŸ“¦ Stock check: Item $itemId, Required: $quantity, Available: ${stock?.currentStock ?? 0}, Result: $isAvailable');

      return isAvailable;
    } catch (e) {
      print('âŒ Error checking item availability: $e');
      return false;
    }
  }

  /// Get delivery and stock information for an item
  static Future<DeliveryAndStockInfo?> getDeliveryAndStockInfo(String itemId, int quantity) async {
    final deliveryInfo = getUserDeliveryInfo();

    if (deliveryInfo == null || !deliveryInfo.isServiceable) {
      return DeliveryAndStockInfo(
        isServiceable: false,
        isStockAvailable: false,
        deliveryTime: null,
        stockMessage: "Not serviceable in your area",
        userAddress: "Location not available",
      );
    }

    // Get stock status
    final stockStatus = await StockService.getStockStatus(itemId);
    final hasEnoughStock = stockStatus.currentStock >= quantity;

    return DeliveryAndStockInfo(
      isServiceable: true,
      isStockAvailable: hasEnoughStock,
      deliveryTime: deliveryInfo.deliveryTime,
      stockMessage: stockStatus.message,
      userAddress: deliveryInfo.userAddress,
      currentStock: stockStatus.currentStock,
      deliveryFee: deliveryInfo.deliveryFee,
      minOrder: deliveryInfo.minOrder,
    );
  }

  /// Get user's delivery info
  static DeliveryInfo? getUserDeliveryInfo() {
    final userData = UserData();
    final user = userData.getCurrentUser();

    if (user == null || !user.hasWarehouseInfo) {
      return null;
    }

    return DeliveryInfo(
      isServiceable: user.isServiceable ?? false,
      deliveryTime: user.estimatedDeliveryTime,
      deliveryStatus: user.deliveryStatus,
      userAddress: user.userAddress ?? "Your location",
      zoneName: user.selectedWarehouseId, // Using warehouse ID as zone name for now
      deliveryFee: 0, // You may want to store this in UserModel
      minOrder: 0, // You may want to store this in UserModel
    );
  }

  // Private helper methods

  /// Check if location is inside a delivery zone
  static Future<ZoneCheckResult> _checkLocationInZone(
      double lat,
      double lng,
      String token
      ) async {
    final url = Uri.parse('$baseUrl/check-location');

    print('ðŸŒ Checking zone API: $url');
    print('ðŸ“ Coordinates: ($lat, $lng)');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'lat': lat,
          'lng': lng,
        }),
      );

      print('ðŸ“¡ Zone API Response Status: ${response.statusCode}');
      print('ðŸ“¡ Zone API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final inside = data['inside'] ?? false;

          if (inside) {
            print('âœ… Location is inside zone: ${data['zoneName']}');
            return ZoneCheckResult(
              inside: true,
              zoneId: data['zoneId'],
              zoneName: data['zoneName'],
              storeId: data['storeId'],
              deliveryFee: (data['deliveryFee'] ?? 0).toDouble(),
              minOrder: (data['minOrder'] ?? 0).toDouble(),
              source: data['source'],
            );
          } else {
            print('âŒ Location is outside all delivery zones');
            return ZoneCheckResult(inside: false);
          }
        }
      }

      print('âš ï¸ Unexpected API response format');
      return ZoneCheckResult(inside: false);

    } catch (e) {
      print('âŒ Error calling zone API: $e');
      return ZoneCheckResult(inside: false);
    }
  }

  /// Calculate delivery time based on zone (customize as needed)
  static int _calculateDeliveryTimeForZone(ZoneCheckResult zoneResult) {
    // You can customize this based on your business logic
    // For now, returning a standard delivery time
    // You could also add a deliveryTime field to the zone API response
    return 15; // 15 minutes standard delivery
  }

  /// Save zone information to user data
  static Future<void> _saveZoneToUser({
    required String zoneId,
    required String zoneName,
    required String storeId,
    required int deliveryTime,
    required double deliveryFee,
    required double minOrder,
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
        // Zone/Store info (using existing fields)
        selectedWarehouseId: storeId, // Store ID acts as warehouse ID
        estimatedDeliveryTime: deliveryTime,
        isServiceable: true,
        userLatitude: latitude,
        userLongitude: longitude,
        userAddress: address,
      );

      await userData.saveUser(updatedUser);
      print('ðŸ’¾ Zone info saved to user data');
      print('ðŸ“ Zone: $zoneName (ID: $zoneId)');
      print('ðŸª Store: $storeId');
    }
  }
}

// Result models

class ZoneCheckResult {
  final bool inside;
  final String? zoneId;
  final String? zoneName;
  final String? storeId;
  final double? deliveryFee;
  final double? minOrder;
  final String? source;

  ZoneCheckResult({
    required this.inside,
    this.zoneId,
    this.zoneName,
    this.storeId,
    this.deliveryFee,
    this.minOrder,
    this.source,
  });
}

class ServiceabilityResult {
  final bool isServiceable;
  final String message;
  final int? deliveryTime;
  final String? userAddress;
  final String? zoneName;
  final double? deliveryFee;
  final double? minOrder;

  ServiceabilityResult({
    required this.isServiceable,
    required this.message,
    this.deliveryTime,
    this.userAddress,
    this.zoneName,
    this.deliveryFee,
    this.minOrder,
  });
}

class DeliveryInfo {
  final bool isServiceable;
  final int? deliveryTime;
  final String deliveryStatus;
  final String userAddress;
  final String? zoneName;
  final double? deliveryFee;
  final double? minOrder;

  DeliveryInfo({
    required this.isServiceable,
    this.deliveryTime,
    required this.deliveryStatus,
    required this.userAddress,
    this.zoneName,
    this.deliveryFee,
    this.minOrder,
  });

  String get deliveryTimeFormatted {
    if (deliveryTime == null) return "N/A";
    return "$deliveryTime mins";
  }

  String get deliveryFeeFormatted {
    if (deliveryFee == null || deliveryFee == 0) return "Free";
    return "â‚¹${deliveryFee!.toStringAsFixed(0)}";
  }

  String get minOrderFormatted {
    if (minOrder == null || minOrder == 0) return "No minimum";
    return "â‚¹${minOrder!.toStringAsFixed(0)}";
  }
}

class DeliveryAndStockInfo {
  final bool isServiceable;
  final bool isStockAvailable;
  final int? deliveryTime;
  final String stockMessage;
  final String userAddress;
  final int? currentStock;
  final double? deliveryFee;
  final double? minOrder;

  DeliveryAndStockInfo({
    required this.isServiceable,
    required this.isStockAvailable,
    this.deliveryTime,
    required this.stockMessage,
    required this.userAddress,
    this.currentStock,
    this.deliveryFee,
    this.minOrder,
  });

  bool get canOrder => isServiceable && isStockAvailable;

  String get deliveryTimeFormatted {
    if (deliveryTime == null) return "N/A";
    return "$deliveryTime mins";
  }

  String get deliveryFeeFormatted {
    if (deliveryFee == null || deliveryFee == 0) return "Free";
    return "â‚¹${deliveryFee!.toStringAsFixed(0)}";
  }
}