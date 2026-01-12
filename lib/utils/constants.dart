import 'dart:ui';

class ApiConstants {
  static const String baseUrl = 'https://pos.inspiredgrow.in/vps/api';
  static const String addressesEndpoint = '$baseUrl/addresses';

  // HTTP Status Codes
  static const int statusOk = 200;
  static const int statusCreated = 201;
  static const int statusNotFound = 404;

  // SharedPreferences Keys
  static const String jwtTokenKey = 'jwt_token';
}

class AppColors {
  static const primaryGreen = Color(0xFF00A651);
  static const lightGreen = Color(0xFFE8F5E8);
  static const errorRed = Color(0xFFE74C3C);
  static const greyText = Color(0xFF757575);
  static const lightGrey = Color(0xFFF5F5F5);
}

class AppStrings {
  static const String addressTitle = 'Delivery Address';
  static const String addAddress = 'Add Address';
  static const String selectAddress = 'Select Delivery Address';
  static const String deleteConfirmation =
      'Are you sure you want to delete this address?';
  static const String noSavedAddresses = 'No saved addresses';
  static const String addFirstAddress =
      'Add your first delivery address to get started';
  static const String authRequired = 'Authentication required. Please login.';
}
