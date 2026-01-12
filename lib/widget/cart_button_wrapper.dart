/*import 'package:flutter/material.dart';

import '../buttons/global_cart_button.dart' show GlobalCartButton;
import '../services/Cart/cart_notifier.dart';

class CartButtonWrapper extends StatelessWidget {
  final Widget child;
  final CartNotifier cartNotifier;

  const CartButtonWrapper({
    super.key,
    required this.child,
    required this.cartNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ListenableBuilder(
            listenable: cartNotifier,
            builder: (context, _) {
              return GlobalCartButton(
                isVisible: cartNotifier.isVisible,
                itemCount: cartNotifier.itemCount,
                totalAmount: cartNotifier.totalAmount,
                onPressed: () {
                  Navigator.pushNamed(context, '/cart');
                },
              );
            },
          ),
        ),
      ],
    );
  }
}*/