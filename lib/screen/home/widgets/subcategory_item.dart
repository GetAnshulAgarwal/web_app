import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../Animation/bouncing_dots.dart';
import '../../../model/home/subcategory.dart';
import '../../../services/home/api_service.dart';

class SubcategoryItem extends StatelessWidget {
  final SubCategory subcategory;
  final VoidCallback onTap;
  final double? width;
  final double? height;
  final double? imageSize;
  final double? fontSize;
  final int? maxLines;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;

  const SubcategoryItem({
    Key? key,
    required this.subcategory,
    required this.onTap,
    this.width,
    this.height,
    this.imageSize = 80,
    this.fontSize = 12,
    this.maxLines = 2,
    this.margin,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(12);
    final effectiveMargin = margin ?? EdgeInsets.symmetric(horizontal: 4, vertical: 4);
    final effectiveImageSize = imageSize ?? 80;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width ?? effectiveImageSize,
        height: height,
        margin: effectiveMargin,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Image Container with grey theme
            Container(
              width: effectiveImageSize,
              height: effectiveImageSize,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: effectiveBorderRadius,
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: _buildImage(context, effectiveBorderRadius, effectiveImageSize),
            ),

            SizedBox(height: 8),

            // Text with grey color
            SizedBox(
              width: effectiveImageSize,
              child: Text(
                subcategory.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                  height: 1.2,
                ),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context, BorderRadius borderRadius, double imageSize) {
    if (subcategory.image.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: borderRadius,
        ),
        child: Center(
          child: Icon(
            Icons.category,
            color: Colors.grey[600],
            size: imageSize * 0.4,
          ),
        ),
      );
    }

    // Get device pixel ratio for high-quality images
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    // Calculate optimal cache dimensions (3x for retina displays)
    final cacheSize = (imageSize * devicePixelRatio * 1.5).toInt(); // ← Increased multiplier

    // Maximum disk cache size for better quality
    final diskCacheSize = (imageSize * 3).toInt(); // ← Tripled for better quality

    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: ApiService.getImageUrl(
          subcategory.image,
          'subcategory',
        ),
        fit: BoxFit.cover,
        width: imageSize,
        height: imageSize,

        // ✅ HIGH QUALITY MEMORY CACHE
        memCacheWidth: cacheSize,
        memCacheHeight: cacheSize,

        // ✅ HIGH QUALITY DISK CACHE (increased from 512)
        maxWidthDiskCache: diskCacheSize > 1024 ? 1024 : diskCacheSize, // Max 1024px
        maxHeightDiskCache: diskCacheSize > 1024 ? 1024 : diskCacheSize,

        // ✅ ENABLE FILTERING FOR SMOOTHER IMAGES
        filterQuality: FilterQuality.high, // ← Added for better quality

        placeholder: (context, url) => Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: borderRadius,
          ),
          child: Center(
            child: BouncingDotsIndicator(
              color: Colors.grey[600]!,
              size: 3.0,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: borderRadius,
          ),
          child: Center(
            child: Icon(
              Icons.image_not_supported,
              color: Colors.grey[600],
              size: imageSize * 0.4,
            ),
          ),
        ),
        fadeInDuration: Duration(milliseconds: 300), // ← Smoother fade-in
        fadeOutDuration: Duration(milliseconds: 200),
      ),
    );
  }
}