import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Animation/bouncing_dots.dart';
import '../model/home/product_model.dart';
import '../providers/cart_provider.dart';
import '../providers/notification_provider.dart';
import '../services/stock_service.dart';
import 'variant/variant_selection_sheet.dart';

class ProductAddButton extends StatefulWidget {
  final Product product;
  final bool isVariantRow;

  const ProductAddButton({
    super.key,
    required this.product,
    this.isVariantRow = false,
  });

  @override
  State<ProductAddButton> createState() => _ProductAddButtonState();
}

class _ProductAddButtonState extends State<ProductAddButton> {
  bool _isProcessing = false;
  StockStatus? _stockStatus;
  bool _isLoadingStock = true;

  @override
  void initState() {
    super.initState();
    _loadStockStatus();
  }

  Future<void> _loadStockStatus() async {
    try {
      final stockStatus = await StockService.getStockStatus(widget.product.id);
      if (mounted) {
        setState(() {
          _stockStatus = stockStatus;
          _isLoadingStock = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stockStatus = StockStatus(
            isAvailable: true,
            currentStock: widget.product.stock,
            message: 'In Stock',
            statusType: widget.product.stock > 0
                ? StockStatusType.inStock
                : StockStatusType.outOfStock,
          );
          _isLoadingStock = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _handleAddClick(int currentQuantity) {
    if (!widget.isVariantRow &&
        widget.product.variants != null &&
        widget.product.variants!.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => VariantSelectionSheet(
          mainProduct: widget.product,
          variants: widget.product.variants!,
        ),
      );
    } else {
      _updateCartQuantity(currentQuantity + 1);
    }
  }

  Future<void> _updateCartQuantity(int newQuantity) async {
    if (_isProcessing) return;

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final int oldQuantity = cartProvider.getItemQuantity(widget.product.id);

    if (newQuantity > 0 && _stockStatus != null) {
      if (!_stockStatus!.isAvailable ||
          newQuantity > _stockStatus!.currentStock) {
        _showSnackBar(
          'Only ${_stockStatus!.currentStock} items available in stock',
          backgroundColor: Colors.orange,
        );
        return;
      }
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await cartProvider.updateItemQuantity(
        itemId: widget.product.id,
        newQuantity: newQuantity,
      );

      if (result != null && result['error'] != null) {
        _showSnackBar(result['error'] as String, backgroundColor: Colors.red);
      } else {
        if (oldQuantity == 0 && newQuantity == 1) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          _showSnackBar(
            'Item added to cart!',
            backgroundColor: Colors.green,
          );
        }
      }
    } catch (e) {
      _showSnackBar('Failed to update cart', backgroundColor: Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<CartProvider, NotificationProvider>(
      builder: (context, cartProvider, notificationProvider, child) {
        final currentQuantity = cartProvider.getItemQuantity(widget.product.id);
        final isOutOfStock =
            _stockStatus?.statusType == StockStatusType.outOfStock;

        Widget buttonWidget;

        if (isOutOfStock) {
          final isAlreadyRequested =
          notificationProvider.isNotificationRequested(widget.product.id);
          buttonWidget = isAlreadyRequested
              ? OutlinedButton.icon(
            key: const ValueKey('notified_button'),
            onPressed: null,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: BorderSide(color: Colors.blue.shade100),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.check, color: Colors.blue, size: 16),
            label: const Text('NOTIFIED',
                style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          )
              : OutlinedButton.icon(
            key: const ValueKey('notify_button'),
            onPressed: () {
              Provider.of<NotificationProvider>(context, listen: false)
                  .requestNotification(widget.product.id);
              _showSnackBar(
                  'We will notify you when this is back in stock!',
                  backgroundColor: Colors.blue);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: const BorderSide(color: Colors.blue, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.notifications_active_outlined,
                color: Colors.blue, size: 16),
            label: const Text('NOTIFY',
                style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          );
        } else if (currentQuantity > 0) {
          buttonWidget = Container(
            key: ValueKey('quantity_stepper_$currentQuantity'),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _isProcessing ? Colors.grey.shade300 : Colors.green,
                    width: 1.5)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _isProcessing
                        ? null
                        : () => _updateCartQuantity(currentQuantity - 1),
                    child: Icon(Icons.remove,
                        size: 20, // Increased size
                        color: _isProcessing ? Colors.grey : Colors.green),
                  ),
                ),
                Text('$currentQuantity',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)), // Increased size
                Expanded(
                  child: InkWell(
                    onTap: _isProcessing
                        ? null
                        : () => _updateCartQuantity(currentQuantity + 1),
                    child: Icon(Icons.add,
                        size: 20, // Increased size
                        color: _isProcessing ? Colors.grey : Colors.green),
                  ),
                ),
              ],
            ),
          );
        } else {
          // ✅ RESTORED: Standard Size "ADD" button
          buttonWidget = OutlinedButton(
            key: const ValueKey('add_button'),
            onPressed: _isLoadingStock || _isProcessing
                ? null
                : () => _handleAddClick(currentQuantity),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: BorderSide(
                  color: _isLoadingStock || _isProcessing
                      ? Colors.grey.shade300
                      : Colors.green,
                  width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: _isLoadingStock || _isProcessing
                ? const BouncingDotsIndicator(color: Colors.green, size: 4)
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('ADD',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)), // Increased size
                if (!widget.isVariantRow &&
                    widget.product.variants != null &&
                    widget.product.variants!.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.keyboard_arrow_down, size: 16),
                  )
              ],
            ),
          );
        }

        // ✅ RESTORED: Standard height 36
        return SizedBox(
          width: double.infinity,
          height: 36,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              );
            },
            child: buttonWidget,
          ),
        );
      },
    );
  }
}