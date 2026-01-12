import 'package:flutter/material.dart';

import '../../../model/home/category.dart';
import '../../../model/home/product_model.dart';
import '../../../services/home/api_service.dart';
import '../../../widget/home/optimized_network.dart';
import '../../../widget/product_add_button.dart'; // ✅ 1. IMPORTING the correct button
import '../../../widget/skeleton_widgets.dart';
import '../../home_screen.dart';
import '../product_detail_screen.dart'; // ✅ IMPORTING the detail screen for navigation

class CategoryProductsSection extends StatefulWidget {
  final Category category;

  const CategoryProductsSection({
    super.key,
    required this.category,
  });

  @override
  State<CategoryProductsSection> createState() =>
      _CategoryProductsSectionState();
}

class _CategoryProductsSectionState extends State<CategoryProductsSection> {
  late Future<List<Product>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() {
    _productsFuture = ApiService.getProductsForCategory(
      widget.category.id,
      limit: 10,
    ).timeout(const Duration(seconds: 10)).catchError((e) {
      debugPrint('Error loading products for ${widget.category.name}: $e');
      return <Product>[];
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingSkeleton();
        }
        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        return _buildCategoryWithProducts(widget.category, snapshot.data!);
      },
    );
  }

  Widget _buildCategoryWithProducts(
      Category category, List<Product> products) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Because you might like these',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: products.length,
              itemBuilder: (context, index) =>
              // Pass the category down to the card for navigation context
              _buildProductCard(context, products[index], category),
              separatorBuilder: (context, index) => const SizedBox(width: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
      BuildContext context, Product product, Category category) {
    return SizedBox(
      width: 160,
      child: GestureDetector(
        // ✅ 2. WRAPPED card with GestureDetector for navigation
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(
                product: product,
                categoryId: category.id,
                subcategoryId: null, // No subcategory is available here
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  color: Colors.grey[50],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: _buildProductImage(product),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (product.unit.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                product.unit,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          const Spacer(),
                          if (product.brand.isNotEmpty)
                            Text(
                              product.brand,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.itemName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              size: 10, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text('4.2',
                              style: TextStyle(
                                  fontSize: 9, color: Colors.grey[600])),
                          const SizedBox(width: 4),
                          Text('• 12 MINS',
                              style: TextStyle(
                                  fontSize: 9, color: Colors.grey[600])),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '₹${_safeToInt(product.salesPrice)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                              ),
                              if (_safeToDouble(product.mrp) >
                                  _safeToDouble(product.salesPrice)) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '₹${_safeToInt(product.mrp)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (_safeToDouble(product.discountPercentage) >
                              0) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${_safeToInt(product.discountPercentage)}% OFF',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 32,
                        // ✅ 3. REPLACED the old button with the interactive one.
                        child: ProductAddButton(product: product),
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

  Widget _buildProductImage(Product product) {
    if (product.itemImages.isEmpty) {
      return Center(
        child:
        Icon(Icons.shopping_basket, size: 32, color: Colors.grey[400]),
      );
    }
    return OptimizedNetworkImage(
      imageUrl: product.itemImages.first,
      imageType: 'item',
      width: double.infinity,
      height: 120,
      fit: BoxFit.contain,
    );
  }

  int _safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.isNaN ? 0 : value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value.isNaN ? 0.0 : value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Widget _buildLoadingSkeleton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonWidgets.buildCardSkeleton(
                    width: 200, height: 18, margin: EdgeInsets.zero),
                const SizedBox(height: 4),
                SkeletonWidgets.buildCardSkeleton(
                    width: 150, height: 12, margin: EdgeInsets.zero),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 5,
              itemBuilder: (context, index) => _buildProductCardSkeleton(),
              separatorBuilder: (context, index) => const SizedBox(width: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCardSkeleton() {
    return SizedBox(
      width: 160,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                color: Colors.grey[50],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: SkeletonWidgets.buildCardSkeleton(
                    width: double.infinity,
                    height: 120,
                    margin: EdgeInsets.zero),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SkeletonWidgets.buildCardSkeleton(
                            width: 30, height: 12, margin: EdgeInsets.zero),
                        const Spacer(),
                        SkeletonWidgets.buildCardSkeleton(
                            width: 40, height: 12, margin: EdgeInsets.zero),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SkeletonWidgets.buildCardSkeleton(
                        width: double.infinity,
                        height: 14,
                        margin: EdgeInsets.zero),
                    const SizedBox(height: 4),
                    SkeletonWidgets.buildCardSkeleton(
                        width: 100, height: 14, margin: EdgeInsets.zero),
                    const SizedBox(height: 8),
                    SkeletonWidgets.buildCardSkeleton(
                        width: 80, height: 10, margin: EdgeInsets.zero),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SkeletonWidgets.buildCardSkeleton(
                            width: 40, height: 16, margin: EdgeInsets.zero),
                        const SizedBox(width: 4),
                        SkeletonWidgets.buildCardSkeleton(
                            width: 30, height: 12, margin: EdgeInsets.zero),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SkeletonWidgets.buildCardSkeleton(
                        width: 50, height: 10, margin: EdgeInsets.zero),
                    const Spacer(),
                    SkeletonWidgets.buildCardSkeleton(
                        width: double.infinity,
                        height: 32,
                        margin: EdgeInsets.zero),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}