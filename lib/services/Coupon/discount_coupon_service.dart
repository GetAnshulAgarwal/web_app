// lib/services/Coupon/discount_coupon_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../authentication/user_data.dart';
import '../../model/cart/cart_item_model.dart';

class DiscountCouponService {
  static const String _baseUrl = 'https://pos.inspiredgrow.in/vps/api';
  static const String _couponEndpoint = '/discount-coupons';

  static const String _verifyEndpoint = '/discount-coupons/apply';

  static Future<Map<String, String>> _getHeaders() async {
    final userData = UserData();
    final token = userData.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// 1. GET: Fetch all available discount coupons
  static Future<Map<String, dynamic>> getCoupons() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$_baseUrl$_couponEndpoint');
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        List<dynamic> couponsList = [];

        if (decoded is List) {
          couponsList = decoded;
        } else if (decoded is Map<String, dynamic>) {
          if (decoded['data'] is List) couponsList = decoded['data'];
        }

        return {
          'success': true,
          'data': couponsList,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to load coupons (Status: ${response.statusCode})'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// 2. POST: Server-side validation using new Body structure
  static Future<Map<String, dynamic>> applyCoupon({
    required String occasionName,
    required double orderAmount,
    required List<CartItem> cartItems,
  }) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$_baseUrl$_verifyEndpoint');

      // 1. Prepare Lists (Remove duplicates)
      final itemIds = cartItems.map((e) => e.itemId).where((s) => s.isNotEmpty).toSet().toList();
      final categoryIds = cartItems.map((e) => e.categoryId).where((s) => s.isNotEmpty).toSet().toList();
      final subCategoryIds = cartItems.map((e) => e.subCategoryId).where((s) => s.isNotEmpty).toSet().toList();
      final subSubCategoryIds = cartItems.map((e) => e.subSubCategoryId).where((s) => s.isNotEmpty).toSet().toList();

      // 2. Construct Body
      final Map<String, dynamic> body = {
        "occasionName": occasionName,
        "spendAmount": orderAmount,
        "itemIds": itemIds,
        "categoryIds": categoryIds,
        "subCategoryIds": subCategoryIds,
        "subSubCategoryIds": subSubCategoryIds,
      };

      print("Applying Coupon Body: ${jsonEncode(body)}");

      final response = await http.post(
          uri,
          headers: headers,
          body: jsonEncode(body)
      );

      final dynamic decoded = json.decode(response.body);
      print("Coupon Response: $decoded");

      // 3. Handle Responses

      // Case A: Success
      if (response.statusCode == 200 || (decoded['message'] == "Coupon applied")) {
        return {
          'success': true,
          'discount': (decoded['discount'] is num) ? (decoded['discount'] as num).toDouble() : 0.0,
          'type': decoded['type'] ?? 'Fixed',
          'message': decoded['message'] ?? 'Coupon applied successfully'
        };
      }

      // Case B: Known Error Messages from Server
      // Includes:
      // - "Coupon is not valid for this product"
      // - "Coupon not valid for selected sub-category"
      // - "New user coupon not allowed for this phone"
      // - "Coupon usage limit reached"
      String errorMsg = decoded['message'] ?? 'Invalid Coupon';

      return {
        'success': false,
        'error': errorMsg // Pass the server message directly to UI
      };

    } catch (e) {
      return {'success': false, 'error': 'Error verifying coupon: $e'};
    }
  }
}