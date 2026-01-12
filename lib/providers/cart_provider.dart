// lib/providers/cart_provider.dart
// Enhanced version with detailed API logging

import 'package:flutter/material.dart';
import '../services/Cart/cart_service.dart';

class CartProvider extends ChangeNotifier {
  CartProvider() {
    // Kick off a non-blocking load so UI shows cached data quickly
    loadCart();
  }
  Map<String, int> _cartItems = {};
  bool _isLoading = false;
  String? _lastError;
  DateTime? _lastUpdated;

  // Getters
  Map<String, int> get cartItems => Map.unmodifiable(_cartItems);
  final Map<String, String> _itemIdToCartItemId = {};
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  int get totalItemsInCart =>
      _cartItems.values.fold(0, (sum, quantity) => sum + quantity);

  // Get quantity for a specific item
  int getItemQuantity(String itemId) {
    return _cartItems[itemId] ?? 0;
  }

  // Check if item is in cart
  bool isItemInCart(String itemId) {
    return _cartItems.containsKey(itemId) && _cartItems[itemId]! > 0;
  }

  // Load cart from service
  Future<void> loadCart() async {
    _lastError = null;

    // Try to load cached cart first so UI can show immediately.
    try {
      final cached = await CartService.readCartFromCache();
      if (cached != null) {
        final items = cached['items'] as List<dynamic>? ?? [];

        _cartItems.clear();
        for (final item in items) {
          final itemId = item['itemId']?.toString();
          final quantity =
              (item['quantity'] is num)
                  ? (item['quantity'] as num).toInt()
                  : (item['quantity'] as int? ?? 0);
          if (itemId != null && quantity > 0) {
            _cartItems[itemId] = quantity;
          }
        }

        _lastUpdated = DateTime.now();
        // Notify listeners immediately with cached data (no spinner)
        notifyListeners();

        // Refresh in background, don't block UI
        _refreshCartFromNetwork();
        return;
      }
    } catch (e) {
      print('⚠️ Failed to read cached cart: $e');
      // fallback to network fetch below
    }

    // No cache available - perform network fetch and show loading
    _isLoading = true;
    notifyListeners();

    try {
      final result = await CartService.getCart();

      if (result != null) {
        if (result['error'] != null) {
          _lastError = result['error'];
          print('❌ Load cart error: ${result['error']}');
        } else if (result['success'] == true && result['data'] != null) {
          final cartData = result['data'];
          final items = cartData['items'] as List<dynamic>? ?? [];

          // Build the cart items map
          _cartItems.clear();
          for (final item in items) {
            final itemId = item['itemId']?.toString();
            final quantity =
                (item['quantity'] is num)
                    ? (item['quantity'] as num).toInt()
                    : (item['quantity'] as int? ?? 0);
            if (itemId != null && quantity > 0) {
              _cartItems[itemId] = quantity;
            }
          }

          _lastUpdated = DateTime.now();
          print('✅ Loaded cart: ${_cartItems.length} items');

          // Cache result for faster next loads
          try {
            await CartService.saveCartToCache(
              result['data'] as Map<String, dynamic>,
            );
          } catch (_) {}
        }
      }
    } catch (e) {
      _lastError = 'Failed to load cart: $e';
      print('❌ Load cart exception: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Background refresh - fetch fresh cart and update cache & UI
  Future<void> _refreshCartFromNetwork() async {
    try {
      final result = await CartService.getCart();
      if (result != null &&
          result['success'] == true &&
          result['data'] != null) {
        final cartData = result['data'];
        final items = cartData['items'] as List<dynamic>? ?? [];

        _cartItems.clear();
        for (final item in items) {
          final itemId = item['itemId']?.toString();
          final quantity =
              (item['quantity'] is num)
                  ? (item['quantity'] as num).toInt()
                  : (item['quantity'] as int? ?? 0);
          if (itemId != null && quantity > 0) {
            _cartItems[itemId] = quantity;
          }
        }

        _lastUpdated = DateTime.now();

        // Update cache
        try {
          await CartService.saveCartToCache(cartData as Map<String, dynamic>);
        } catch (e) {
          print('⚠️ Failed to cache cart after refresh: $e');
        }

        notifyListeners();
      }
    } catch (e) {
      print('⚠️ Background cart refresh failed: $e');
    }
  }

  // Add item to cart (for new items - uses POST)
  Future<Map<String, dynamic>?> addItemToCart({
    required String itemId,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      return {'error': 'Invalid quantity'};
    }

    print('📤 ADD: itemId=$itemId, quantity=$quantity');

    // Optimistically update UI
    final previousQuantity = _cartItems[itemId] ?? 0;
    _cartItems[itemId] = quantity;
    notifyListeners();

    _lastError = null;

    try {
      final result = await CartService.addSingleItemToCart(
        itemId: itemId,
        quantity: quantity,
      );

      print('📥 ADD Result: $result');

      if (result != null && result['error'] != null) {
        // Revert on error
        if (previousQuantity > 0) {
          _cartItems[itemId] = previousQuantity;
        } else {
          _cartItems.remove(itemId);
        }
        _lastError = result['error'];
        notifyListeners();
      } else {
        _lastUpdated = DateTime.now();
      }

      return result;
    } catch (e) {
      print('❌ ADD Exception: $e');
      // Revert on error
      if (previousQuantity > 0) {
        _cartItems[itemId] = previousQuantity;
      } else {
        _cartItems.remove(itemId);
      }
      _lastError = 'Failed to add item: $e';
      notifyListeners();
      return {'error': _lastError};
    }
  }

  // Update item quantity - USES DIFFERENT LOGIC BASED ON CURRENT STATE
  Future<Map<String, dynamic>?> updateItemQuantity({
    required String itemId,
    required int newQuantity,
  }) async {
    final currentQuantity = _cartItems[itemId] ?? 0;

    if (newQuantity <= 0) {
      return await removeItemFromCart(itemId: itemId);
    }

    if (currentQuantity == 0) {
      return await addItemToCart(itemId: itemId, quantity: newQuantity);
    }

    // 1. Optimistic Update (Immediate UI feedback)
    final previousQuantity = _cartItems[itemId];
    _cartItems[itemId] = newQuantity;
    notifyListeners(); // Header updates here instantly

    _lastError = null;

    try {
      // 2. Network Call
      final result = await CartService.updateItemQuantity(
        cartItemId: _itemIdToCartItemId[itemId] ?? '', // Use actual ID if available
        itemId: itemId,
        quantity: newQuantity,
      ).timeout(const Duration(seconds: 10)); // Prevent long iOS hangs

      if (result != null && result['error'] != null) {
        // 3. Revert on API Failure
        _cartItems[itemId] = previousQuantity ?? 0;
        _lastError = result['error'];
        notifyListeners();
      } else {
        // 4. FIX: Notify on success to sync the Header
        _lastUpdated = DateTime.now();
        notifyListeners();
      }

      return result;
    } catch (e) {
      // 3. Revert on Network Exception
      _cartItems[itemId] = previousQuantity ?? 0;
      _lastError = 'Connection issue. Please try again.';
      notifyListeners();
      return {'error': _lastError};
    }
  }

  // Remove item from cart
  Future<Map<String, dynamic>?> removeItemFromCart({
    required String itemId,
  }) async {
    print('📤 REMOVE: itemId=$itemId');

    // Optimistically update UI
    final previousQuantity = _cartItems[itemId];
    _cartItems.remove(itemId);
    notifyListeners();

    _lastError = null;

    try {
      final result = await CartService.removeItemFromCart(
        cartItemId: '',
        itemId: itemId,
      );

      print('📥 REMOVE Result: $result');

      if (result != null && result['error'] != null) {
        print('❌ REMOVE Error: ${result['error']}');
        // Revert on error
        if (previousQuantity != null) {
          _cartItems[itemId] = previousQuantity;
        }
        _lastError = result['error'];
        notifyListeners();
      } else {
        print('✅ REMOVE Success');
        _lastUpdated = DateTime.now();
      }

      return result;
    } catch (e) {
      print('❌ REMOVE Exception: $e');
      // Revert on error
      if (previousQuantity != null) {
        _cartItems[itemId] = previousQuantity;
      }
      _lastError = 'Failed to remove item: $e';
      notifyListeners();
      return {'error': _lastError};
    }
  }

  // Clear cart
  void clearCart() {
    _cartItems.clear();
    _lastError = null;
    _lastUpdated = null;
    notifyListeners();
  }

  // Check if authenticated
  bool isAuthenticated() {
    return CartService.isAuthenticated();
  }

  // Debug method
  void debugAuth() {
    CartService.debugAuth();
  }

  // Refresh cart data
  Future<void> refreshCart() async {
    await loadCart();
  }

  // Set cart items directly from a pre-built map (no network call).
  // Useful for syncing UI components that already have the cart payload
  // (for example, after fetching cart in a screen) without issuing
  // another network request.
  void setCartItems(Map<String, int> items) {
    _cartItems = Map<String, int>.from(items);
    _lastUpdated = DateTime.now();
    notifyListeners();
  }
}
