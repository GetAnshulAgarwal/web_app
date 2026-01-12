// api_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../authentication/user_data.dart';

class ApiService {
  static const String baseUrl = 'https://pos.inspiredgrow.in/vps/customer';

  static Future<Map<String, dynamic>> sendOtp(String phone) async {
    try {
      print('=== FLUTTER SEND OTP DEBUG ===');
      print('Phone: $phone');
      print('API URL: $baseUrl/send-otp');

      final requestBody = jsonEncode({'phone': phone});
      print('Request body: $requestBody');

      final response = await http.post(
        Uri.parse('$baseUrl/send-otp'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: requestBody,
      );

      print('Send OTP Response status: ${response.statusCode}');
      print('Send OTP Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (data.containsKey('otp')) {
        print('🔥 OTP IN RESPONSE: ${data['otp']}');
      }
      if (data.containsKey('data') &&
          data['data'] != null &&
          data['data'].containsKey('otp')) {
        print('🔥 OTP IN DATA: ${data['data']['otp']}');
      }

      print('=== END SEND OTP DEBUG ===');

      return {
        'success': response.statusCode == 200,
        'data': data,
        'statusCode': response.statusCode,
      };
    } catch (e) {
      print('Error in sendOtp: $e');
      return {
        'success': false,
        'error': 'Network error. Please check your connection.',
      };
    }
  }

  static Future<Map<String, dynamic>> verifyOtp(
      String phone,
      String otp, {
        int maxRetries = 2,
      }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('=== FLUTTER VERIFY OTP DEBUG (Attempt $attempt) ===');
        print('Phone: $phone');
        print('OTP: $otp');
        print('API URL: $baseUrl/verify-otp');

        final requestBody = jsonEncode({'phone': phone, 'otp': otp});
        print('Request body: $requestBody');

        final response = await http.post(
          Uri.parse('$baseUrl/verify-otp'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: requestBody,
        );

        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');

        if (response.body.trim().startsWith('<!DOCTYPE') ||
            response.body.trim().startsWith('<html')) {
          print('HTML response detected - server error');
          if (attempt < maxRetries) {
            print('Retrying in 2 seconds...');
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
          return {'success': false, 'error': 'Server error. Please try again.'};
        }

        final data = jsonDecode(response.body);

        if (response.statusCode == 400 &&
            data['message'] != null &&
            data['message'].toString().toLowerCase().contains('invalid') &&
            attempt < maxRetries) {
          print(
            '⏳ OTP might not be ready yet, waiting 3 seconds before retry...',
          );
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }

        print('=== END VERIFY OTP DEBUG ===');

        return {
          'success': true,
          'data': data,
          'statusCode': response.statusCode,
        };
      } catch (e) {
        print('Error in verifyOtp attempt $attempt: $e');
        if (attempt < maxRetries) {
          print('Retrying in 2 seconds...');
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        return {
          'success': false,
          'error': 'Network error. Please check your connection.',
        };
      }
    }

    return {
      'success': false,
      'error': 'Failed to verify OTP after $maxRetries attempts',
    };
  }

  static Future<Map<String, dynamic>> completeProfile({
    required String phone,
    required String name,
    String? email,
    String? city,
    String? state,
    String? country,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/create-account'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'phone': phone,
          'name': name,
          if (email != null) 'email': email,
          if (city != null) 'city': city,
          if (state != null) 'state': state,
          if (country != null) 'country': country,
        }),
      );

      final data = jsonDecode(response.body);

      return {
        'success': response.statusCode == 201,
        'data': data,
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        if (responseData['success'] == true) {
          return {'success': true, 'data': responseData['data']};
        } else {
          return {'success': false, 'error': responseData['message'] ?? 'Failed to get profile'};
        }
      } else {
        return {'success': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
    String? city,
    String? state,
    String? country,
  }) async {
    try {
      final userData = UserData();
      final token = await userData.getToken();

      if (token == null) {
        return {'success': false, 'error': 'No token found'};
      }

      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (email != null) body['email'] = email;
      if (city != null) body['city'] = city;
      if (state != null) body['state'] = state;
      if (country != null) body['country'] = country;

      final response = await http.patch(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      return {
        'success': response.statusCode == 200,
        'data': data,
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ========================================
  // ACCOUNT DELETION API METHODS
  // ========================================

  static Future<Map<String, dynamic>> requestAccountDeletion({
    required String reason,
  }) async {
    try {
      print('=== ACCOUNT DELETION DEBUG ===');

      final userData = UserData();
      final token = await userData.getToken();

      if (token == null) {
        return {
          'success': false,
          'error': 'Authentication required. Please login again.'
        };
      }

      // 1. Define URL
      final url = Uri.parse('$baseUrl/delete-account');

      // 2. Define Body
      final requestBody = jsonEncode({
        "reason": reason
      });

      print('API URL: $url');
      print('Request Method: DELETE'); // Changed to DELETE
      print('Request Body: $requestBody');

      // 3. Execute Request using http.delete
      // Note: The standard http package supports body in delete requests
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: requestBody,
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      // 4. Handle HTML responses (like 404s) gracefully to avoid app crash
      if (response.headers['content-type']?.contains('text/html') == true ||
          response.body.trim().startsWith('<')) {
        print('❌ Server returned HTML (Error page).');
        return {
          'success': false,
          'error': 'Server error (${response.statusCode}). Please contact support.',
        };
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'] ?? 'Account deleted (soft)',
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Failed to delete account',
        };
      }
    } catch (e) {
      print('Error in deleteAccount: $e');
      return {
        'success': false,
        'error': 'Network error. Please check your connection.',
      };
    }
  }

  static Future<Map<String, dynamic>> checkDeletionStatus() async {
    try {
      print('=== CHECK DELETION STATUS DEBUG ===');

      final userData = UserData();
      final token = await userData.getToken();

      if (token == null) {
        print('Error: No token found');
        return {
          'success': false,
          'has_pending_request': false,
          'error': 'Authentication required',
        };
      }

      print('API URL: $baseUrl/account/deletion-status');

      final response = await http.get(
        Uri.parse('$baseUrl/account/deletion-status'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Status check successful');
        return {
          'success': true,
          'has_pending_request': data['has_pending_request'] ?? false,
          'request_date': data['request_date'],
          'deletion_date': data['deletion_date'],
          'status': data['status'], // pending, approved, rejected
          'data': data,
        };
      } else if (response.statusCode == 404) {
        print('ℹ️ No deletion request found');
        return {
          'success': true,
          'has_pending_request': false,
        };
      } else {
        print('❌ Status check failed');
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'has_pending_request': false,
          'error': data['message'] ?? 'Failed to check deletion status',
        };
      }
    } catch (e) {
      print('Error in checkDeletionStatus: $e');
      return {
        'success': true,
        'has_pending_request': false,
        'error': 'Network error. Please check your connection.',
      };
    } finally {
      print('=== END STATUS CHECK DEBUG ===');
    }
  }

  /// Cancel pending deletion request
  /// Returns success status
  static Future<Map<String, dynamic>> cancelDeletionRequest() async {
    try {
      print('=== CANCEL DELETION REQUEST DEBUG ===');

      final userData = UserData();
      final token = await userData.getToken();

      if (token == null) {
        print('Error: No token found');
        return {'success': false, 'error': 'Authentication required. Please login again.'};
      }

      print('API URL: $baseUrl/account/deletion-request');

      final response = await http.delete(
        Uri.parse('$baseUrl/account/deletion-request'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        print('✅ Deletion request cancelled successfully');
        return {
          'success': true,
          'message': data['message'] ?? 'Deletion request cancelled successfully',
          'data': data,
        };
      } else if (response.statusCode == 404) {
        print('ℹ️ No pending deletion request found');
        return {
          'success': false,
          'error': data['message'] ?? 'No pending deletion request found',
        };
      } else {
        print('❌ Cancellation failed');
        return {
          'success': false,
          'error': data['message'] ?? 'Failed to cancel deletion request',
        };
      }
    } catch (e) {
      print('Error in cancelDeletionRequest: $e');
      return {
        'success': false,
        'error': 'Network error. Please check your connection.',
      };
    } finally {
      print('=== END CANCEL REQUEST DEBUG ===');
    }
  }
}