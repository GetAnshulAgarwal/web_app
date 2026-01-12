// File: lib/providers/cart_notifier.dart

import 'package:flutter/material.dart';

class CartNotifier extends ChangeNotifier {
  int _itemCount = 0;
  double _totalAmount = 0.0;
  bool _isVisible = false;

  int get itemCount => _itemCount;
  double get totalAmount => _totalAmount;
  bool get isVisible => _isVisible;

  void updateCart(int count, double amount) {
    _itemCount = count;
    _totalAmount = amount;
    _isVisible = count > 0;
    notifyListeners();
  }

  void hideButton() {
    _isVisible = false;
    notifyListeners();
  }

  void showButton() {
    if (_itemCount > 0) {
      _isVisible = true;
      notifyListeners();
    }
  }

  void clearCart() {
    _itemCount = 0;
    _totalAmount = 0.0;
    _isVisible = false;
    notifyListeners();
  }
}