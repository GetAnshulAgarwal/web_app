import 'package:flutter/material.dart';
import '../../model/cart/cart_item_model.dart';
import '../../model/home/product_model.dart';
import '../../screen/home/product_detail_screen.dart';
import '../../services/Cart/cart_service.dart';
import '../../services/home/api_service.dart';
import '../../services/stock_service.dart';

class PopularProductsWidget extends StatefulWidget {
  final List<CartItem> cartItems;
  final VoidCallback? onCartUpdated;

  const PopularProductsWidget({
    Key? key,
    this.cartItems = const [],
    this.onCartUpdated,
  }) : super(key: key);

  @override
  State<PopularProductsWidget> createState() => _PopularProductsWidgetState();
}

class _PopularProductsWidgetState extends State<PopularProductsWidget> {
  List<Product> popularProducts = [];
  bool isLoadingPopularProducts = true;

  // Track stock status for each product
  Map<String, StockStatus> productStockStatus = {};
  Map<String, bool> productStockLoading = {};

  @override
  void initState() {
    super.initState();
    loadPopularProducts();
  }

  Future<void> loadPopularProducts() async {
    if (!mounted) return;

    setState(() {
      isLoadingPopularProducts = true;
    });

    try {
      final products = await ApiService.getPopularProducts(limit: 8);

      if (mounted) {
        setState(() {
          popularProducts =
              products
                  .where(
                    (product) =>
                        !widget.cartItems.any(
                          (cartItem) => cartItem.itemId == product.id,
                        ),
                  )
                  .toList();
          isLoadingPopularProducts = false;
        });

        // Load stock status for all products
        await _loadStockStatusForAllProducts();
      }
    } catch (e) {
      print('❌ Error loading popular products: $e');
      if (mounted) {
        setState(() {
          popularProducts = [];
          isLoadingPopularProducts = false;
        });
      }
    }
  }

  // UPDATED: Load stock and filter out out-of-stock products
  Future<void> _loadStockStatusForAllProducts() async {
    List<String> productsToRemove = [];

    for (var product in popularProducts) {
      await _loadStockStatus(product.id, product.stock);

      // Check if product is out of stock after loading
      final stockStatus = productStockStatus[product.id];
      if (stockStatus != null &&
          stockStatus.statusType == StockStatusType.outOfStock) {
        productsToRemove.add(product.id);
        print('🚫 Removing out-of-stock product: ${product.itemName}');
      }
    }

    // Remove out-of-stock products from the list
    if (productsToRemove.isNotEmpty && mounted) {
      setState(() {
        popularProducts.removeWhere(
          (product) => productsToRemove.contains(product.id),
        );
      });
      print('✅ Filtered out ${productsToRemove.length} out-of-stock products');
    }
  }

  Future<void> _loadStockStatus(String productId, int fallbackStock) async {
    if (!mounted) return;

    setState(() {
      productStockLoading[productId] = true;
    });

    try {
      final stockStatus = await StockService.getStockStatus(productId);
      if (mounted) {
        setState(() {
          productStockStatus[productId] = stockStatus;
          productStockLoading[productId] = false;
        });
        print('✅ Stock loaded for $productId: ${stockStatus.currentStock}');
      }
    } catch (e) {
      print('⚠️ Error loading stock for $productId: $e');
      if (mounted) {
        setState(() {
          productStockStatus[productId] = StockStatus(
            isAvailable: true,
            currentStock: fallbackStock,
            message: 'In Stock',
            statusType:
                fallbackStock > 0
                    ? StockStatusType.inStock
                    : StockStatusType.outOfStock,
          );
          productStockLoading[productId] = false;
        });
      }
    }
  }

  Future<void> _fetchReplacementProduct() async {
    try {
      final products = await ApiService.getPopularProducts(
        limit: popularProducts.length + 5,
      );

      if (mounted) {
        final newProducts =
            products
                .where(
                  (product) =>
                      !popularProducts.any((p) => p.id == product.id) &&
                      !widget.cartItems.any(
                        (cartItem) => cartItem.itemId == product.id,
                      ),
                )
                .toList();

        if (newProducts.isNotEmpty) {
          for (var newProduct in newProducts) {
            // Load stock for new product
            await _loadStockStatus(newProduct.id, newProduct.stock);

            // Only add if not out of stock
            final stockStatus = productStockStatus[newProduct.id];
            if (stockStatus == null ||
                stockStatus.statusType != StockStatusType.outOfStock) {
              if (mounted) {
                setState(() {
                  popularProducts.add(newProduct);
                });
              }
              break; // Only add one replacement
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error fetching replacement product: $e');
    }
  }

  bool _isProductInCart(String productId) {
    return widget.cartItems.any((item) => item.itemId == productId);
  }

  int _getProductQuantityInCart(String productId) {
    try {
      final cartItem = widget.cartItems.firstWhere(
        (item) => item.itemId == productId,
      );
      return cartItem.quantity;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _addToCart(Product product) async {
    print('🛒 Attempting to add product to cart: ${product.id}');

    final stockStatus = productStockStatus[product.id];

    if (stockStatus != null) {
      if (!stockStatus.isAvailable || stockStatus.currentStock < 1) {
        _showSnackBar(
          '${product.itemName} is currently out of stock',
          backgroundColor: Colors.red,
        );
        return;
      }
    }

    try {
      final response = await CartService.addSingleItemToCart(
        itemId: product.id,
        quantity: 1,
      );

      if (response != null && response['error'] == null) {
        print('✅ Item added to cart successfully');

        if (mounted) {
          setState(() {
            popularProducts.removeWhere((p) => p.id == product.id);
            productStockStatus.remove(product.id);
            productStockLoading.remove(product.id);
          });
        }

        _fetchReplacementProduct();

        if (widget.onCartUpdated != null) {
          widget.onCartUpdated!();
        }

        if (mounted) {
          _showSnackBar(
            '${product.itemName} added to cart',
            backgroundColor: Colors.green.shade600,
          );
        }
      } else {
        if (mounted) {
          String errorMessage =
              response?['error']?.toString() ?? 'Failed to add item to cart';
          _showSnackBar(errorMessage, backgroundColor: Colors.red);
        }
      }
    } catch (e) {
      print('❌ Exception while adding to cart: $e');
      if (mounted) {
        _showSnackBar(
          'Error adding item: ${e.toString()}',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _updatePopularProductQuantity(
    Product product,
    int newQuantity,
  ) async {
    print('🔄 Updating quantity for ${product.id} to $newQuantity');

    try {
      final cartItem = widget.cartItems.firstWhere(
        (item) => item.itemId == product.id,
      );

      if (newQuantity > 0) {
        final stockStatus = productStockStatus[product.id];

        if (stockStatus != null) {
          if (!stockStatus.isAvailable ||
              newQuantity > stockStatus.currentStock) {
            _showSnackBar(
              'Only ${stockStatus.currentStock} items available in stock',
              backgroundColor: Colors.orange,
            );
            return;
          }
        }
      }

      if (newQuantity <= 0) {
        print('🗑️ Removing item from cart');
        final response = await CartService.removeItemFromCart(
          cartItemId: cartItem.id,
          itemId: product.id,
        );

        if (response != null && response['error'] == null) {
          if (mounted) {
            setState(() {
              if (!popularProducts.any((p) => p.id == product.id)) {
                popularProducts.insert(0, product);
              }
            });
            // Reload stock for re-added product
            await _loadStockStatus(product.id, product.stock);

            // Remove if out of stock
            final stockStatus = productStockStatus[product.id];
            if (stockStatus != null &&
                stockStatus.statusType == StockStatusType.outOfStock) {
              setState(() {
                popularProducts.removeWhere((p) => p.id == product.id);
              });
            }
          }

          if (widget.onCartUpdated != null) {
            widget.onCartUpdated!();
          }
        } else {
          _showSnackBar(
            response?['error']?.toString() ?? 'Failed to remove item',
            backgroundColor: Colors.red,
          );
        }
      } else {
        print('📝 Updating quantity in cart');
        final response = await CartService.updateItemQuantity(
          cartItemId: cartItem.id,
          itemId: product.id,
          quantity: newQuantity,
        );

        if (response != null && response['error'] == null) {
          if (widget.onCartUpdated != null) {
            widget.onCartUpdated!();
          }
        } else {
          _showSnackBar(
            response?['error']?.toString() ?? 'Failed to update quantity',
            backgroundColor: Colors.red,
          );
        }
      }
    } catch (e) {
      print('❌ Error updating quantity: $e');
      _showSnackBar(
        'Error updating quantity: ${e.toString()}',
        backgroundColor: Colors.red,
      );
    }
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              backgroundColor == Colors.red
                  ? Icons.error
                  : backgroundColor == Colors.orange
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: backgroundColor ?? Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildPopularProductCard(Product product) {
    final isInCart = _isProductInCart(product.id);
    final quantityInCart = _getProductQuantityInCart(product.id);

    final stockStatus = productStockStatus[product.id];
    final isLoadingStock = productStockLoading[product.id] ?? true;
    final isOutOfStock = stockStatus?.statusType == StockStatusType.outOfStock;

    if (isOutOfStock) {
      return const SizedBox.shrink();
    }

    double discountPercentage = 0;
    if (product.mrp > 0 && product.salesPrice > 0 && product.mrp > product.salesPrice) {
      discountPercentage = ((product.mrp - product.salesPrice) / product.mrp) * 100;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        // INCREASED: Card width from 0.40 to 0.45 (45% of screen width)
        final cardWidth = (screenWidth * 0.45).clamp(180.0, 220.0);
        // INCREASED: Image height ratio
        final imageHeight = (cardWidth * 0.85).clamp(120.0, 150.0);

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailScreen(product: product),
              ),
            );
          },
          child: Container(
            width: cardWidth,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Product Image Container - LARGER
                Stack(
                  children: [
                    Container(
                      height: imageHeight,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: Colors.grey[50],
                          child: product.itemImages.isNotEmpty
                              ? Image.network(
                            ApiService.getImageUrl(product.itemImages.first, 'item'),
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.green,
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  size: imageHeight * 0.25,
                                  color: Colors.grey[400],
                                ),
                              );
                            },
                          )
                              : Center(
                            child: Icon(
                              Icons.shopping_basket_outlined,
                              size: imageHeight * 0.25,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Add/Quantity Button - LARGER
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: !isInCart
                          ? GestureDetector(
                        onTap: isLoadingStock ? null : () => _addToCart(product),
                        child: Container(
                          width: cardWidth * 0.32,
                          height: cardWidth * 0.24,
                          decoration: BoxDecoration(
                            color: isLoadingStock ? Colors.grey : Colors.green,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: isLoadingStock
                                ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : Icon(
                              Icons.add,
                              color: Colors.white,
                              size: (cardWidth * 0.12).clamp(16.0, 20.0),
                            ),
                          ),
                        ),
                      )
                          : Container(
                        width: cardWidth * 0.50,
                        height: cardWidth * 0.20,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _updatePopularProductQuantity(product, quantityInCart - 1),
                                child: Container(
                                  height: double.infinity,
                                  decoration: const BoxDecoration(
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(8),
                                      bottomLeft: Radius.circular(8),
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.remove,
                                      color: Colors.white,
                                      size: (cardWidth * 0.09).clamp(14.0, 18.0),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: cardWidth * 0.18,
                              height: double.infinity,
                              decoration: const BoxDecoration(
                                border: Border.symmetric(
                                  vertical: BorderSide(
                                    color: Colors.white,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$quantityInCart',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: (cardWidth * 0.09).clamp(13.0, 16.0),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: (stockStatus != null && quantityInCart >= stockStatus.currentStock)
                                    ? null
                                    : () => _updatePopularProductQuantity(product, quantityInCart + 1),
                                child: Container(
                                  height: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(8),
                                      bottomRight: Radius.circular(8),
                                    ),
                                    color: (stockStatus != null && quantityInCart >= stockStatus.currentStock)
                                        ? Colors.grey.withOpacity(0.3)
                                        : Colors.transparent,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.add,
                                      color: Colors.white,
                                      size: (cardWidth * 0.09).clamp(14.0, 18.0),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: cardWidth * 0.06),

                // Unit and Brand Row - LARGER FONT
                if (product.unit.isNotEmpty || product.brand.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: cardWidth * 0.025),
                    child: Row(
                      children: [
                        if (product.unit.isNotEmpty)
                          Flexible(
                            child: Text(
                              product.unit,
                              style: TextStyle(
                                fontSize: (cardWidth * 0.07).clamp(10.0, 12.0),
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        if (product.unit.isNotEmpty && product.brand.isNotEmpty)
                          SizedBox(width: cardWidth * 0.02),
                        if (product.brand.isNotEmpty)
                          Flexible(
                            child: Text(
                              product.brand,
                              style: TextStyle(
                                fontSize: (cardWidth * 0.07).clamp(10.0, 12.0),
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              maxLines: 1,
                            ),
                          ),
                      ],
                    ),
                  ),

                // Product Name - LARGER FONT
                Padding(
                  padding: EdgeInsets.only(bottom: cardWidth * 0.025),
                  child: Text(
                    product.itemName,
                    style: TextStyle(
                      fontSize: (cardWidth * 0.09).clamp(13.0, 16.0),
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Stock status indicator - LARGER
                if (stockStatus != null &&
                    stockStatus.statusType != StockStatusType.inStock &&
                    !isLoadingStock)
                  Padding(
                    padding: EdgeInsets.only(bottom: cardWidth * 0.025),
                    child: Row(
                      children: [
                        Icon(
                          stockStatus.statusType == StockStatusType.outOfStock
                              ? Icons.cancel
                              : Icons.warning_amber_rounded,
                          size: (cardWidth * 0.07).clamp(12.0, 14.0),
                          color: stockStatus.statusType == StockStatusType.outOfStock
                              ? Colors.red
                              : Colors.orange,
                        ),
                        SizedBox(width: cardWidth * 0.015),
                        Flexible(
                          child: Text(
                            stockStatus.message,
                            style: TextStyle(
                              fontSize: (cardWidth * 0.06).clamp(9.0, 11.0),
                              color: stockStatus.statusType == StockStatusType.outOfStock
                                  ? Colors.red
                                  : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Discount Badge - LARGER
                if (discountPercentage > 0) ...[
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: cardWidth * 0.03,
                      vertical: cardWidth * 0.015,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${discountPercentage.toInt()}% OFF',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: (cardWidth * 0.06).clamp(9.0, 11.0),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: cardWidth * 0.025),
                ],

                // Price Section - LARGER FONT
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '₹${product.salesPrice.toInt()}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: (cardWidth * 0.105).clamp(15.0, 18.0),
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPopularProductsLoading() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        // INCREASED: Card width and height
        final cardWidth = (screenWidth * 0.40).clamp(160.0, 200.0);
        final availableHeight = (screenHeight * 0.45 - 60).clamp(250.0, 400.0);

        return SizedBox(
          height: availableHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            itemBuilder: (context, index) {
              return Container(
                width: cardWidth,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image placeholder - LARGER
                    Container(
                      height: cardWidth * 0.85,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    SizedBox(height: cardWidth * 0.06),
                    Container(
                      height: cardWidth * 0.09,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(height: cardWidth * 0.04),
                    Container(
                      height: cardWidth * 0.28,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(height: cardWidth * 0.05),
                    Container(
                      height: cardWidth * 0.24,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPopularProductsEmpty() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = MediaQuery.of(context).size.height;
        // INCREASED: Empty state height
        final emptyHeight = (screenHeight * 0.20).clamp(120.0, 160.0);

        return SizedBox(
          height: emptyHeight,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.trending_down,
                  size: emptyHeight * 0.35,
                  color: Colors.grey.shade400,
                ),
                SizedBox(height: emptyHeight * 0.12),
                Text(
                  'No popular products available',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: emptyHeight * 0.14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = MediaQuery.of(context).size.height;
        // INCREASED: from 0.35 (35%) to 0.45 (45%) of screen height
        final availableHeight = screenHeight * 0.45;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.trending_up, size: 20, color: Colors.brown.shade800),
                  const SizedBox(width: 8),
                  const Text(
                    'Popular Products',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (isLoadingPopularProducts)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.brown.shade800,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Content with INCREASED dynamic height
              if (isLoadingPopularProducts)
                _buildPopularProductsLoading()
              else if (popularProducts.isEmpty)
                _buildPopularProductsEmpty()
              else
                SizedBox(
                  // INCREASED: Adjusted constraints for larger display
                  height: (availableHeight - 60).clamp(250.0, 400.0),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: popularProducts.length,
                    itemBuilder: (context, index) {
                      return _buildPopularProductCard(popularProducts[index]);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
