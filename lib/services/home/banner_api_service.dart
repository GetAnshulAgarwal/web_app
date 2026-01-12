import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' as foundation;

import '../../authentication/user_data.dart';
import '../../model/home/banner_model.dart';
import '../../model/home/product_model.dart';

class BannerApiService {
  static const String baseUrl = 'https://pos.inspiredgrow.in/vps/api/catalog';
  static const String apiBaseUrl = 'https://pos.inspiredgrow.in/vps/api';
  static const String imageBaseUrl = 'https://pos.inspiredgrow.in';

  static final Map<String, dynamic> _cache = {};
  static const Duration _cacheExpiry = Duration(minutes: 10);
  static final Map<String, DateTime> _cacheTimestamps = {};

  static final http.Client _client = http.Client();
  static const Duration _requestTimeout = Duration(seconds: 30);

  static int _activeRequests = 0;
  static const int _maxConcurrentRequests = 3;

  // ========================================
  // BANNER FETCHING METHODS
  // ========================================

  /// Fetch all banners or banners by folder name
  static Future<List<Banner>> getBanners({String? folderName}) async {
    // Wait if too many concurrent requests
    while (_activeRequests >= _maxConcurrentRequests) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _activeRequests++;

    try {
      return await _makeRequest('banners_${folderName ?? 'all'}', () async {
        try {
          final userData = UserData();
          final String? token = userData.getToken();

          final Map<String, String> headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          };

          if (token != null) {
            headers['Authorization'] = 'Bearer $token';
          }

          final url = '$apiBaseUrl/product/all?page=1&limit=100';

          foundation.debugPrint('Fetching banners from: $url');

          // Reduced timeout from 30s to 8s
          final response = await _client.get(
            Uri.parse(url),
            headers: headers,
          ).timeout(const Duration(seconds: 8));

          foundation.debugPrint('Banner API Response Status: ${response.statusCode}');

          if (response.statusCode == 200) {
            final dynamic responseData = json.decode(response.body);
            List<dynamic> bannersJson = [];

            if (responseData is List) {
              bannersJson = responseData;
            } else if (responseData is Map) {
              if (responseData['data'] is List) {
                bannersJson = responseData['data'];
              } else if (responseData['banners'] is List) {
                bannersJson = responseData['banners'];
              } else if (responseData['products'] is List) {
                bannersJson = responseData['products'];
              }
            }

            foundation.debugPrint('Found ${bannersJson.length} banner objects in API response');

            if (bannersJson.isEmpty) {
              foundation.debugPrint('No banners found, returning fallback');
              return _getFallbackBanners();
            }

            final banners = bannersJson
                .map((json) {
              try {
                final banner = Banner.fromBannerApiJson(json as Map<String, dynamic>);
                foundation.debugPrint('Parsed banner: ${banner.id}, folder: ${banner.folderName}');
                return banner;
              } catch (e) {
                foundation.debugPrint('Error parsing banner: $e');
                return null;
              }
            })
                .where((banner) =>
            banner != null &&
                banner.folderName.isNotEmpty &&
                (banner.imageUrls.isNotEmpty || (banner.media != null && banner.media!.isNotEmpty))
            )
                .cast<Banner>()
                .toList();

            foundation.debugPrint('Successfully parsed ${banners.length} banners');

            List<Banner> filteredBanners = banners;
            if (folderName != null) {
              filteredBanners = banners
                  .where((b) => b.folderName.toLowerCase() == folderName.toLowerCase())
                  .toList();
              foundation.debugPrint('Filtered to ${filteredBanners.length} banners for folder: $folderName');
            }

            filteredBanners.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

            return filteredBanners.isNotEmpty ? filteredBanners : _getFallbackBanners();
          } else {
            foundation.debugPrint('Banner API Error: ${response.statusCode}');
            return _getFallbackBanners();
          }
        } catch (e, stackTrace) {
          foundation.debugPrint('Network Error fetching banners: $e');
          foundation.debugPrint('Stack trace: $stackTrace');
          return _getFallbackBanners();
        }
      });
    } finally {
      _activeRequests--;
    }
  }

  static Future<List<Banner>> getBannersForCategory(String? categoryId) async {
    return await _makeRequest('banners_category_${categoryId ?? 'general'}', () async {
      try {
        final userData = UserData();
        final String? token = userData.getToken();

        final Map<String, String> headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        };

        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        }

        // Try to get category-specific banners first
        String url = '$apiBaseUrl/product/all?page=1&limit=100';
        if (categoryId != null) {
          url += '&category=$categoryId';
        }

        final response = await _client.get(
          Uri.parse(url),
          headers: headers,
        ).timeout(_requestTimeout);

        if (response.statusCode == 200) {
          final dynamic jsonResponse = json.decode(response.body);
          List<dynamic> bannersJson = [];

          if (jsonResponse is List) {
            bannersJson = jsonResponse;
          } else if (jsonResponse is Map) {
            bannersJson = (jsonResponse['data'] ?? jsonResponse['banners'] ?? []) as List;
          }

          final banners = bannersJson
              .map((json) {
            try {
              return Banner.fromBannerApiJson(json);
            } catch (e) {
              foundation.debugPrint('❌ Error parsing category banner: $e');
              return null;
            }
          })
              .where((banner) => banner != null && banner.imageUrls.isNotEmpty)
              .cast<Banner>()
              .toList();

          banners.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          return banners.isNotEmpty ? banners : _getFallbackBannersForCategory(categoryId);
        } else {
          return _getFallbackBannersForCategory(categoryId);
        }
      } catch (e) {
        foundation.debugPrint('🚨 Error fetching banners for category $categoryId: $e');
        return _getFallbackBannersForCategory(categoryId);
      }
    });
  }

  /// Get a specific banner by ID
  static Future<Banner?> getBannerById(String bannerId) async {
    try {
      final userData = UserData();
      final String? token = userData.getToken();

      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final url = '$apiBaseUrl/product/$bannerId';

      final response = await _client.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is Map<String, dynamic>) {
          if (data['success'] == true && data['data'] != null) {
            return Banner.fromBannerApiJson(data['data'] as Map<String, dynamic>);
          } else {
            return Banner.fromBannerApiJson(data);
          }
        }
      }

      return null;
    } catch (e) {
      foundation.debugPrint('🚨 Error fetching banner $bannerId: $e');
      return null;
    }
  }

  // ========================================
  // BANNER PRODUCTS METHODS
  // ========================================

  /// Fetch products for a specific banner
  static Future<List<Product>> getProductsForBanner(Banner banner) async {
    try {
      foundation.debugPrint('🎯 Fetching products for banner: ${banner.id}');

      if (banner.media == null || banner.media!.isEmpty) {
        foundation.debugPrint('⚠️ No media data in banner');
        return [];
      }

      final List<Product> allProducts = [];
      final Set<String> seenProductIds = {};

      for (final mediaItem in banner.media!) {
        foundation.debugPrint('🔄 Processing media: brand=${mediaItem.brand?.name}, category=${mediaItem.category?.name}');

        // Priority 1: Brand + Category
        if (mediaItem.brand != null && mediaItem.category != null) {
          final products = await getProductsByCategoryAndBrand(
            mediaItem.category!.id,
            mediaItem.brand!.id,
            limit: 20,
          );

          for (final product in products) {
            if (!seenProductIds.contains(product.id)) {
              allProducts.add(product);
              seenProductIds.add(product.id);
            }
          }

          if (products.isNotEmpty) {
            foundation.debugPrint('✅ Found ${products.length} products for brand + category');
            continue;
          }
        }

        // Priority 2: Brand only
        if (mediaItem.brand != null && allProducts.length < 20) {
          final products = await getProductsByBrand(mediaItem.brand!.id, limit: 20);

          for (final product in products) {
            if (!seenProductIds.contains(product.id)) {
              allProducts.add(product);
              seenProductIds.add(product.id);
            }
          }

          if (products.isNotEmpty) {
            foundation.debugPrint('✅ Found ${products.length} products for brand');
            continue;
          }
        }

        // Priority 3: Category only
        if (mediaItem.category != null && allProducts.length < 20) {
          final products = await getProductsForCategory(mediaItem.category!.id, limit: 15);

          for (final product in products) {
            if (!seenProductIds.contains(product.id)) {
              allProducts.add(product);
              seenProductIds.add(product.id);
            }
          }

          foundation.debugPrint('✅ Found ${products.length} products for category');
        }
      }

      foundation.debugPrint('🎉 Total unique products found: ${allProducts.length}');
      return allProducts.take(50).toList();

    } catch (e) {
      foundation.debugPrint('🚨 Error fetching products for banner: $e');
      return [];
    }
  }

  /// Fetch products by brand ID
  static Future<List<Product>> getProductsByBrand(String brandId, {int limit = 20}) async {
    return await _makeRequest('products_brand_$brandId', () async {
      try {
        final endpoints = [
          '$apiBaseUrl/items?brand_id=$brandId&limit=$limit',
          '$baseUrl/brands/$brandId/items?limit=$limit',
        ];

        for (final url in endpoints) {
          try {
            final response = await _client.get(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            ).timeout(_requestTimeout);

            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              List<dynamic> itemsData = [];

              if (data['success'] == true && data['data'] != null) {
                itemsData = data['data'] as List;
              } else if (data is List) {
                itemsData = data;
              }

              if (itemsData.isNotEmpty) {
                final products = itemsData
                    .map((json) {
                  try {
                    return Product.fromJson(json);
                  } catch (e) {
                    return null;
                  }
                })
                    .where((p) => p != null)
                    .cast<Product>()
                    .toList();

                if (products.isNotEmpty) {
                  return products;
                }
              }
            }
          } catch (e) {
            continue;
          }
        }

        return <Product>[];
      } catch (e) {
        return <Product>[];
      }
    });
  }

  /// Fetch products for a category
  static Future<List<Product>> getProductsForCategory(String categoryId, {int limit = 20}) async {
    return await _makeRequest('products_cat_$categoryId', () async {
      try {
        final endpoints = [
          '$apiBaseUrl/items?category_id=$categoryId&limit=$limit',
          '$baseUrl/categories/$categoryId/items?limit=$limit',
        ];

        for (final url in endpoints) {
          try {
            final response = await _client.get(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            ).timeout(_requestTimeout);

            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              List<dynamic> itemsData = [];

              if (data['success'] == true && data['data'] != null) {
                itemsData = data['data'] as List;
              } else if (data is List) {
                itemsData = data;
              }

              if (itemsData.isNotEmpty) {
                final products = itemsData
                    .map((json) {
                  try {
                    return Product.fromJson(json);
                  } catch (e) {
                    return null;
                  }
                })
                    .where((p) => p != null)
                    .cast<Product>()
                    .toList();

                if (products.isNotEmpty) {
                  return products;
                }
              }
            }
          } catch (e) {
            continue;
          }
        }

        return <Product>[];
      } catch (e) {
        return <Product>[];
      }
    });
  }

  /// Fetch products for a specific media item within a banner
  static Future<List<Product>> getProductsForSpecificMedia(
      Banner banner,
      BannerMedia mediaItem
      ) async {
    try {
      foundation.debugPrint('🎯 Fetching products for specific media: brand=${mediaItem.brand?.name}, category=${mediaItem.category?.name}');

      // First, check if products are already embedded
      if (mediaItem.items != null && mediaItem.items!.isNotEmpty) {
        foundation.debugPrint('✅ Found ${mediaItem.items!.length} embedded products');
        return mediaItem.items!;
      }

      // Fallback: Fetch via API
      foundation.debugPrint('📡 No embedded products, fetching via API...');

      // Priority 1: Brand + Category
      if (mediaItem.brand != null && mediaItem.category != null) {
        final products = await getProductsByCategoryAndBrand(
          mediaItem.category!.id,
          mediaItem.brand!.id,
          limit: 50,
        );
        if (products.isNotEmpty) {
          foundation.debugPrint('✅ Found ${products.length} products for brand + category');
          return products;
        }
      }

      // Priority 2: Brand only
      if (mediaItem.brand != null) {
        final products = await getProductsByBrand(mediaItem.brand!.id, limit: 50);
        if (products.isNotEmpty) {
          foundation.debugPrint('✅ Found ${products.length} products for brand');
          return products;
        }
      }

      // Priority 3: Category only
      if (mediaItem.category != null) {
        final products = await getProductsForCategory(mediaItem.category!.id, limit: 50);
        if (products.isNotEmpty) {
          foundation.debugPrint('✅ Found ${products.length} products for category');
          return products;
        }
      }

      return [];
    } catch (e) {
      foundation.debugPrint('🚨 Error fetching products for media: $e');
      return [];
    }
  }



  /// Fetch products by category and brand combination
  static Future<List<Product>> getProductsByCategoryAndBrand(
      String categoryId,
      String brandId, {
        int limit = 20,
      }) async {
    return await _makeRequest(
      'products_cat_${categoryId}_brand_$brandId',
          () async {
        try {
          final endpoints = [
            '$apiBaseUrl/items?category_id=$categoryId&brand_id=$brandId&limit=$limit',
            '$baseUrl/items?category_id=$categoryId&brand_id=$brandId&limit=$limit',
          ];

          for (final url in endpoints) {
            try {
              final response = await _client.get(
                Uri.parse(url),
                headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
              ).timeout(_requestTimeout);

              if (response.statusCode == 200) {
                final data = json.decode(response.body);
                List<dynamic> itemsData = [];

                if (data['success'] == true && data['data'] != null) {
                  itemsData = data['data'] as List;
                } else if (data is List) {
                  itemsData = data;
                }

                if (itemsData.isNotEmpty) {
                  final products = itemsData
                      .map((json) {
                    try {
                      return Product.fromJson(json);
                    } catch (e) {
                      return null;
                    }
                  })
                      .where((p) => p != null)
                      .cast<Product>()
                      .toList();

                  if (products.isNotEmpty) {
                    return products;
                  }
                }
              }
            } catch (e) {
              continue;
            }
          }

          return await getProductsByBrand(brandId, limit: limit);

        } catch (e) {
          return <Product>[];
        }
      },
    );
  }

  // ========================================
  // BANNER IMAGE METHODS
  // ========================================

  /*static List<String> getBannerImageUrls(String imagePath) {
    if (imagePath.isEmpty) return [];

    final List<String> urls = [];

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      urls.add(imagePath);
      return urls;
    }

    if (imagePath.startsWith('/')) {
      urls.add('https://pos.inspiredgrow.in$imagePath');
      return urls;
    }

    // ✅ FIXED: Added the correct path based on the 404 error log
    urls.add('$imageBaseUrl/uploads/banners/$imagePath');

    // Keep the old ones as fallbacks if needed
    urls.add('$imageBaseUrl/banners/$imagePath');
    urls.add('https://pos.inspiredgrow.in/vps/uploads/banners/$imagePath');
    urls.add('$imageBaseUrl/$imagePath');

    return urls;
  }*/
  // ========================================
  // FALLBACK METHODS
  // ========================================

  static List<Banner> _getFallbackBanners() {
    return [
      Banner(
        id: '1',
        imageUrls: ['https://via.placeholder.com/400x140/FF6B6B/FFFFFF?text=Special+Offers'],
        title: 'Special Offers',
        subtitle: 'Great deals on your favorite items',
        folderName: '1',
        link: null,
        isActive: true,
        sortOrder: 1,
        media: [],
      ),
    ];
  }

  static List<Banner> _getFallbackBannersForCategory(String? categoryId) {
    if (categoryId != null) {
      return [
        Banner(
          id: 'cat_${categoryId}_1',
          imageUrls: ['https://via.placeholder.com/400x140/45B7D1/FFFFFF?text=Category+Special'],
          title: 'Special Offers',
          subtitle: 'Great deals in this category',
          folderName: 'category_$categoryId',
          link: 'category:$categoryId',
          isActive: true,
          sortOrder: 1,
          media: [],
        ),
      ];
    }
    return _getFallbackBanners();
  }

  // ========================================
  // UTILITY METHODS
  // ========================================

  static Future<T> _makeRequest<T>(
      String cacheKey,
      Future<T> Function() request, {
        bool useCache = true,
      }) async {
    if (useCache && _cache.containsKey(cacheKey)) {
      final timestamp = _cacheTimestamps[cacheKey];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _cacheExpiry) {
        return _cache[cacheKey] as T;
      }
    }

    try {
      T result = await request().timeout(_requestTimeout);

      if (useCache) {
        _cache[cacheKey] = result;
        _cacheTimestamps[cacheKey] = DateTime.now();
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }

  static void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
    _cacheTimestamps.clear();
  }

  static void clearOldCache() {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    for (final key in _cache.keys) {
      final timestamp = _cacheTimestamps[key];
      if (timestamp != null && now.difference(timestamp) >= _cacheExpiry) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
    }

    foundation.debugPrint('Cleared ${keysToRemove.length} expired cache entries');
  }


  static void clearExpiredCache() {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    for (final key in _cache.keys) {
      final timestamp = _cacheTimestamps[key];
      if (timestamp != null && now.difference(timestamp) >= _cacheExpiry) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  static Map<String, dynamic> getCacheStats() {
    final now = DateTime.now();
    final validCache = <String, dynamic>{};
    final expiredCache = <String, dynamic>{};

    for (final key in _cache.keys) {
      final timestamp = _cacheTimestamps[key];
      if (timestamp != null) {
        final isExpired = now.difference(timestamp) >= _cacheExpiry;
        if (isExpired) {
          expiredCache[key] = {
            'cached_at': timestamp.toIso8601String(),
            'expired': true,
          };
        } else {
          validCache[key] = {
            'cached_at': timestamp.toIso8601String(),
            'expires_in': _cacheExpiry.inMinutes - now.difference(timestamp).inMinutes,
          };
        }
      }
    }

    return {
      'total_cached_items': _cache.length,
      'valid_cache_items': validCache.length,
      'expired_cache_items': expiredCache.length,
      'cache_expiry_minutes': _cacheExpiry.inMinutes,
      'valid_cache': validCache,
      'expired_cache': expiredCache,
    };
  }

  static void dispose() {
    try {
      _client.close();
      clearCache();
    } catch (e) {
      // Handle dispose error silently
    }
  }

  static void reset() {
    clearCache();
  }
}