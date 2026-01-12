import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../authentication/user_data.dart';
import '../../model/Support/support_message.dart' show SupportMessage;
import '../../model/Support/support_ticket.dart';

class SupportApiService {
  static const String baseUrl = 'https://pos.inspiredgrow.in/vps/api/chat';
  static String supportUserId = 'support_team'; // Default support user ID

  // Create UserData instance
  static final UserData _userData = UserData();

  // Get JWT token from UserData
  static String? get jwtToken => _userData.getToken();

  // Get current user phone as ID (since phone is used as identifier)
  static String? get currentUserId => _userData.getPhone();

  // Get current user name
  static String? get currentUserName => _userData.getName();

  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (jwtToken != null) 'Authorization': 'Bearer $jwtToken',
  };

  // Check if user is authenticated
  static bool get isAuthenticated => _userData.isLoggedIn() && jwtToken != null;

  // Set support user ID if needed
  static void setSupportUserId(String supportId) {
    supportUserId = supportId;
  }

  // Get all support tickets/conversations
  static Future<List<SupportTicket>> getSupportTickets() async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated. Please login first.');
    }

    try {
      print('Making API call with token: ${jwtToken?.substring(0, 20)}...');
      print('Current User: ${currentUserName} (${currentUserId})');

      final response = await http.get(
        Uri.parse('$baseUrl/conversations'),
        headers: headers,
      );

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return (data['data'] as List)
              .map((json) => SupportTicket.fromJson(json))
              .toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to load support tickets');
        }
      } else if (response.statusCode == 401) {
        // Token might be expired, user needs to login again
        await _userData.clearUserData();
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. Insufficient permissions.');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Network Error: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('HandshakeException') ||
          e.toString().contains('Connection failed')) {
        throw Exception(
          'No internet connection. Please check your network and try again.',
        );
      }
      rethrow;
    }
  }

  // Create new support ticket/conversation
  static Future<SupportTicket> createSupportTicket([String? category]) async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated. Please login first.');
    }

    try {
      print('Creating support ticket with category: $category');
      print('Support User ID: $supportUserId');
      print('Current User: ${currentUserName} (${currentUserId})');

      final requestBody = {
        'otherUserId': supportUserId,
        'category': category ?? 'general',
        'metadata': {
          'userName': currentUserName,
          'userPhone': currentUserId,
          'userEmail': _userData.getEmail(),
        },
      };

      print('Request Body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('$baseUrl/conversations'),
        headers: headers,
        body: json.encode(requestBody),
      );

      print('Create Ticket Response Status: ${response.statusCode}');
      print('Create Ticket Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return SupportTicket.fromJson(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Failed to create support ticket');
        }
      } else if (response.statusCode == 401) {
        await _userData.clearUserData();
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access denied. Insufficient permissions.');
      } else if (response.statusCode == 400) {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ?? 'Invalid request. Please try again.',
        );
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ?? 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Create Ticket Error: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('HandshakeException') ||
          e.toString().contains('Connection failed')) {
        throw Exception(
          'No internet connection. Please check your network and try again.',
        );
      }
      rethrow;
    }
  }

  // Get messages for a specific ticket
  static Future<List<SupportMessage>> getMessages(
    String ticketId, {
    int limit = 50,
    String? before,
  }) async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated. Please login first.');
    }

    try {
      var url = '$baseUrl/conversations/$ticketId/messages?limit=$limit';
      if (before != null) url += '&before=$before';

      print('Fetching messages from: $url');

      final response = await http.get(Uri.parse(url), headers: headers);

      print('Get Messages Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return (data['data'] as List)
              .map((json) => SupportMessage.fromJson(json))
              .toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to load messages');
        }
      } else if (response.statusCode == 401) {
        await _userData.clearUserData();
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 404) {
        throw Exception('Conversation not found.');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('HandshakeException') ||
          e.toString().contains('Connection failed')) {
        throw Exception(
          'No internet connection. Please check your network and try again.',
        );
      }
      rethrow;
    }
  }

  // Send a message
  static Future<SupportMessage> sendMessage(
    String ticketId,
    String message,
  ) async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated. Please login first.');
    }

    try {
      final requestBody = {'conversationId': ticketId, 'body': message};

      print('Sending message: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('$baseUrl/messages'),
        headers: headers,
        body: json.encode(requestBody),
      );

      print('Send Message Response Status: ${response.statusCode}');
      print('Send Message Response Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return SupportMessage.fromJson(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Failed to send message');
        }
      } else if (response.statusCode == 401) {
        await _userData.clearUserData();
        throw Exception('Session expired. Please login again.');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to send message');
      }
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('HandshakeException') ||
          e.toString().contains('Connection failed')) {
        throw Exception(
          'No internet connection. Please check your network and try again.',
        );
      }
      rethrow;
    }
  }

  // Mark single message as read
  static Future<void> markMessageAsRead(String messageId) async {
    if (!isAuthenticated) return;

    try {
      await http.patch(
        Uri.parse('$baseUrl/messages/$messageId/read'),
        headers: headers,
      );
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  // Mark all messages in conversation as read
  static Future<void> markAllMessagesAsRead(String ticketId) async {
    if (!isAuthenticated) return;

    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/conversations/$ticketId/readAll'),
        headers: headers,
      );
      print('Mark all as read status: ${response.statusCode}');
    } catch (e) {
      print('Error marking all messages as read: $e');
    }
  }

  // Get user info for display
  static Map<String, String> getUserInfo() {
    return {
      'name': _userData.getName(),
      'phone': _userData.getPhone(),
      'email': _userData.getEmail(),
      'city': _userData.getCity(),
      'state': _userData.getState(),
      'country': _userData.getCountry(),
    };
  }
}
