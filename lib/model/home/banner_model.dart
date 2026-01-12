import 'package:eshop/model/home/product_model.dart';
import 'package:flutter/foundation.dart' as foundation;

class Banner {
  final String id;
  final List<String> imageUrls;
  final String title;
  final String subtitle;
  final String folderName;
  final String? link;
  final bool isActive;
  final int sortOrder;
  final List<BannerMedia>? media; // Changed from List<dynamic> to List<BannerMedia>

  Banner({
    required this.id,
    required this.imageUrls,
    required this.title,
    required this.subtitle,
    required this.folderName,
    this.link,
    required this.isActive,
    required this.sortOrder,
    this.media,
  });

  /// The primary factory used by your BannerApiService
  factory Banner.fromBannerApiJson(Map<String, dynamic> json) {
    return Banner(
      id: json['_id'] ?? json['id'] ?? '',
      imageUrls: _extractBannerImageUrls(json),
      title: json['title'] ?? json['folderName'] ?? 'Banner',
      subtitle: json['subtitle'] ?? '',
      folderName: json['folderName'] ?? '',
      link: json['link'],
      isActive: json['status'] == 'Active' || json['isActive'] == true || _parseBool(json['is_active']),
      sortOrder: _parseInt(json['sortOrder'] ?? json['sort_order']),
      media: _extractMediaList(json), // Parse media array
    );
  }

  factory Banner.fromProductJson(Map<String, dynamic> json) {
    return Banner(
      id: json['_id'] ?? '',
      imageUrls: _extractBannerImageUrls(json),
      title: json['folderName'] ?? '',
      subtitle: '',
      folderName: json['folderName'] ?? '',
      link: null,
      isActive: true,
      sortOrder: 0,
      media: _extractMediaList(json),
    );
  }

  factory Banner.fromJson(Map<String, dynamic> json) {
    return Banner(
      id: json['id']?.toString() ?? '',
      imageUrls: [(json['image'] ?? json['imageUrl'] ?? '')],
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      folderName: json['folderName'] ?? '',
      link: json['link'],
      sortOrder: _parseInt(json['sort_order']),
      isActive: _parseBool(json['is_active']),
      media: _extractMediaList(json),
    );
  }

  static List<String> _extractBannerImageUrls(Map<String, dynamic> json) {
    final List<String> urls = [];

    // Primary logic: Process the 'media' array if it exists.
    if (json['media'] != null && json['media'] is List) {
      final media = json['media'] as List;
      for (final item in media) {
        if (item != null && item is Map && item['url'] != null) {
          String url = item['url'].toString();

          // This logic correctly handles all known URL formats from your API.
          if (url.startsWith('http')) {
            // Case 1: The URL is already a full, absolute path. No changes needed.
          } else if (url.startsWith('/uploads/')) {
            // Case 2: The URL is a partial path like '/uploads/banners/...'.
            // Prepend the correct domain WITH /vps
            url = 'https://pos.inspiredgrow.in/vps$url'; // This is correct
          } else if (url.startsWith('/')) {
            // Case 3: The URL is a different root path. Prepend the domain as a safe fallback.
            // e.g., "/some/other/path/image.webp"
            url = 'https://pos.inspiredgrow.in$url';
          } else if (url.isNotEmpty) {
            // Case 4: The URL is just a filename. Build the full, correct path from scratch.
            // e.g., "1756959178359.webp"
            url = 'https://pos.inspiredgrow.in/vps/uploads/banners/$url';
          }

          // Add the correctly formatted URL to the list if it's not empty.
          if (url.isNotEmpty) {
            urls.add(url);
          }
        }
      }
    }

    // Fallback to a direct 'image' field if the 'media' array is empty or missing.
    if (urls.isEmpty && json['image'] != null) {
      // Note: This fallback assumes the 'image' field is already a full URL.
      // If it can also be a relative path, it would require the same logic as above.
      urls.add(json['image'].toString());
    }

    return urls;
  }

  /// Extracts and parses the media array into BannerMedia objects
  static List<BannerMedia>? _extractMediaList(Map<String, dynamic> json) {
    if (json['media'] == null || json['media'] is! List) {
      return null;
    }

    final List<BannerMedia> mediaList = [];
    final media = json['media'] as List;

    for (final item in media) {
      if (item != null && item is Map<String, dynamic>) {
        try {
          mediaList.add(BannerMedia.fromJson(item));
        } catch (e) {
          foundation.debugPrint('Error parsing media item: $e');
        }
      }
    }

    return mediaList.isNotEmpty ? mediaList : null;
  }

  // Helper Methods
  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
  }
}

/// Represents a media item within a banner
/// Represents a media item within a banner
class BannerMedia {
  final String id;
  final String url;
  final BannerBrand? brand;
  final BannerCategory? category;
  final BannerSubSubCategory? subSubCategory; // Add this if needed
  final List<Product>? items;
  final List<String> itemIds;

  BannerMedia({
    required this.id,
    required this.url,
    this.brand,
    this.items,
    this.category,
    this.subSubCategory,
    required this.itemIds,
  });

  factory BannerMedia.fromJson(Map<String, dynamic> json) {
    return BannerMedia(
      id: json['_id'] ?? '',
      url: json['url'] ?? '',
      brand: json['brand'] != null
          ? BannerBrand.fromJson(json['brand'] as Map<String, dynamic>)
          : null,
      category: json['category'] != null
          ? BannerCategory.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      subSubCategory: json['subSubCategory'] != null
          ? BannerSubSubCategory.fromJson(json['subSubCategory'] as Map<String, dynamic>)
          : null,
      items: json['items'] != null && json['items'] is List
          ? (json['items'] as List)
          .map((item) {
        try {
          final itemMap = Map<String, dynamic>.from(item);
          if (itemMap.containsKey('_id') && !itemMap.containsKey('id')) {
            itemMap['id'] = itemMap['_id'];
          }
          return Product.fromJson(itemMap);
        } catch (e) {
          foundation.debugPrint('Error parsing product in banner media: $e');
          return null;
        }
      })
          .whereType<Product>()
          .toList()
          : null,
      itemIds: json['items'] != null && json['items'] is List
          ? (json['items'] as List)
          .map((item) => item['_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList()
          : [],
    );
  }

  String getFullUrl() {
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('/uploads/')) {
      return 'https://pos.inspiredgrow.in/vps$url';
    }
    if (url.startsWith('/')) {
      return 'https://pos.inspiredgrow.in/vps$url';
    }
    return 'https://pos.inspiredgrow.in/vps/uploads/banners/$url';
  }
}

// Add this class if you need subSubCategory
class BannerSubSubCategory {
  final String id;
  final String name;
  final String status;
  final String description;
  final String? image;

  BannerSubSubCategory({
    required this.id,
    required this.name,
    required this.status,
    this.description = '',
    this.image,
  });

  factory BannerSubSubCategory.fromJson(Map<String, dynamic> json) {
    return BannerSubSubCategory(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      status: json['status'] ?? 'Active',
      description: json['description'] ?? '',
      image: json['image'],
    );
  }
}

class BannerBrand {
  final String id;
  final String name;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BannerBrand({
    required this.id,
    required this.name,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory BannerBrand.fromJson(Map<String, dynamic> json) {
    return BannerBrand(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['brandName'] ?? json['name'] ?? '',
      status: json['status'] ?? 'Active',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
    );
  }
}

/// Represents a category associated with a banner media item
class BannerCategory {
  final String id;
  final String name;
  final String status;
  final String description;
  final String? image;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BannerCategory({
    required this.id,
    required this.name,
    required this.status,
    this.description = '',
    this.image,
    this.createdAt,
    this.updatedAt,
  });

  factory BannerCategory.fromJson(Map<String, dynamic> json) {
    return BannerCategory(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      status: json['status'] ?? 'Active',
      description: json['description'] ?? '',
      image: json['image'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
    );
  }
}