import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../services/home/api_service.dart';
import '../skeleton_widgets.dart';

class OptimizedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final String imageType;
  final double? width;
  final double? height;
  final BoxFit fit;

  const OptimizedNetworkImage({
    super.key,
    required this.imageUrl,
    required this.imageType,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildDefaultPlaceholder();
    }

    String fullUrl;
    try {
      fullUrl = ApiService.getImageUrl(imageUrl, imageType);
    } catch (e) {
      debugPrint('Error getting image URL: $e');
      return _buildDefaultPlaceholder();
    }

    final safeWidth = _validateDimension(width);
    final safeHeight = _validateDimension(height);

    return CachedNetworkImage(
      imageUrl: fullUrl,
      width: safeWidth,
      height: safeHeight,
      fit: fit,
      // This placeholder will now show a skeleton
      placeholder: (context, url) => _buildLoadingPlaceholder(),
      errorWidget: (context, url, error) => _buildDefaultPlaceholder(),
      memCacheWidth:
      safeWidth != null
          ? (safeWidth * MediaQuery.of(context).devicePixelRatio).round()
          : null,
      memCacheHeight:
      safeHeight != null
          ? (safeHeight * MediaQuery.of(context).devicePixelRatio).round()
          : null,
      maxWidthDiskCache: 1024,
      maxHeightDiskCache: 1024,
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: const Duration(milliseconds: 100),
    );
  }

  double? _validateDimension(double? dimension) {
    if (dimension == null) {
      return null;
    }
    if (dimension.isInfinite || dimension.isNaN || dimension <= 0) {
      return null;
    }
    return dimension.clamp(10.0, 2000.0);
  }

  Widget _buildLoadingPlaceholder() {
    // Use the existing SkeletonWidgets to show a shimmer effect
    return SkeletonWidgets.buildCardSkeleton(
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildDefaultPlaceholder() {
    final safeWidth = _validateDimension(width) ?? 100.0;
    final safeHeight = _validateDimension(height) ?? 100.0;

    return Container(
      width: safeWidth,
      height: safeHeight,
      color: Colors.grey[100],
      child: Center(
        child: Icon(
          Icons.image_not_supported,
          size: (safeHeight * 0.3).clamp(16.0, 32.0),
          color: Colors.grey[300],
        ),
      ),
    );
  }
}
