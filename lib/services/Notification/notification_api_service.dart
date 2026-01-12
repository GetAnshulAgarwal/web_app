// lib/services/notifications/notification_api_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../authentication/user_data.dart';
import 'notification_content_service.dart';

class NotificationApiService {
  static const String baseUrl = 'https://pos.inspiredgrow.in/vps/api/push';
  final UserData _userData = UserData();

  Future<Map<String, String>> _getHeaders({bool isAdmin = false}) async {
    final token = _userData.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${isAdmin ? 'ADMIN_JWT' : token ?? ''}',
    };
  }

  // Register device token
  Future<bool> registerDeviceToken(String deviceToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register-token'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'deviceToken': deviceToken,
          'platform': 'android',
        }),
      );

      if (response.statusCode == 200) {
        print('Device token registered successfully');
        return true;
      } else {
        print('Failed to register device token: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error registering device token: $e');
      return false;
    }
  }

  // Send welcome notification
  Future<bool> sendWelcomeNotification({
    required String customerId,
    int? messageIndex,
  }) async {
    final notification = messageIndex != null
        ? NotificationContentService.getNotificationByIndex('welcome', messageIndex)
        : NotificationContentService.getRandomNotification('welcome');

    return await sendNotificationToUser(
      customerId: customerId,
      title: notification['title']!,
      body: notification['body']!,
      data: {
        'type': 'welcome',
        'action': 'open_app',
      },
    );
  }

  // Send first order notification
  Future<bool> sendFirstOrderNotification({
    required String customerId,
    required String orderId,
    int? messageIndex,
  }) async {
    final notification = messageIndex != null
        ? NotificationContentService.getNotificationByIndex('first_order', messageIndex)
        : NotificationContentService.getRandomNotification('first_order');

    return await sendNotificationToUser(
      customerId: customerId,
      title: notification['title']!,
      body: notification['body']!,
      data: {
        'type': 'first_order',
        'orderId': orderId,
        'action': 'view_order',
      },
    );
  }

  // Send order confirmation notification
  Future<bool> sendOrderConfirmationNotification({
    required String customerId,
    required String orderId,
    required double orderAmount,
    int? messageIndex,
  }) async {
    final notification = messageIndex != null
        ? NotificationContentService.getNotificationByIndex('order_placed', messageIndex)
        : NotificationContentService.getRandomNotification('order_placed');

    return await sendNotificationToUser(
      customerId: customerId,
      title: notification['title']!,
      body: notification['body']!,
      data: {
        'type': 'order_confirmation',
        'orderId': orderId,
        'amount': orderAmount.toString(),
        'action': 'view_order',
      },
    );
  }

  // Send order status notification with your content
// lib/services/notifications/notification_api_service.dart

  // Send order status notification with your content
  Future<bool> sendOrderStatusNotification({
    required String customerId,
    required String orderId,
    required String status,
    String? additionalMessage,
    int? messageIndex,
  }) async {
    String notificationType;
    String displayStatus = status; // Default to the raw status

    switch (status.toLowerCase()) {
      case 'processing':
      case 'picked_up':
        notificationType = 'order_processing';
        displayStatus = 'Processing';
        break;
      case 'shipped':
      case 'in_transit': // <-- Added 'in_transit' from your screenshot
        notificationType = 'order_shipped';
        displayStatus = 'Shipped';
        break;
      case 'out_for_delivery':
        notificationType = 'out_for_delivery';
        displayStatus = 'Out for Delivery';
        break;
      case 'delivered':
        notificationType = 'delivered';
        displayStatus = 'Delivered';
        break;
      default:
        notificationType = 'order_placed';
        displayStatus = 'Placed';
    }

    // Get the friendly body message
    final notification = messageIndex != null
        ? NotificationContentService.getNotificationByIndex(notificationType, messageIndex)
        : NotificationContentService.getRandomNotification(notificationType);

    // --- THIS IS THE FIX ---

    // 1. Get the short, readable ID
    final shortOrderId = _getShortId(orderId);

    // 2. Create a clean, informative title
    final String title = 'Order ${displayStatus}: #${shortOrderId}';

    // 3. Use the friendly content for the body
    String body = notification['body']!;
    if (additionalMessage != null) {
      body = '$body $additionalMessage';
    }

    // --- END OF FIX ---

    return await sendNotificationToUser(
      customerId: customerId,
      title: title, // <-- Use new friendly title
      body: body,   // <-- Use friendly body
      data: {
        'type': 'order_status',
        'orderId': orderId,
        'status': status,
        'action': 'view_order',
      },
    );
  }

  // Send van booking notification
  Future<bool> sendVanBookingNotification({
    required String customerId,
    required String bookingId,
    int? messageIndex,
  }) async {
    final notification = messageIndex != null
        ? NotificationContentService.getNotificationByIndex('van_booking', messageIndex)
        : NotificationContentService.getRandomNotification('van_booking');

    // --- THIS IS THE FIX ---

    // 1. Get the short, readable ID
    final shortBookingId = _getShortId(bookingId);

    // 2. Create a clean, informative title
    //    We use the title from the content service here, but add the ID
    final String title = '${notification['title']!}: #${shortBookingId}';

    // 3. Use the friendly content for the body
    String body = notification['body']!;

    // --- END OF FIX ---

    return await sendNotificationToUser(
      customerId: customerId,
      title: title, // <-- Use new friendly title
      body: body,   // <-- Use friendly body
      data: {
        'type': 'van_booking',
        'bookingId': bookingId,
        'action': 'view_booking',
      },
    );
  }

  // Send van nearby notification
  Future<bool> sendVanNearbyNotification({
    required String customerId,
    int? messageIndex,
  }) async {
    final notification = messageIndex != null
        ? NotificationContentService.getNotificationByIndex('van_near', messageIndex)
        : NotificationContentService.getRandomNotification('van_near');

    return await sendNotificationToUser(
      customerId: customerId,
      title: notification['title']!,
      body: notification['body']!,
      data: {
        'type': 'van_nearby',
        'action': 'track_van',
      },
    );
  }

  // Send van arrived notification
  Future<bool> sendVanArrivedNotification({
    required String customerId,
    int? messageIndex,
  }) async {
    final notification = messageIndex != null
        ? NotificationContentService.getNotificationByIndex('van_arrived', messageIndex)
        : NotificationContentService.getRandomNotification('van_arrived');

    return await sendNotificationToUser(
      customerId: customerId,
      title: notification['title']!,
      body: notification['body']!,
      data: {
        'type': 'van_arrived',
        'action': 'start_shopping',
      },
    );
  }

  // Core notification sending method
  Future<bool> sendNotificationToUser({
    required String customerId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // The requestBody is a Map<String, dynamic> which is correct
      final Map<String, dynamic> requestBody = {
        'customerId': customerId,
        'title': title,
        'body': body,
      };

      // This now correctly adds the data map if it exists
      if (data != null) {
        requestBody['data'] = data;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/send'),
        headers: await _getHeaders(isAdmin: true),
        body: jsonEncode(requestBody), // jsonEncode handles the nested map
      );

      if (response.statusCode == 200) {
        print('✅ Notification sent: $title');
        return true;
      } else {
        print('❌ Failed to send notification: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending notification: $e');
      return false;
    }
  }

  // Broadcast notification
  // In lib/services/notifications/notification_api_service.dart

  Future<bool> broadcastNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final Map<String, dynamic> requestBody = {
        'title': title,
        'body': body,
      };

      // This correctly adds the data map without the previous bug
      if (data != null) {
        requestBody['data'] = data;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/broadcast'),
        headers: await _getHeaders(isAdmin: true),
        body: jsonEncode(requestBody),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error broadcasting notification: $e');
      return false;
    }
  }
  String _getShortId(String id) {
    if (id.length > 8) {
      // Returns the last 8 characters
      return id.substring(id.length - 8);
    }
    return id;
  }
}