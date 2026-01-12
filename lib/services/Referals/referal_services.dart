// services/referral_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../authentication/user_data.dart';

class ReferralService {
  static const String _referralCodeKey = 'user_referral_code';

  static void _log(String message) {
    print("🔍 [ReferralService] $message");
  }

  static Future<String> getReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_referralCodeKey) ?? '';
  }

  static Future<void> setReferralCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_referralCodeKey, code);
  }

  static Future<String> generateReferralFromServer(
      String customerId, {
        String? token,
      }) async {
    if (customerId.trim().isEmpty) {
      _log('❌ generateReferralFromServer: Customer ID is empty!');
      return '';
    }

    final url = 'https://pos.inspiredgrow.in/vps/customer/$customerId/generate-referral';
    final headers = <String, String>{'Content-Type': 'application/json'};

    // Add token if available (optional based on your API description)
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      _log("→ POST $url");

      final response = await http.post(Uri.parse(url), headers: headers);

      _log("← Response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200) {
        final body = json.decode(response.body);

        // Parse logic based on your JSON:
        // { "success": true, "data": { "referralCode": "...", "created": true } }
        if (body['success'] == true && body['data'] != null) {
          final data = body['data'];
          if (data['referralCode'] != null) {
            final code = data['referralCode'].toString();
            await setReferralCode(code); // Cache it
            return code;
          }
        }
      }

      return '';
    } catch (e) {
      _log("❌ Error generating referral: $e");
      return '';
    }
  }

  // Apply Referral Code Logic
  static Future<Map<String, dynamic>> applyReferralCodeToServer(
      String referralCode, {
        String? token,
        String? customerId,
      }) async {
    String url;
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (customerId != null && customerId.isNotEmpty) {
      url = 'https://pos.inspiredgrow.in/vps/referral/apply-referral-code/$customerId';
    } else {
      url = 'https://pos.inspiredgrow.in/vps/referral/apply-referral-code';
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode({'referralCode': referralCode}),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<List<String>> fetchReferralHistory({String? token}) async {
    // 1. New Endpoint provided
    const url = 'https://pos.inspiredgrow.in/vps/referral/my-referrals';

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    // Token is required for "my-referrals" endpoint
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    } else {
      _log("❌ fetchReferralHistory: Token is missing!");
      return [];
    }

    try {
      _log("→ GET $url");
      final response = await http.get(Uri.parse(url), headers: headers);
      _log("← Response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200) {
        final body = json.decode(response.body);

        // 2. Parse based on provided JSON:
        // { "success": true, "data": [ { "referred": { "name": "Anshul", ... } } ] }
        if (body['success'] == true && body['data'] != null) {
          final List<dynamic> data = body['data'];

          return data.map<String>((item) {
            // Safe navigation to extract the name
            if (item['referred'] != null && item['referred']['name'] != null) {
              return item['referred']['name'].toString();
            }
            return "Unknown User";
          }).toList();
        }
      }
    } catch (e) {
      _log("❌ Error fetching history: $e");
    }
    return [];
  }
}