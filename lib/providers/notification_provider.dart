import 'package:flutter/foundation.dart';

class NotificationProvider with ChangeNotifier {
  // A set to store the unique IDs of products requested for notification.
  final Set<String> _notifiedProductIds = {};

  // A method to check if a notification has been requested for a product.
  bool isNotificationRequested(String productId) {
    return _notifiedProductIds.contains(productId);
  }

  // A method to add a product to the notification list.
  void requestNotification(String productId) {
    if (_notifiedProductIds.add(productId)) {
      // Only notify listeners if a new ID was actually added.
      notifyListeners();
    }
  }
}