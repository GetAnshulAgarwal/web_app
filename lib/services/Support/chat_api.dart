import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatApiService {
  static const String baseUrl = 'https://pos.inspiredgrow.in/vps/api/chat';
  static final ChatApiService _instance = ChatApiService._internal();
  factory ChatApiService() => _instance;
  ChatApiService._internal();

  String? _jwtToken;

  void setToken(String token) {
    _jwtToken = token.trim();
    print('Token set: $_jwtToken');
  }

  String? get token => _jwtToken;

  // Build headers with optional content-type; Authorization included only when token set
  Map<String, String> _buildHeaders({bool withContentType = false}) {
    final headers = <String, String>{};
    if (withContentType) headers['Content-Type'] = 'application/json';
    if (_jwtToken != null) headers['Authorization'] = 'Bearer ${_jwtToken!}';
    return headers;
  }

  Future<Map<String, dynamic>> startOrRetrieveConversation(
    String otherUserId,
  ) async {
    print('');
    print('📞 [ChatAPI] ========================================');
    print('📞 [ChatAPI] Starting conversation');
    print('📞 [ChatAPI] URL: $baseUrl/conversations');
    print('📞 [ChatAPI] Other User ID: $otherUserId');
    print('📞 [ChatAPI] ========================================');
    print('📞[ChatAPI] Using Token: $_jwtToken');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/conversations'),
        headers: _buildHeaders(withContentType: true),
        body: json.encode({'otherUserId': otherUserId}),
      );

      print('📥 [ChatAPI] Response Status: ${response.statusCode}');
      print('📥 [ChatAPI] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        print('✅ [ChatAPI] Conversation established successfully');
        print('✅ [ChatAPI] Conversation ID: ${data['_id']}');
        return data;
      } else {
        print('❌ [ChatAPI] Failed to start conversation');
        print('❌ [ChatAPI] Status: ${response.statusCode}');
        print('❌ [ChatAPI] Body: ${response.body}');
        throw Exception('Failed to start conversation: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('❌ [ChatAPI] Exception in startOrRetrieveConversation: $e');
      print('📍 [ChatAPI] Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<dynamic>> getMessages(
    String conversationId, {
    int limit = 50,
    String? before,
  }) async {
    print('');
    print('📨 [ChatAPI] ========================================');
    print('📨 [ChatAPI] Fetching messages');
    print('📨 [ChatAPI] Conversation ID: $conversationId');
    print('📨 [ChatAPI] Limit: $limit');
    if (before != null) print('📨 [ChatAPI] Before: $before');
    print('📨 [ChatAPI] ========================================');

    try {
      final queryParams = {
        'limit': limit.toString(),
        if (before != null) 'before': before,
      };

      final uri = Uri.parse(
        '$baseUrl/conversations/$conversationId/messages',
      ).replace(queryParameters: queryParams);
      print('🌐 [ChatAPI] Request URL: $uri');

      final response = await http.get(uri, headers: _buildHeaders());

      print('📥 [ChatAPI] Response Status: ${response.statusCode}');
      print('📥 [ChatAPI] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final messages = json.decode(response.body)['data'] as List;
        print('✅ [ChatAPI] Loaded ${messages.length} messages');

        // Print first few messages for debugging
        for (int i = 0; i < messages.length && i < 3; i++) {
          final msg = messages[i];
          print(
            '   📝 Message ${i + 1}: ${msg['_id']} - ${msg['body']?.substring(0, msg['body'].length > 50 ? 50 : msg['body'].length)}...',
          );
        }

        return messages;
      } else {
        print('❌ [ChatAPI] Failed to load messages');
        print('❌ [ChatAPI] Status: ${response.statusCode}');
        print('❌ [ChatAPI] Body: ${response.body}');
        throw Exception('Failed to load messages: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('❌ [ChatAPI] Exception in getMessages: $e');
      print('📍 [ChatAPI] Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sendMessage(
    String conversationId,
    String body,
  ) async {
    print('');
    print('📤 [ChatAPI] ========================================');
    print('📤 [ChatAPI] Sending message');
    print('📤 [ChatAPI] URL: $baseUrl/messages');
    print('📤 [ChatAPI] Conversation ID: $conversationId');
    print('📤 [ChatAPI] Message Body: $body');
    print('📤 [ChatAPI] ========================================');

    try {
      final requestBody = json.encode({
        'conversationId': conversationId,
        'body': body,
      });

      print('📦 [ChatAPI] Request Body: $requestBody');

      final response = await http.post(
        Uri.parse('$baseUrl/messages'),
        headers: _buildHeaders(withContentType: true),
        body: requestBody,
      );

      print('📥 [ChatAPI] Response Status: ${response.statusCode}');
      print('📥 [ChatAPI] Response Body: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body)['data'];
        print('✅ [ChatAPI] Message sent successfully');
        print('✅ [ChatAPI] Message ID: ${data['_git id']}');
        return data;
      } else {
        print('❌ [ChatAPI] Failed to send message');
        print('❌ [ChatAPI] Status: ${response.statusCode}');
        print('❌ [ChatAPI] Body: ${response.body}');
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('❌ [ChatAPI] Exception in sendMessage: $e');
      print('📍 [ChatAPI] Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> markMessageAsRead(String messageId) async {
    print('');
    print('✓ [ChatAPI] ========================================');
    print('✓ [ChatAPI] Marking message as read');
    print('✓ [ChatAPI] Message ID: $messageId');
    print('✓ [ChatAPI] ========================================');

    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/messages/$messageId/read'),
        headers: _buildHeaders(),
      );

      print('📥 [ChatAPI] Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ [ChatAPI] Message marked as read successfully');
      } else {
        print('❌ [ChatAPI] Failed to mark message as read');
        print('❌ [ChatAPI] Status: ${response.statusCode}');
        print('❌ [ChatAPI] Body: ${response.body}');
        throw Exception(
          'Failed to mark message as read: ${response.statusCode}',
        );
      }
    } catch (e, stackTrace) {
      print('❌ [ChatAPI] Exception in markMessageAsRead: $e');
      print('📍 [ChatAPI] Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> markAllMessagesAsRead(String conversationId) async {
    print('');
    print('✓✓ [ChatAPI] ========================================');
    print('✓✓ [ChatAPI] Marking all messages as read');
    print('✓✓ [ChatAPI] Conversation ID: $conversationId');
    print('✓✓ [ChatAPI] ========================================');

    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/conversations/$conversationId/readAll'),
        headers: _buildHeaders(),
      );

      print('📥 [ChatAPI] Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ [ChatAPI] All messages marked as read successfully');
      } else {
        print('❌ [ChatAPI] Failed to mark all messages as read');
        print('❌ [ChatAPI] Status: ${response.statusCode}');
        print('❌ [ChatAPI] Body: ${response.body}');
        throw Exception(
          'Failed to mark all messages as read: ${response.statusCode}',
        );
      }
    } catch (e, stackTrace) {
      print('❌ [ChatAPI] Exception in markAllMessagesAsRead: $e');
      print('📍 [ChatAPI] Stack trace: $stackTrace');
      rethrow;
    }
  }
}
