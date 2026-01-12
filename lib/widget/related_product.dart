import 'package:flutter/material.dart';

import '../model/home/product_model.dart';
import '../screen/home/product_detail_screen.dart';
import '../services/home/api_service.dart';
import 'product_add_button.dart'; // ✅ ADD THIS IMPORT

class RelatedProductsWidget extends StatelessWidget {
  final List<Product> relatedProducts;
  final bool loadingRelatedProducts;
  final bool isFromSearch;
  final String? categoryId;
  final String? subcategoryId;

  const RelatedProductsWidget({
    super.key,
    required this.relatedProducts,
    required this.loadingRelatedProducts,
    required this.isFromSearch,
    this.categoryId,
    this.subcategoryId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            isFromSearch ? 'You might also like' : 'Related Products',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (loadingRelatedProducts)
          const SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(color: Colors.green),
            ),
          )
        else if (relatedProducts.isEmpty)
          _buildEmptyState()
        else
          _buildProductsList(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 150,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              isFromSearch
                  ? 'No similar products found'
                  : 'No related products found',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsList() {
    return SizedBox(
      height: 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: relatedProducts.length,
        itemBuilder: (context, index) {
          return RelatedProductCard(
            product: relatedProducts[index],
            categoryId: categoryId,
            subcategoryId: subcategoryId,
          );
        },
      ),
    );
  }
}

class RelatedProductCard extends StatelessWidget {
  final Product product;
  final String? categoryId;
  final String? subcategoryId;

  const RelatedProductCard({
    super.key,
    required this.product,
    this.categoryId,
    this.subcategoryId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              product: product,
              categoryId: categoryId,
              subcategoryId: subcategoryId,
            ),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
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
          children: [
            _buildProductImage(),
            _buildProductDetails(),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage() {
    return Container(
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
        child: product.itemImages.isNotEmpty
            ? Image.network(
          ApiService.getImageUrl(product.itemImages.first, 'item'),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(
                Icons.image_not_supported,
                size: 32,
                color: Colors.grey[400],
              ),
            );
          },
        )
            : Center(
          child: Icon(
            Icons.shopping_basket,
            size: 32,
            color: Colors.grey[400],
          ),
        ),
      ),
    );
  }

  Widget _buildProductDetails() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBrandTag(),
            const SizedBox(height: 4),
            _buildProductName(),
            const Spacer(),
            _buildPriceSection(),
            const SizedBox(height: 8),
            // ✅ CHANGED: Use ProductAddButton instead of RelatedProductAddButton
            ProductAddButton(product: product),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandTag() {
    if (product.brand.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        product.brand,
        style: const TextStyle(
          fontSize: 9,
          color: Colors.green,
          fontWeight: FontWeight.bold,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildProductName() {
    return Text(
      product.itemName,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildPriceSection() {
    return Row(
      children: [
        Text(
          '₹${_safeToInt(product.salesPrice)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black,
          ),
        ),
        if (_safeToDouble(product.mrp) > _safeToDouble(product.salesPrice)) ...[
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '₹${_safeToInt(product.mrp)}',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                decoration: TextDecoration.lineThrough,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  int _safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }
}