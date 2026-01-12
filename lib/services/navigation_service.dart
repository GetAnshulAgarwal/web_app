import 'package:flutter/material.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  // This key MUST be assigned to your MaterialApp's navigatorKey property
  static final GlobalKey<NavigatorState> navigatorKey =
  GlobalKey<NavigatorState>();

  // This callback will be set by your main navigation screen
  static Function(int)? onTabChange;

  /// NEW METHOD: Changes tab to Home and pops all routes on top.
  static void goBackToHomeScreen() {
    // 1. Tell the main screen to switch its index to 0 (Home)
    onTabChange?.call(0);

    // 2. Use the global navigator key to pop until the first route
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  static void goToSearchScreen() {
    // Replace 'SearchScreen' with your actual search screen route name
    Navigator.pushNamed(navigatorKey.currentContext!, '/search');
  }

  static void goToCartScreen() {
    // 1. Tell the main screen to switch its index to 0 (Home)
    onTabChange?.call(3);

    // 2. Use the global navigator key to pop until the first route
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  // You can keep these if you need to switch tabs without navigating
  static void goToHomeTab() {
    onTabChange?.call(0);
  }

  static void goToCartTab() {
    onTabChange?.call(3);
  }

  // --- NEWLY CREATED METHOD ---
  static void goToSavedAddressScreen() {
    // Make sure '/saved_addresses' matches your route name in MaterialApp
    if (navigatorKey.currentContext != null) {
      Navigator.pushNamed(navigatorKey.currentContext!, '/saved_addresses');
    }
  }
}