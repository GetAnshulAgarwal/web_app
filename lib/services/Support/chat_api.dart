import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ChatApiService {
  static const String baseUrl = 'https://pos.inspiredgrow.in/vps/api/chat';
  static const String returnsBaseUrl = 'https://pos.inspiredgrow.in/vps/returns';

  static final ChatApiService _instance = ChatApiService._internal();
  factory ChatApiService() => _instance;
  ChatApiService._internal();

  String? _jwtToken;

  void setToken(String token) {
    _jwtToken = token.trim();
  }

  Map<String, String> _buildHeaders({bool withContentType = false}) {
    final headers = <String, String>{};
    if (withContentType) headers['Content-Type'] = 'application/json';
    if (_jwtToken != null) headers['Authorization'] = 'Bearer ${_jwtToken!}';
    return headers;
  }

  Future<Map<String, dynamic>> startOrRetrieveConversation(String otherUserId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/conversations'),
        headers: _buildHeaders(withContentType: true),
        body: json.encode({'otherUserId': otherUserId}),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body)['data'];
      } else {
        throw Exception('Failed to start conversation: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getMessages(String conversationId, {int limit = 50, String? before}) async {
    try {
      final queryParams = {'limit': limit.toString(), if (before != null) 'before': before};
      final uri = Uri.parse('$baseUrl/conversations/$conversationId/messages').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _buildHeaders());
      if (response.statusCode == 200) {
        return json.decode(response.body)['data'] as List;
      } else {
        throw Exception('Failed to load messages');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sendMessage(String conversationId, String body) async {
    try {
      final requestBody = json.encode({'conversationId': conversationId, 'body': body});
      final response = await http.post(
        Uri.parse('$baseUrl/messages'),
        headers: _buildHeaders(withContentType: true),
        body: requestBody,
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body)['data'];
      } else {
        throw Exception('Failed to send message');
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- STANDARD CHAT UPLOAD (Fallback) ---
  Future<Map<String, dynamic>> sendImageMessage(String conversationId, File imageFile, {String? caption}) async {
    print('📤 [ChatAPI] Sending Chat Image...');
    try {
      var uri = Uri.parse('$baseUrl/messages');
      var request = http.MultipartRequest('POST', uri);

      request.headers.addAll({
        'Authorization': 'Bearer ${_jwtToken ?? ''}',
      });

      // Fields MUST be added before files for some server parsers
      // We send 'conversationId' to match the JSON endpoint key expected by the controller
      request.fields['conversationId'] = conversationId;
      request.fields['body'] = caption ?? 'Image Attachment';

      var stream = http.ByteStream(imageFile.openRead());
      var length = await imageFile.length();

      var multipartFile = http.MultipartFile(
        'image',
        stream,
        length,
        filename: imageFile.path.split('/').last,
        contentType: MediaType('image', 'jpeg'),
      );

      request.files.add(multipartFile);

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('📥 [ChatAPI] Chat Image Status: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body)['data'];
      } else {
        throw Exception('Upload failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ [ChatAPI] Chat Upload Error: $e');
      rethrow;
    }
  }

  // --- NEW: RETURN IMAGE UPLOAD (Correct Endpoint) ---
// --- FIXED: "Smart" Upload that tries multiple field names ---
  Future<Map<String, dynamic>> uploadReturnImage(String returnId, File imageFile) async {
    print('🔍 [ChatAPI] Starting Smart Upload to: $returnsBaseUrl/$returnId/images');

    // These are the most common keys backends expect. We try them one by one.
    final possibleFieldNames = [
      'images',      // Common for /images endpoint
      'file',        // Standard singular
      'files',       // Standard plural
      'image',       // Common singular
      'attachment',  // Common for support
      'evidence'     // Specific to returns
    ];

    for (final fieldName in possibleFieldNames) {
      print('🔄 [ChatAPI] Trying field name: "$fieldName"...');

      try {
        var uri = Uri.parse('$returnsBaseUrl/$returnId/images');
        var request = http.MultipartRequest('POST', uri);

        request.headers.addAll({
          'Authorization': 'Bearer ${_jwtToken ?? ''}',
          // Do NOT set Content-Type here; MultipartRequest sets it automatically
        });

        var stream = http.ByteStream(imageFile.openRead());
        var length = await imageFile.length();

        var multipartFile = http.MultipartFile(
          fieldName, // <--- Using the current guess from our list
          stream,
          length,
          filename: imageFile.path.split('/').last,
          contentType: MediaType('image', 'jpeg'),
        );

        request.files.add(multipartFile);

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        // If specific failure "Unexpected field", we continue to the next key
        if (response.statusCode == 500 && response.body.contains("Unexpected field")) {
          print('❌ Field "$fieldName" rejected. Trying next...');
          continue;
        }

        // If success
        if (response.statusCode == 200 || response.statusCode == 201) {
          print('✅ SUCCESS! The correct field name is: "$fieldName"');
          final body = json.decode(response.body);
          return body['data'] ?? body;
        }

        // If other error (not field name related), throw it
        print('❌ Upload failed with status ${response.statusCode}: ${response.body}');
        throw Exception('Upload failed: ${response.statusCode}');

      } catch (e) {
        // If it's the last attempt, rethrow the error
        if (fieldName == possibleFieldNames.last) {
          print('❌ All field names failed. Last error: $e');
          rethrow;
        }
      }
    }

    throw Exception('Unable to determine correct upload field name');
  }

  Future<void> markAllMessagesAsRead(String conversationId) async {
    try {
      await http.patch(Uri.parse('$baseUrl/conversations/$conversationId/readAll'), headers: _buildHeaders());
    } catch (e) {
      print('Error marking read: $e');
    }
  }

  Future<Map<String, dynamic>> createReturnRequest({
    required String orderId,
    required String itemId,
    String reason = "Damaged item received",
    String notes = "Packaging was open",
  }) async {
    try {
      final requestBody = json.encode({
        "orderId": orderId,
        "itemId": itemId,
        "reason": reason,
        "notes": notes
      });

      final response = await http.post(
        Uri.parse('$returnsBaseUrl/request'),
        headers: _buildHeaders(withContentType: true),
        body: requestBody,
      );

      final body = json.decode(response.body);

      // SUCCESS: Created new return
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (body['success'] == true) {
          // Handle case where data might be a list or a map
          if (body['data'] is List && (body['data'] as List).isNotEmpty) {
            return body['data'][0];
          }
          return body['data'];
        } else {
          throw Exception(body['message']);
        }
      }
      // CONFLICT: Return ALREADY EXISTS (Error 409)
      else if (response.statusCode == 409) {
        print("⚠️ [ChatAPI] Return already exists.");

        // Smart Handling: If the server returns the EXISTING return data, use it!
        if (body['data'] != null) {
          if (body['data'] is List && (body['data'] as List).isNotEmpty) {
            return body['data'][0];
          }
          return body['data'];
        }

        // If no data, throw specific flag
        throw Exception("RETURN_EXISTS");
      }
      // OTHER ERRORS
      else {
        throw Exception(body['message'] ?? 'Return request failed: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}