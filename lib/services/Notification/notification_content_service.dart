// lib/services/notifications/notification_content_service.dart
class NotificationContentService {
  static const Map<String, List<Map<String, String>>> notificationContent = {
    'welcome': [
      {
        'title': 'Freshness at your doorstep',
        'body': 'Welcome aboard! Your groceries just got faster.'
      },
      {
        'title': 'Hey, you\'re in!',
        'body': 'Shopping is now as easy as tapping once.'
      },
      {
        'title': 'Hello from Grocery on Wheels',
        'body': 'Fresh, fast, and right where you need it.'
      },
    ],
    'first_order': [
      {
        'title': 'Your first order is locked',
        'body': 'Fresh groceries are being packed for you.'
      },
      {
        'title': 'First step, first order',
        'body': 'Thanks for starting your journey with us.'
      },
      {
        'title': 'Freshness is on the way',
        'body': 'Your first order has been placed successfully.'
      },
    ],
    'order_placed': [
      {
        'title': 'Order confirmed',
        'body': 'Your groceries are now in queue.'
      },
      {
        'title': 'Done & dusted',
        'body': 'We\'ve received your order successfully.'
      },
      {
        'title': 'All set',
        'body': 'Your order is placed. Sit back and relax.'
      },
    ],
    'order_processing': [
      {
        'title': 'Picked and packed',
        'body': 'Your order is on the move now.'
      },
      {
        'title': 'Groceries collected',
        'body': 'Your items are ready for delivery.'
      },
      {
        'title': 'Out from store',
        'body': 'Order picked, heading your way.'
      },
    ],
    'order_shipped': [
      {
        'title': 'Order shipped',
        'body': 'Your groceries are on the road.'
      },
      {
        'title': 'It\'s moving',
        'body': 'Freshness is heading towards you.'
      },
      {
        'title': 'Shipped successfully',
        'body': 'Your order is on its way.'
      },
    ],
    'out_for_delivery': [
      {
        'title': 'Out for delivery',
        'body': 'Your groceries will reach you soon.'
      },
      {
        'title': 'Almost there',
        'body': 'Your order is on its final mile.'
      },
      {
        'title': 'On the way',
        'body': 'Expect your groceries shortly.'
      },
    ],
    'delivered': [
      {
        'title': 'Delivered successfully',
        'body': 'Enjoy your fresh groceries.'
      },
      {
        'title': 'Done deal',
        'body': 'Order completed. Hope you loved it.'
      },
      {
        'title': 'Delivered!',
        'body': 'Thanks for shopping with us again.'
      },
    ],
    'van_booking': [
      {
        'title': 'Van booked for you',
        'body': 'Your mobile grocery store is reserved.'
      },
      {
        'title': 'Spot secured',
        'body': 'Your van booking is now confirmed.'
      },
      {
        'title': 'All set',
        'body': 'The van will be there as scheduled.'
      },
    ],
    'van_near': [
      {
        'title': 'Look around!',
        'body': 'Your grocery van is nearby.'
      },
      {
        'title': 'Close to you',
        'body': 'The van is now in your area.'
      },
      {
        'title': 'Freshness has arrived',
        'body': 'Shop while the van is just around.'
      },
    ],
    'van_arrived': [
      {
        'title': 'We\'re here',
        'body': 'The van has reached your location.'
      },
      {
        'title': 'Outside now',
        'body': 'Step out for instant fresh groceries.'
      },
      {
        'title': 'Knock knock',
        'body': 'The van is waiting right outside.'
      },
    ],
  };

  static Map<String, String> getRandomNotification(String type) {
    final notifications = notificationContent[type];
    if (notifications == null || notifications.isEmpty) {
      return {
        'title': 'Grocery on Wheels',
        'body': 'You have a new update!'
      };
    }

    final random = DateTime.now().millisecondsSinceEpoch % notifications.length;
    return notifications[random];
  }

  static Map<String, String> getNotificationByIndex(String type, int index) {
    final notifications = notificationContent[type];
    if (notifications == null || notifications.isEmpty || index >= notifications.length) {
      return getRandomNotification(type);
    }
    return notifications[index];
  }
}