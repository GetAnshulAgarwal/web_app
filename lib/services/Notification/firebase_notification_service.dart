// lib/services/notifications/firebase_notification_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import '../../authentication/user_data.dart';

// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
  print('Message data: ${message.data}');

  // Firebase automatically shows the notification in background
  // No need to manually show it
}

class FirebaseNotificationService {
  static final FirebaseNotificationService _instance = FirebaseNotificationService._internal();
  factory FirebaseNotificationService() => _instance;
  FirebaseNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final UserData _userData = UserData();

  // Navigation callback
  Function(String)? onNotificationTap;

  static const String baseUrl = 'https://pos.inspiredgrow.in/vps/api/push';

  Future<void> initialize({Function(String)? onNotificationTap}) async {
    this.onNotificationTap = onNotificationTap;

    // Initialize Firebase
    await Firebase.initializeApp();

    // Request notification permissions
    await _requestPermissions();

    // Setup Firebase messaging handlers
    await _setupFirebaseMessaging();

    // Get and register FCM token if user is logged in
    if (_userData.isLoggedIn()) {
      await _registerDeviceToken();
    }
  }

  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('User granted permission: ${settings.authorizationStatus}');
  }

  Future<void> _setupFirebaseMessaging() async {
    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        // Firebase will handle showing the notification automatically
        // You can add custom UI here if needed (like in-app banner)
        _handleForegroundMessage(message);
      }
    });

    // Handle notification taps when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      _handleNotificationNavigation(message.data);
    });

    // Handle notification tap when app is terminated
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationNavigation(initialMessage.data);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // Handle foreground messages - Firebase shows notification automatically
    print('Foreground message: ${message.notification?.title} - ${message.notification?.body}');

    // Optional: You can show a custom in-app notification here
    // For example, a banner at the top of the screen
  }

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    try {
      print('Navigating with data: $data');

      final type = data['type'] ?? '';
      String route = '/home'; // Default route

      switch (type) {
        case 'order_confirmation':
        case 'order_status':
          final orderId = data['orderId'];
          if (orderId != null) {
            route = '/order-details/$orderId';
          } else {
            route = '/orders';
          }
          break;
        case 'promotional':
          final deepLink = data['deepLink'];
          if (deepLink != null) {
            route = deepLink;
          } else {
            route = '/offers';
          }
          break;
        case 'van_booking':
        case 'van_nearby':
        case 'van_arrived':
          route = '/van-tracking';
          break;
        case 'welcome':
          route = '/home';
          break;
        case 'cart_abandonment':
          route = '/cart';
          break;
      }

      // Call the navigation callback
      if (onNotificationTap != null) {
        onNotificationTap!(route);
      }
    } catch (e) {
      print('Error parsing notification data: $e');
    }
  }

  Future<void> _registerDeviceToken() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        print('FCM Token: $token');
        await _sendTokenToServer(token);
      }

      // Listen for token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        print('FCM Token refreshed: $newToken');
        _sendTokenToServer(newToken);
      });
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      final jwtToken = _userData.getToken();
      if (jwtToken == null) {
        print('No JWT token found, cannot register device token');
        return;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/register-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'deviceToken': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('Device token registered successfully: ${responseData['message']}');
      } else {
        print('Failed to register device token: ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('Error sending token to server: $e');
    }
  }

  // Method to manually register token (call this after user login)
  Future<void> registerDeviceTokenAfterLogin() async {
    if (_userData.isLoggedIn()) {
      String? token = await _fcm.getToken();
      if (token != null) {
        await _sendTokenToServer(token);
      }
    }
  }

  // Get current FCM token
  Future<String?> getCurrentToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      print('Error getting current token: $e');
      return null;
    }
  }
}