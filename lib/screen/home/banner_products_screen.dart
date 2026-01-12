import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/cart_provider.dart';
import '../cart_screen.dart';

import '../../model/home/banner_model.dart' as banner_model;
import '../../model/home/product_model.dart';
import '../../services/home/api_service.dart';
import '../../widget/product_add_button.dart';
import '../home/product_detail_screen.dart';

class BannerProductsScreen extends StatelessWidget {
  final banner_model.Banner banner;
  final List<Product> products;
  final banner_model.BannerMedia? mediaItem;

  const BannerProductsScreen({
    super.key,
    required this.banner,
    required this.products,
    this.mediaItem,
  });

  @override
  Widget build(BuildContext context) {
    // Determine if we are on a wide screen (Web/Desktop)
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWeb = screenWidth > 800;

    String bannerImageUrl = '';
    if (mediaItem != null) {
      bannerImageUrl = mediaItem!.getFullUrl();
    } else if (banner.imageUrls.isNotEmpty) {
      bannerImageUrl = banner.imageUrls.first;
    }

    const backgroundColor = Color(0xFFf8f9fa);
    const textColor = Color(0xFF343a40);
    const accentRed = Color(0xFFe63946);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0.5,
        centerTitle: isWeb, // Center title on web for a cleaner look
        title: isWeb ? const Text("Offers & Products", style: TextStyle(color: textColor)) : null,
        shadowColor: Colors.grey.withOpacity(0.2),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.dark,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              return Padding(
                padding: EdgeInsets.only(right: isWeb ? 40.0 : 8.0), // Extra padding on web
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart, color: textColor),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CartScreen()),
                        );
                      },
                    ),
                    if (cartProvider.totalItemsInCart > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: accentRed,
                            shape: BoxShape.circle,
                            border: Border.all(color: backgroundColor, width: 1.5),
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '${cartProvider.totalItemsInCart}',
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          // Limits the width of the content so it doesn't stretch infinitely on web
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: isWeb ? 40.0 : 16.0,
                  vertical: 24.0
              ),
              child: Column(
                children: [
                  if (bannerImageUrl.isNotEmpty)
                    AspectRatio(
                      // Banner is more "letterbox" style on web
                      aspectRatio: isWeb ? 4 / 1 : 2.2 / 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16.0),
                        child: CachedNetworkImage(
                          imageUrl: bannerImageUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.grey[200]),
                          errorWidget: (context, url, error) => const Icon(Icons.image, size: 48, color: Colors.grey),
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: products.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      // Dynamically change column count based on width
                      crossAxisCount: screenWidth > 1100 ? 5 : (screenWidth > 700 ? 3 : 2),
                      mainAxisSpacing: 20.0,
                      crossAxisSpacing: 20.0,
                      childAspectRatio: 0.72, // Slightly taller for web readability
                    ),
                    itemBuilder: (context, index) {
                      return _ProductCard(
                        product: products[index],
                        banner: banner,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatefulWidget {
  final Product product;
  final banner_model.Banner banner;

  const _ProductCard({required this.product, required this.banner});

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool isHovered = false;

  void _navigateToProductDetail(BuildContext context) {
    String? categoryId;
    if (widget.banner.media != null && widget.banner.media!.isNotEmpty) {
      categoryId = widget.banner.media!.first.category?.id;
    }
    categoryId ??= '687cbb1a5f081ded01079b1c';
    const subcategoryId = '68b82c78ed01f968c63ac335';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(
          product: widget.product,
          categoryId: categoryId,
          subcategoryId: subcategoryId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const cardLight = Colors.white;
    const textLight = Color(0xFF212529);
    const accentRed = Color(0xFFd00000);

    final hasDiscount = widget.product.mrp > widget.product.salesPrice;
    final discountPercent = hasDiscount
        ? (((widget.product.mrp - widget.product.salesPrice) / widget.product.mrp) * 100).round()
        : 0;

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _navigateToProductDetail(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: isHovered ? (Matrix4.identity()..translate(0, -5, 0)) : Matrix4.identity(),
          decoration: BoxDecoration(
            color: cardLight,
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isHovered ? 0.12 : 0.05),
                spreadRadius: 1,
                blurRadius: isHovered ? 15 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Stack(
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: CachedNetworkImage(
                          imageUrl: ApiService.getImageUrl(
                              widget.product.itemImages.isNotEmpty ? widget.product.itemImages.first : '',
                              'item'),
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
                          errorWidget: (context, url, error) => const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                        ),
                      ),
                    ),
                    if (hasDiscount)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: accentRed, borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            '$discountPercent% OFF',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.itemName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textLight),
                        maxLines: 2, // Increased for web readability
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hasDiscount)
                                Text(
                                  '₹${widget.product.mrp.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey,
                                  ),
                                ),
                              Text(
                                '₹${widget.product.salesPrice.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textLight),
                              ),
                            ],
                          ),
                          ProductAddButton(product: widget.product),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}