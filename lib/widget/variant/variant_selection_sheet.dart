import 'package:flutter/material.dart';
import '../../model/home/product_model.dart';
import '../../services/home/api_service.dart'; // Needed for images
import '../product_add_button.dart';

class VariantSelectionSheet extends StatelessWidget {
  final Product mainProduct;
  final List<Product> variants;

  const VariantSelectionSheet({
    super.key,
    required this.mainProduct,
    required this.variants,
  });

  @override
  Widget build(BuildContext context) {
    // Sort variants by price
    variants.sort((a, b) => a.salesPrice.compareTo(b.salesPrice));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.only(top: 20, bottom: 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title uses clean name
                Text(
                  mainProduct.displayName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select Variant',
                  style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: variants.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final variant = variants[index];

                // ✅ LOGIC: Use displayName instead of "Previous variant"
                String displayName = variant.displayName;
                if (displayName.isEmpty) displayName = variant.unit;

                // ✅ IMAGE LOGIC
                String imageUrl = '';
                if (variant.itemImages.isNotEmpty) {
                  imageUrl = ApiService.getImageUrl(variant.itemImages.first, 'item');
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // ✅ ADDED: Product Image
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageUrl.isNotEmpty
                              ? Image.network(imageUrl, fit: BoxFit.cover)
                              : const Icon(Icons.image_not_supported, size: 30, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '₹${variant.salesPrice.toInt()}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                if (variant.mrp > variant.salesPrice) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '₹${variant.mrp.toInt()}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${variant.discountPercentage.toInt()}% OFF',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ✅ Button with Notify Logic
                      SizedBox(
                        width: 90,
                        height: 35,
                        child: ProductAddButton(
                          product: variant,
                          isVariantRow: true, // Prevents recursion
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}