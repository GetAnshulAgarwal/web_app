// lib/services/notifications/order_notification_manager.dart

import 'notification_api_service.dart';

class OrderNotificationManager {
  static final OrderNotificationManager _instance = OrderNotificationManager._internal();
  factory OrderNotificationManager() => _instance;
  OrderNotificationManager._internal();

  final NotificationApiService _notificationApi = NotificationApiService();

  // Track if this is user's first order
  static bool _isFirstOrderForUser = true; // You can implement proper tracking

  // Call this when user places an order
  Future<void> handleOrderPlaced({
    required String customerId,
    required String orderId,
    required double orderAmount,
    required List<String> items,
  }) async {
    print('DEBUG: handleOrderPlaced TRIGGERED for orderId: $orderId'); // <-- Recommended debug line
    try {
      if (_isFirstOrderForUser) {
        // Send first order notification with your custom content
        await _notificationApi.sendFirstOrderNotification(
          customerId: customerId,
          orderId: orderId,
          messageIndex: 0, // You can randomize this (0, 1, 2)
        );
        _isFirstOrderForUser = false; // Mark as no longer first order
      } else {
        // Send regular order confirmation notification
        await _notificationApi.sendOrderConfirmationNotification(
          customerId: customerId,
          orderId: orderId,
          orderAmount: orderAmount,
          messageIndex: 1, // You can randomize this
        );
      }

      print('Order placed notification sent for order: $orderId');
    } catch (e) {
      print('Error sending order placed notification: $e');
    }
  }

  // Call this when order status changes
  Future<void> handleOrderStatusChange({
    required String customerId,
    required String orderId,
    required String newStatus,
    String? estimatedDeliveryTime,
    String? trackingNumber,
  }) async {
    try {
      await _notificationApi.sendOrderStatusNotification(
        customerId: customerId,
        orderId: orderId,
        status: newStatus,
        messageIndex: _getRandomMessageIndex(), // Randomize messages
        additionalMessage: _buildAdditionalMessage(
          newStatus,
          estimatedDeliveryTime,
          trackingNumber,
        ),
      );

      print('Order status notification sent for order: $orderId, status: $newStatus');
    } catch (e) {
      print('Error sending order status notification: $e');
    }
  }

  // Van booking notification
  Future<void> handleVanBooking({
    required String customerId,
    required String bookingId,
    required String location,
    required DateTime scheduledTime,
  }) async {
    print('DEBUG: handleVanBooking TRIGGERED for bookingId: $bookingId'); // <-- Recommended debug line
    try {
      await _notificationApi.sendVanBookingNotification(
        customerId: customerId,
        bookingId: bookingId,
        messageIndex: _getRandomMessageIndex(),
      );

      print('Van booking notification sent for booking: $bookingId');
    } catch (e) {
      print('Error sending van booking notification: $e');
    }
  }

  // Van nearby notification
  Future<void> handleVanNearby({
    required String customerId,
    required String location,
  }) async {
    try {
      await _notificationApi.sendVanNearbyNotification(
        customerId: customerId,
        messageIndex: _getRandomMessageIndex(),
      );

      print('Van nearby notification sent');
    } catch (e) {
      print('Error sending van nearby notification: $e');
    }
  }

  // Van arrived notification
  Future<void> handleVanArrived({
    required String customerId,
    required String location,
  }) async {
    try {
      await _notificationApi.sendVanArrivedNotification(
        customerId: customerId,
        messageIndex: _getRandomMessageIndex(),
      );

      print('Van arrived notification sent');
    } catch (e) {
      print('Error sending van arrived notification: $e');
    }
  }

  // Send delivery reminder
  Future<void> sendDeliveryReminder({
    required String customerId,
    required String orderId,
    required String estimatedTime,
  }) async {
    try {
      await _notificationApi.sendNotificationToUser(
        customerId: customerId,
        title: 'Almost there',
        body: 'Your order #${_getShortOrderId(orderId)} is on its final mile. Expected delivery: $estimatedTime',
        data: {
          'type': 'delivery_reminder',
          'orderId': orderId,
          'action': 'view_order',
        },
      );
    } catch (e) {
      print('Error sending delivery reminder: $e');
    }
  }

  // Send payment confirmation
  Future<void> sendPaymentConfirmation({
    required String customerId,
    required String orderId,
    required double amount,
    required String paymentMethod,
  }) async {
    try {
      await _notificationApi.sendNotificationToUser(
        customerId: customerId,
        title: 'Done deal',
        body: 'Payment of ₹${amount.toStringAsFixed(2)} confirmed for order #${_getShortOrderId(orderId)}. Thanks for choosing us!',
        data: {
          'type': 'payment_confirmation',
          'orderId': orderId,
          'amount': amount.toString(),
          'action': 'view_order',
        },
      );
    } catch (e) {
      print('Error sending payment confirmation: $e');
    }
  }

  // Send welcome notification for new users
  Future<void> sendWelcomeNotification({
    required String customerId,
  }) async {
    try {
      await _notificationApi.sendWelcomeNotification(
        customerId: customerId,
        messageIndex: _getRandomMessageIndex(),
      );

      print('Welcome notification sent');
    } catch (e) {
      print('Error sending welcome notification: $e');
    }
  }

  // Cart abandonment notification
  Future<void> sendCartAbandonmentNotification({
    required String customerId,
    required List<String> itemNames,
  }) async {
    try {
      final messages = [
        {
          'title': 'Your cart looks ready',
          'body': 'Just one tap away from fresh groceries.'
        },
        {
          'title': 'Don\'t leave them behind',
          'body': 'Items in your cart are waiting for you.'
        },
        {
          'title': 'Almost there',
          'body': 'Complete your order before it slips away.'
        },
      ];

      final message = messages[_getRandomMessageIndex()];

      await _notificationApi.sendNotificationToUser(
        customerId: customerId,
        title: message['title']!,
        body: message['body']!,
        data: {
          'type': 'cart_abandonment',
          'action': 'view_cart',
        },
      );

      print('Cart abandonment notification sent');
    } catch (e) {
      print('Error sending cart abandonment notification: $e');
    }
  }

  // Send promotional notification
  Future<void> sendPromotionalNotification({
    required String customerId,
    required String title,
    required String message,
    String? imageUrl,
    String? deepLink,
  }) async {
    try {
      await _notificationApi.sendNotificationToUser(
        customerId: customerId,
        title: title,
        body: message,
        data: {
          'type': 'promotional',
          'imageUrl': imageUrl,
          'deepLink': deepLink,
          'action': 'open_offer',
        },
      );
    } catch (e) {
      print('Error sending promotional notification: $e');
    }
  }

  // Helper methods
  String _buildAdditionalMessage(
      String status,
      String? estimatedDeliveryTime,
      String? trackingNumber,
      ) {
    switch (status.toLowerCase()) {
      case 'processing':
        return estimatedDeliveryTime != null
            ? ' Ready in: $estimatedDeliveryTime'
            : '';
      case 'shipped':
        return trackingNumber != null
            ? ' Track: $trackingNumber'
            : '';
      case 'out_for_delivery':
        return estimatedDeliveryTime != null
            ? ' ETA: $estimatedDeliveryTime'
            : '';
      case 'delivered':
        return ' Hope you loved it!';
      default:
        return '';
    }
  }

  String _getShortOrderId(String orderId) {
    if (orderId.length > 8) {
      return orderId.substring(orderId.length - 8);
    }
    return orderId;
  }

  int _getRandomMessageIndex() {
    return DateTime.now().millisecondsSinceEpoch % 3;
  }

  // Method to determine if this is user's first order
  Future<bool> _isUserFirstOrder(String customerId) async {
    try {
      // You can implement this by checking your order history API
      // For now, returning a simple logic
      return _isFirstOrderForUser;
    } catch (e) {
      return false;
    }
  }

  // Utility method for testing notifications
  Future<void> sendTestNotification({
    required String customerId,
    required String type,
    Map<String, dynamic>? testData,
  }) async {
    try {
      switch (type) {
        case 'welcome':
          await sendWelcomeNotification(customerId: customerId);
          break;

        case 'first_order':
          await _notificationApi.sendFirstOrderNotification(
            customerId: customerId,
            orderId: testData?['orderId'] ?? 'TEST123456',
            messageIndex: 0,
          );
          break;

        case 'order_placed':
          await handleOrderPlaced(
            customerId: customerId,
            orderId: testData?['orderId'] ?? 'TEST123456',
            orderAmount: testData?['amount'] ?? 299.99,
            items: testData?['items'] ?? ['Chicken Biryani', 'Coke 500ml'],
          );
          break;

        case 'status_change':
          await handleOrderStatusChange(
            customerId: customerId,
            orderId: testData?['orderId'] ?? 'TEST123456',
            newStatus: testData?['status'] ?? 'processing',
            estimatedDeliveryTime: testData?['estimatedTime'],
          );
          break;

        case 'van_booking':
          await handleVanBooking(
            customerId: customerId,
            bookingId: testData?['bookingId'] ?? 'VAN123',
            location: testData?['location'] ?? 'Test Location',
            scheduledTime: DateTime.now().add(Duration(hours: 2)),
          );
          break;

        case 'van_nearby':
          await handleVanNearby(
            customerId: customerId,
            location: testData?['location'] ?? 'Test Location',
          );
          break;

        case 'van_arrived':
          await handleVanArrived(
            customerId: customerId,
            location: testData?['location'] ?? 'Test Location',
          );
          break;

        case 'cart_abandonment':
          await sendCartAbandonmentNotification(
            customerId: customerId,
            itemNames: testData?['items'] ?? ['Test Item 1', 'Test Item 2'],
          );
          break;

        case 'payment':
          await sendPaymentConfirmation(
            customerId: customerId,
            orderId: testData?['orderId'] ?? 'TEST123456',
            amount: testData?['amount'] ?? 299.99,
            paymentMethod: testData?['method'] ?? 'UPI',
          );
          break;

        case 'delivery_reminder':
          await sendDeliveryReminder(
            customerId: customerId,
            orderId: testData?['orderId'] ?? 'TEST123456',
            estimatedTime: testData?['time'] ?? '15 minutes',
          );
          break;
      }
    } catch (e) {
      print('Error sending test notification: $e');
    }
  }
}