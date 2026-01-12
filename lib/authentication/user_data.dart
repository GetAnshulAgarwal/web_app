// user_data.dart
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import '../model/Login/user_model.dart';
import '../services/Notification/firebase_notification_service.dart';
// ADD THIS IMPORT
import '../services/warehouse/warehouse_service.dart';

class UserData {
  static const String _userBoxName = 'user_data';
  static const String _userKey = 'current_user';

  // Initialize Hive
  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(UserModelAdapter());
    await Hive.openBox<UserModel>(_userBoxName);
  }

  // Get user box
  Box<UserModel> get _userBox => Hive.box<UserModel>(_userBoxName);

  // NEW: Get delivery info for display (what user sees)
  DeliveryInfo? getDeliveryInfo() {
    return ZoneWarehouseService.getUserDeliveryInfo();
  }

  // NEW: Check if location has delivery service
  bool isLocationServiceable() {
    final user = getCurrentUser();
    return user?.isServiceable ?? false;
  }

  // NEW: Get delivery time for display
  String getDeliveryTime() {
    final user = getCurrentUser();
    if (user?.estimatedDeliveryTime != null) {
      return "${user!.estimatedDeliveryTime} mins";
    }
    return "N/A";
  }

  // NEW: Get delivery status for display
  String getDeliveryStatus() {
    final user = getCurrentUser();
    return user?.deliveryStatus ?? "Checking availability...";
  }

  // NEW: Get user address for display
  String getUserAddress() {
    final user = getCurrentUser();
    return user?.userAddress ?? "Location not set";
  }

  // NEW: Check if user has delivery service available
  bool hasDeliveryService() {
    final user = getCurrentUser();
    return user?.isServiceable == true;
  }

  // NEW: Get delivery status for UI display
  String getDeliveryStatusForDisplay() {
    final user = getCurrentUser();
    if (user?.isServiceable == true) {
      final deliveryTime = user?.estimatedDeliveryTime;
      if (deliveryTime != null && deliveryTime <= 20) {
        return "⚡ Express delivery available";
      } else if (deliveryTime != null) {
        return "🚀 Fast delivery available";
      } else {
        return "✅ Delivery available";
      }
    }
    return "📍 Checking delivery availability...";
  }

  // NEW: Get delivery time for display
  String getDeliveryTimeForDisplay() {
    final user = getCurrentUser();
    final deliveryTime = user?.estimatedDeliveryTime;
    if (deliveryTime != null) {
      return "$deliveryTime mins";
    }
    return "N/A";
  }

  // NEW: Check if warehouse info needs refresh (called periodically)
  Future<bool> shouldRefreshWarehouse() async {
    final user = getCurrentUser();
    if (user?.selectedWarehouseId == null) return true;

    // Refresh if warehouse was assigned more than 24 hours ago
    final loginTime = user?.createdAt;
    if (loginTime != null) {
      final hoursSinceLogin = DateTime.now().difference(loginTime).inHours;
      return hoursSinceLogin > 24;
    }

    return false;
  }

  // NEW: Clear warehouse info (when user logs out)
  Future<void> clearWarehouseInfo() async {
    final currentUser = getCurrentUser();
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
        // Clear warehouse info
        selectedWarehouseId: null,
        estimatedDeliveryTime: null,
        isServiceable: null,
        userLatitude: null,
        userLongitude: null,
        userAddress: null,
      );
      await saveUser(updatedUser);
    }
  }

  // Save user data
  Future<void> saveUser(UserModel user) async {
    await _userBox.put(_userKey, user);
  }

  // Get current user
  UserModel? getCurrentUser() {
    return _userBox.get(_userKey);
  }

  // Check if user is logged in
  bool isLoggedIn() {
    final user = getCurrentUser();
    return user?.isLoggedIn ?? false;
  }

  // Get user token
  String? getToken() {
    final user = getCurrentUser();
    return user?.token;
  }

  // Get user ID
  String? getUserId() {
    final user = getCurrentUser();
    return user?.id;
  }

  // Get login time
  DateTime? getLoginTime() {
    final user = getCurrentUser();
    return user?.createdAt;
  }

  // Update user profile
  Future<void> updateUser({
    String? name,
    String? email,
    String? city,
    String? state,
    String? country,
  }) async {
    final currentUser = getCurrentUser();
    if (currentUser != null) {
      final updatedUser = UserModel(
        phone: currentUser.phone,
        name: name ?? currentUser.name,
        email: email ?? currentUser.email,
        city: city ?? currentUser.city,
        state: state ?? currentUser.state,
        country: country ?? currentUser.country,
        token: currentUser.token,
        isLoggedIn: currentUser.isLoggedIn,
        createdAt: currentUser.createdAt,
        id: currentUser.id,
        // Preserve warehouse info
        selectedWarehouseId: currentUser.selectedWarehouseId,
        estimatedDeliveryTime: currentUser.estimatedDeliveryTime,
        isServiceable: currentUser.isServiceable,
        userLatitude: currentUser.userLatitude,
        userLongitude: currentUser.userLongitude,
        userAddress: currentUser.userAddress,
      );
      await saveUser(updatedUser);
    }
  }

  // Register FCM token after login
  Future<void> registerFCMTokenAfterLogin() async {
    if (isLoggedIn()) {
      try {
        final firebaseService = FirebaseNotificationService();
        await firebaseService.registerDeviceTokenAfterLogin();
      } catch (e) {
        print('Error registering FCM token after login: $e');
      }
    }
  }

  // Update user token (useful for token refresh)
  Future<void> updateToken(String newToken) async {
    final currentUser = getCurrentUser();
    if (currentUser != null) {
      final updatedUser = UserModel(
        phone: currentUser.phone,
        name: currentUser.name,
        email: currentUser.email,
        city: currentUser.city,
        state: currentUser.state,
        country: currentUser.country,
        token: newToken, // Update token
        isLoggedIn: true, // Ensure user remains logged in
        createdAt: currentUser.createdAt,
        id: currentUser.id,
        // Preserve warehouse info
        selectedWarehouseId: currentUser.selectedWarehouseId,
        estimatedDeliveryTime: currentUser.estimatedDeliveryTime,
        isServiceable: currentUser.isServiceable,
        userLatitude: currentUser.userLatitude,
        userLongitude: currentUser.userLongitude,
        userAddress: currentUser.userAddress,
      );
      await saveUser(updatedUser);
    }
  }

  // Set user as logged out (without clearing data)
  Future<void> setLoggedOut() async {
    final currentUser = getCurrentUser();
    if (currentUser != null) {
      final updatedUser = UserModel(
        phone: currentUser.phone,
        name: currentUser.name,
        email: currentUser.email,
        city: currentUser.city,
        state: currentUser.state,
        country: currentUser.country,
        token: null, // Clear token
        isLoggedIn: false, // Set as logged out
        createdAt: currentUser.createdAt,
        id: currentUser.id,
        // Clear warehouse info on logout
        selectedWarehouseId: null,
        estimatedDeliveryTime: null,
        isServiceable: null,
        userLatitude: null,
        userLongitude: null,
        userAddress: null,
      );
      await saveUser(updatedUser);
    }
  }

  // Clear user data (complete logout)
  Future<void> clearUserData() async {
    await _userBox.delete(_userKey);
  }

  // Check if user data exists
  bool hasUserData() {
    return _userBox.containsKey(_userKey);
  }

  // Get user data for debugging
  Map<String, dynamic> getUserDebugData() {
    final user = getCurrentUser();
    if (user == null) {
      return {'error': 'No user data found'};
    }

    return {
      'hasData': true,
      'isLoggedIn': user.isLoggedIn,
      'hasToken': user.token != null,
      'tokenLength': user.token?.length ?? 0,
      'phone': user.phone,
      'name': user.name,
      'email': user.email,
      'city': user.city,
      'state': user.state,
      'country': user.country,
      'createdAt': user.createdAt?.toIso8601String(),
      'id': user.id,
      // NEW: Warehouse debug info
      'hasWarehouseInfo': user.selectedWarehouseId != null,
      'isServiceable': user.isServiceable,
      'deliveryTime': user.estimatedDeliveryTime,
      'userAddress': user.userAddress,
    };
  }

  // Get user data methods for backward compatibility
  String getName() => getCurrentUser()?.name ?? 'Guest User';
  String getPhone() => getCurrentUser()?.phone ?? '';
  String getEmail() => getCurrentUser()?.email ?? '';
  String getCity() => getCurrentUser()?.city ?? '';
  String getState() => getCurrentUser()?.state ?? '';
  String getCountry() => getCurrentUser()?.country ?? '';
}