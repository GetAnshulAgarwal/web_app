import 'dart:convert';
import 'dart:async';
import 'dart:math' as Math;
import 'package:flutter/foundation.dart' as foundation;
import 'package:http/http.dart' as http;
import '../cache/isolate_operations.dart'; // Kept from master
import '../../model/home/category.dart';
import '../../model/home/deck.dart';
import '../../model/home/product_model.dart';
import '../../model/home/subcategory.dart';
import '../../model/home/subsubcategory.dart';
import '../../model/home/banner_model.dart';
import '../../authentication/user_data.dart';

class ApiService {
  static const String baseUrl = 'https://pos.inspiredgrow.in/vps/api/catalog';
  static const String apiBaseUrl = 'https://pos.inspiredgrow.in/vps/api';
  static const String imageBaseUrl = 'https://pos.inspiredgrow.in/vps/uploads';
  // Kept from balaji
  static const String Base2Url =
      'https://pos.inspiredgrow.in/vps/api/catalog/trending-tiles-with-items?page=1&limit10';

  static final Map<String, dynamic> _cache = {};
  static const Duration _cacheExpiry = Duration(minutes: 10);
  static final Map<String, DateTime> _cacheTimestamps = {};

  static final http.Client _client = http.Client();
  static const Duration _requestTimeout = Duration(seconds: 30);

  // ========================================
  // ENHANCED IMAGE HANDLING METHODS
  // ========================================

  static String getImageUrl(String imagePath, String type) {
    if (imagePath.isEmpty) return '';

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    if (imagePath.startsWith('/')) {
      return 'https://pos.inspiredgrow.in$imagePath';
    }

    String processedPath = _encodeImagePath(imagePath);

    switch (type) {
      case 'category':
        return '$imageBaseUrl/categories/$processedPath';
      case 'subcategory':
        return '$imageBaseUrl/subcategories/$processedPath';
      case 'subsubcategory':
        return '$imageBaseUrl/sub-subcategories/$processedPath';
      case 'deck':
        return '$imageBaseUrl/sub-subcategories/$processedPath'; // âœ… Fixed based on working solution
      case 'item':
        return '$imageBaseUrl/qr/items/$processedPath';
      case 'banner':
        return getBannerImageUrl(imagePath);
      default:
        return '$imageBaseUrl/$processedPath';
    }
  }

  static String _encodeImagePath(String imagePath) {
    List<String> pathParts = imagePath.split('/');
    List<String> encodedParts = pathParts.map((part) {
      return Uri.encodeComponent(part);
    }).toList();

    return encodedParts.join('/');
  }

  static List<String> getImageUrlFallbacks(String imagePath, String type) {
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

    String encodedPath = _encodeImagePath(imagePath);
    String rawPath = imagePath;

    switch (type) {
      case 'category':
        urls.add('$imageBaseUrl/categories/$encodedPath');
        urls.add('$imageBaseUrl/categories/$rawPath');
        urls.add('$imageBaseUrl/$encodedPath');
        urls.add('$imageBaseUrl/$rawPath');
        break;

      case 'subcategory':
        urls.add('$imageBaseUrl/subcategories/$encodedPath');
        urls.add('$imageBaseUrl/subcategories/$rawPath');
        urls.add('$imageBaseUrl/$encodedPath');
        urls.add('$imageBaseUrl/$rawPath');
        break;

      case 'subsubcategory':
        urls.add('$imageBaseUrl/sub-subcategories/$encodedPath');
        urls.add('$imageBaseUrl/sub-subcategories/$rawPath');
        urls.add('$imageBaseUrl/subsubcategories/$encodedPath');
        urls.add('$imageBaseUrl/subsubcategories/$rawPath');
        urls.add('$imageBaseUrl/subcategories/$encodedPath');
        urls.add('$imageBaseUrl/subcategories/$rawPath');
        urls.add('$imageBaseUrl/$encodedPath');
        urls.add('$imageBaseUrl/$rawPath');
        break;

      case 'deck':
      // âœ… ENHANCED: Based on working solution from logs
        urls.add('$imageBaseUrl/sub-subcategories/$encodedPath');
        urls.add('$imageBaseUrl/sub-subcategories/$rawPath');
        urls.add('$imageBaseUrl/decks/$encodedPath');
        urls.add('$imageBaseUrl/decks/$rawPath');
        urls.add('$imageBaseUrl/subsubcategories/$encodedPath');
        urls.add('$imageBaseUrl/subsubcategories/$rawPath');
        urls.add('$imageBaseUrl/subcategories/$encodedPath');
        urls.add('$imageBaseUrl/subcategories/$rawPath');
        urls.add('$imageBaseUrl/categories/$encodedPath');
        urls.add('$imageBaseUrl/categories/$rawPath');
        urls.add('$imageBaseUrl/$encodedPath');
        urls.add('$imageBaseUrl/$rawPath');
        break;

      case 'item':
        urls.add('$imageBaseUrl/qr/items/$encodedPath');
        urls.add('$imageBaseUrl/qr/items/$rawPath');
        urls.add('$imageBaseUrl/$encodedPath');
        urls.add('$imageBaseUrl/$rawPath');
        urls.add('$imageBaseUrl/items/$encodedPath');
        urls.add('$imageBaseUrl/items/$rawPath');
        break;

      case 'banner':
        urls.add(getBannerImageUrl(imagePath));
        break;

      default:
        urls.add('$imageBaseUrl/$encodedPath');
        urls.add('$imageBaseUrl/$rawPath');
        break;
    }

    final Set<String> seen = {};
    return urls.where((url) => seen.add(url)).toList();
  }

  // âœ… ENHANCED: Specialized method for SubSubCategory images
  static List<String> getSubSubCategoryImageUrls(String imagePath) {
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

    String encodedPath = _encodeImagePath(imagePath);
    String rawPath = imagePath;

    // âœ… Priority order based on successful tests
    urls.add('$imageBaseUrl/sub-subcategories/$encodedPath');
    urls.add('$imageBaseUrl/sub-subcategories/$rawPath');
    urls.add('$imageBaseUrl/subsubcategories/$encodedPath');
    urls.add('$imageBaseUrl/subsubcategories/$rawPath');
    urls.add('$imageBaseUrl/subcategories/$encodedPath');
    urls.add('$imageBaseUrl/subcategories/$rawPath');
    urls.add('$imageBaseUrl/categories/$encodedPath');
    urls.add('$imageBaseUrl/categories/$rawPath');
    urls.add('$imageBaseUrl/$encodedPath');
    urls.add('$imageBaseUrl/$rawPath');

    final Set<String> seen = {};
    return urls.where((url) => seen.add(url)).toList();
  }

  // âœ… NEW: Specialized method for Deck images (based on successful implementation)
  static List<String> getDeckImageUrls(String imagePath) {
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

    String encodedPath = _encodeImagePath(imagePath);
    String rawPath = imagePath;

    // âœ… Deck images are stored in sub-subcategories folder (proven by logs)
    urls.add('$imageBaseUrl/sub-subcategories/$encodedPath');
    urls.add('$imageBaseUrl/sub-subcategories/$rawPath');
    urls.add('$imageBaseUrl/decks/$encodedPath');
    urls.add('$imageBaseUrl/decks/$rawPath');
    urls.add('$imageBaseUrl/subsubcategories/$encodedPath');
    urls.add('$imageBaseUrl/subsubcategories/$rawPath');
    urls.add('$imageBaseUrl/subcategories/$encodedPath');
    urls.add('$imageBaseUrl/subcategories/$rawPath');
    urls.add('$imageBaseUrl/categories/$encodedPath');
    urls.add('$imageBaseUrl/categories/$rawPath');
    urls.add('$imageBaseUrl/$encodedPath');
    urls.add('$imageBaseUrl/$rawPath');

    final Set<String> seen = {};
    return urls.where((url) => seen.add(url)).toList();
  }

  // ========================================
  // BANNER API METHODS
  // ========================================

  static Future<List<Banner>> getBanners({String? folderName}) async {
    return await _makeRequest('banners_${folderName ?? 'all'}', () async {
      try {
        // Fetch all banners and then filter, which is more robust.
        final url = '$apiBaseUrl/banners';
        final response = await _client
            .get(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        )
            .timeout(_requestTimeout);

        if (response.statusCode == 200) {
          // The API returns a List directly for this endpoint
          final List<dynamic> bannersJson = json.decode(response.body);
          final banners = bannersJson
              .map((json) {
            try {
              // Use the correct factory that exists in your model
              return Banner.fromBannerApiJson(json);
            } catch (e) {
              foundation.debugPrint('âŒ Error parsing banner: $e');
              return null;
            }
          })
          // This 'where' clause correctly accesses properties on the 'Banner' object.
              .where(
                (banner) =>
            banner != null &&
                banner.isActive &&
                banner.imageUrls.isNotEmpty,
          )
              .cast<Banner>()
              .toList();

          // If a folderName is specified, filter the results
          if (folderName != null) {
            return banners
                .where(
                  (b) => b.folderName.toLowerCase() == folderName.toLowerCase(),
            )
                .toList();
          }

          banners.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          return banners.isNotEmpty ? banners : await _getFallbackBanners();
        } else {
          foundation.debugPrint(
            'âš ï¸ API Error: ${response.statusCode} - ${response.body}',
          );
          return await _getFallbackBanners();
        }
      } catch (e) {
        foundation.debugPrint('ðŸš¨ Network Error fetching banners: $e');
        return await _getFallbackBanners();
      }
    });
  }

  static Future<List<Banner>> getBannersForCategory(String? categoryId) async {
    return await _makeRequest(
      'banners_category_${categoryId ?? 'general'}',
          () async {
        try {
          String url;
          if (categoryId != null) {
            url = '$apiBaseUrl/banners?category_id=$categoryId';
          } else {
            url = '$apiBaseUrl/banners';
          }

          final response = await _client
              .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
              .timeout(_requestTimeout);

          if (response.statusCode == 200) {
            final Map<String, dynamic> jsonResponse = json.decode(
              response.body,
            );

            List<dynamic> bannersJson = [];

            if (jsonResponse['success'] == true &&
                jsonResponse['data'] != null) {
              bannersJson = jsonResponse['data'] as List<dynamic>;
            } else if (jsonResponse['banners'] != null) {
              bannersJson = jsonResponse['banners'] as List<dynamic>;
            }

            final banners = bannersJson
                .map((json) {
              try {
                return Banner.fromJson(json);
              } catch (e) {
                return null;
              }
            })
                .where((banner) => banner != null && banner.isActive)
                .cast<Banner>()
                .toList();

            banners.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
            return banners;
          } else {
            if (categoryId != null) {
              return await getBannersForCategory(null);
            }
            return _getFallbackBannersForCategory(categoryId);
          }
        } catch (e) {
          return _getFallbackBannersForCategory(categoryId);
        }
      },
    );
  }

  static Future<List<Banner>> _getFallbackBannersForCategory(
      String? categoryId,
      ) async {
    if (categoryId != null) {
      return [
        Banner(
          id: 'cat_${categoryId}_1',
          imageUrls: [
            'https://via.placeholder.com/400x140?text=Category+Special',
          ],
          title: 'Special Offers',
          subtitle: 'Great deals in this category',
          folderName: 'category_fallback', // Added folderName
          link: 'category:$categoryId',
          isActive: true,
          sortOrder: 1,
        ),
      ];
    }
    return _getFallbackBanners();
  }

  static Future<List<Banner>> _getFallbackBanners() async {
    try {
      return [
        Banner(
          id: '1',
          imageUrls: ['https://via.placeholder.com/400x140?text=Banner+1'],
          title: 'Special Offers',
          subtitle: 'Great deals on your favorite items',
          folderName: '1', // Added folderName
          link: null,
          isActive: true,
          sortOrder: 1,
        ),
        Banner(
          id: '2',
          imageUrls: ['https://via.placeholder.com/400x140?text=Banner+2'],
          title: 'Fresh Arrivals',
          subtitle: 'New products just for you',
          folderName: '2', // Added folderName
          link: null,
          isActive: true,
          sortOrder: 2,
        ),
      ];
    } catch (e) {
      return [];
    }
  }

  static String getBannerImageUrl(String imageName) {
    if (imageName.isEmpty) return '';

    if (imageName.startsWith('http://') || imageName.startsWith('https://')) {
      return imageName;
    }

    if (imageName.startsWith('/')) {
      return 'https://pos.inspiredgrow.in$imageName';
    }

    return 'https://pos.inspiredgrow.in/vps/uploads/banners/$imageName';
  }

  // ========================================
  // CATEGORY HIERARCHY METHODS
  // ========================================

  static Future<List<Category>> getCategories() async {
    return await _makeRequest('categories', () async {
      final response = await _client
          .get(Uri.parse('$baseUrl/categories'))
          .timeout(_requestTimeout);
      if (response.statusCode == 200) {
        // Offload JSON decoding to an isolate to avoid blocking UI
        final data = await foundation.compute(
          // parseJsonMap is defined in isolate_operations.dart
          parseJsonMap,
          response.body,
        );
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((json) => Category.fromJson(json))
              .toList();
        }
      }
      throw Exception('Failed to load categories');
    });
  }

  static Future<List<SubCategory>> getSubCategories(String categoryId) async {
    return await _makeRequest('subcategories_$categoryId', () async {
      final url = '$baseUrl/categories/$categoryId/subcategories';

      final response =
      await _client.get(Uri.parse(url)).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final data = await foundation.compute(parseJsonMap, response.body);

        if (data['success'] == true && data['data'] != null) {
          final List<SubCategory> result = (data['data'] as List)
              .map((json) => SubCategory.fromJson(json))
              .toList();
          return result;
        }
      }
      return [];
    });
  }

  // âœ… ENHANCED: SubSubCategories with better error handling
  static Future<List<SubSubCategory>> getSubSubCategories(
      String categoryId,
      String subcategoryId,
      ) async {
    return await _makeRequest(
      'subsubcategories_${categoryId}_$subcategoryId',
          () async {
        try {
          final url =
              '$baseUrl/categories/$categoryId/subcategories/$subcategoryId/subsubcategories';

          final response = await _client
              .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
              .timeout(_requestTimeout);

          if (response.statusCode == 200) {
            final data = await foundation.compute(parseJsonMap, response.body);

            if (data['success'] == true && data['data'] != null) {
              final List<SubSubCategory> result = [];

              for (final json in data['data']) {
                try {
                  final subsubcategory = SubSubCategory.fromJson(json);
                  result.add(subsubcategory);
                } catch (e) {
                  continue; // Skip invalid items
                }
              }

              return result;
            }
          }
        } catch (e) {
          // Silently fail and return empty list for fallback to decks
        }

        return [];
      },
    );
  }

  // âœ… ENHANCED: Decks with improved error handling
  static Future<List<Deck>> getDecksView(
      String categoryId,
      String subCategoryId,
      ) async {
    return await _makeRequest('decks_${categoryId}_$subCategoryId', () async {
      try {
        final url =
            '$baseUrl/categories/$categoryId/subcategories/$subCategoryId/decks';

        final response = await _client
            .get(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        )
            .timeout(_requestTimeout);

        if (response.statusCode == 200) {
          final data = await foundation.compute(parseJsonMap, response.body);
          if (data['success'] == true && data['data'] != null) {
            return (data['data'] as List)
                .map((json) {
              try {
                return Deck.fromJson(json);
              } catch (e) {
                return null;
              }
            })
                .where((deck) => deck != null)
                .cast<Deck>()
                .toList();
          }
        }
      } catch (e) {
        // Return empty list for proper error handling
      }
      return [];
    });
  }

  static Future<List<Product>> getItemsForSubSubCategory(
      String categoryId,
      String subcategoryId,
      String subsubcategoryId, {
        int limit = 20,
      }) async {
    return await _makeRequest(
      'items_for_subsubcategory_${categoryId}_${subcategoryId}_${subsubcategoryId}_limit_$limit',
          () async {
        try {
          final url =
              '$baseUrl/categories/$categoryId/subcategories/$subcategoryId/subsubcategories/$subsubcategoryId/items';

          final response = await _client
              .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
              .timeout(_requestTimeout);

          if (response.statusCode == 200) {
            final data = json.decode(response.body);

            if (data['success'] == true && data['data'] != null) {
              final List<Product> products = (data['data'] as List)
                  .map((json) {
                try {
                  return Product.fromJson(json);
                } catch (e) {
                  return null;
                }
              })
                  .where((product) => product != null)
                  .cast<Product>()
                  .toList();

              return products.take(limit).toList();
            }
          }

          // Try alternative endpoints
          final List<String> alternativeUrls = [
            '$apiBaseUrl/items?subsubcategory_id=$subsubcategoryId&limit=$limit',
            '$apiBaseUrl/items?category_id=$categoryId&subcategory_id=$subcategoryId&subsubcategory_id=$subsubcategoryId&limit=$limit',
            '$baseUrl/items?subsubcategory=$subsubcategoryId&limit=$limit',
          ];

          for (final altUrl in alternativeUrls) {
            try {
              final altResponse = await _client
                  .get(
                Uri.parse(altUrl),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              )
                  .timeout(_requestTimeout);

              if (altResponse.statusCode == 200) {
                final altData = json.decode(altResponse.body);
                if (altData['success'] == true && altData['data'] != null) {
                  final List<Product> products = (altData['data'] as List)
                      .map((json) {
                    try {
                      return Product.fromJson(json);
                    } catch (e) {
                      return null;
                    }
                  })
                      .where((product) => product != null)
                      .cast<Product>()
                      .toList();

                  if (products.isNotEmpty) {
                    return products.take(limit).toList();
                  }
                }
              }
            } catch (e) {
              continue;
            }
          }
        } catch (e) {
          // Return empty list for proper error handling
        }

        return <Product>[];
      },
    );
  }

  static Future<List<Product>> getProductsForCategory(
      String categoryId, {
        int limit = 10,
      }) async {
    return await _makeRequest(
      'products_for_category_${categoryId}_limit_$limit',
          () async {
        try {
          final subcategories = await getSubCategories(categoryId);
          if (subcategories.isEmpty) {
            return <Product>[];
          }

          final List<Product> allProducts = [];

          for (final subcategory in subcategories.take(3)) {
            try {
              final subsubcategories = await getSubSubCategories(
                categoryId,
                subcategory.id,
              );

              if (subsubcategories.isNotEmpty) {
                for (final subsubcategory in subsubcategories.take(2)) {
                  try {
                    final products = await getItemsForSubSubCategory(
                      categoryId,
                      subcategory.id,
                      subsubcategory.id,
                      limit: 10,
                    );
                    allProducts.addAll(products);

                    if (allProducts.length >= limit) break;
                  } catch (e) {
                    continue;
                  }
                }
              } else {
                final decks = await getDecksView(categoryId, subcategory.id);
                final deckProducts =
                decks.expand((deck) => deck.items).toList();
                allProducts.addAll(deckProducts);
              }

              if (allProducts.length >= limit) break;
            } catch (e) {
              continue;
            }
          }
          return allProducts.take(limit).toList();
        } catch (e) {
          return <Product>[];
        }
      },
    );
  }

  // ========================================
  // SEARCH METHODS
  // ========================================

  static Future<List<Product>> searchProducts(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      final cleanQuery = query.trim();
      final searchUrl =
          '$apiBaseUrl/items/search?search=${Uri.encodeComponent(cleanQuery)}&limit=50';

      final response = await _client
          .get(
        Uri.parse(searchUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          final dynamic data = responseData['data'];

          if (data != null && data is List) {
            final List<Product> products = [];
            for (final item in data) {
              try {
                final product = Product.fromJson(item);
                products.add(product);
              } catch (e) {
                // Skip invalid items
              }
            }

            return _sortByRelevance(products, query);
          }
        }
      }

      return await _fallbackSearch(query);
    } catch (e) {
      return await _fallbackSearch(query);
    }
  }

  // âœ… Add this method to debug SubSubCategory image fetching

  static Future<List<Product>> _fallbackSearch(String query) async {
    try {
      final searchQuery = query.toLowerCase().trim();
      final List<Product> allProducts = [];
      final categories = await getCategories();

      for (final category in categories.take(5)) {
        try {
          final products = await getProductsForCategory(category.id, limit: 20);
          allProducts.addAll(products);
        } catch (e) {
          continue;
        }
      }

      final filteredProducts = <Product>[];

      for (final product in allProducts) {
        final productName = product.itemName.toLowerCase();
        final productBrand = product.brand.toLowerCase();
        final productDesc = product.description.toLowerCase();

        bool matches = false;

        if (productName.contains(searchQuery) ||
            productBrand.contains(searchQuery) ||
            productDesc.contains(searchQuery)) {
          matches = true;
        }

        if (!matches) {
          final queryWords = searchQuery.split(' ');
          final nameWords = productName.split(' ');

          for (final queryWord in queryWords) {
            if (queryWord.length > 2) {
              for (final nameWord in nameWords) {
                if (nameWord.contains(queryWord) ||
                    queryWord.contains(nameWord)) {
                  matches = true;
                  break;
                }
              }
              if (matches) break;
            }
          }
        }

        if (matches) {
          filteredProducts.add(product);
        }
      }

      final sortedProducts = _sortByRelevance(filteredProducts, query);
      return sortedProducts.take(20).toList();
    } catch (e) {
      return <Product>[];
    }
  }
  // Add this public method to ApiService class
  static List<String> generateImageUrlsForType(String imagePath, String imageType) {
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

    String encodedPath = _encodeImagePath(imagePath);
    String rawPath = imagePath;

    switch (imageType) {
      case 'subsubcategory':
        urls.addAll([
          '$imageBaseUrl/sub-subcategories/$encodedPath',
          '$imageBaseUrl/sub-subcategories/$rawPath',
          '$imageBaseUrl/subsubcategories/$encodedPath',
          '$imageBaseUrl/subsubcategories/$rawPath',
          '$imageBaseUrl/subcategories/$encodedPath',
          '$imageBaseUrl/subcategories/$rawPath',
          '$imageBaseUrl/$encodedPath',
          '$imageBaseUrl/$rawPath',
        ]);
        break;

      case 'deck':
        urls.addAll([
          '$imageBaseUrl/sub-subcategories/$encodedPath',
          '$imageBaseUrl/sub-subcategories/$rawPath',
          '$imageBaseUrl/decks/$encodedPath',
          '$imageBaseUrl/decks/$rawPath',
          '$imageBaseUrl/subsubcategories/$encodedPath',
          '$imageBaseUrl/subsubcategories/$rawPath',
          '$imageBaseUrl/subcategories/$encodedPath',
          '$imageBaseUrl/subcategories/$rawPath',
          '$imageBaseUrl/categories/$encodedPath',
          '$imageBaseUrl/categories/$rawPath',
          '$imageBaseUrl/$encodedPath',
          '$imageBaseUrl/$rawPath',
        ]);
        break;

      case 'item':
        urls.addAll([
          '$imageBaseUrl/qr/items/$encodedPath',
          '$imageBaseUrl/qr/items/$rawPath',
          '$imageBaseUrl/items/$encodedPath',
          '$imageBaseUrl/items/$rawPath',
          '$imageBaseUrl/$encodedPath',
          '$imageBaseUrl/$rawPath',
        ]);
        break;

      default:
        urls.addAll(['$imageBaseUrl/$encodedPath', '$imageBaseUrl/$rawPath']);
        break;
    }

    final Set<String> seen = {};
    return urls.where((url) => seen.add(url)).toList();
  }

  static Future<Product?> getProductDetails(String productId) async {
    try {
      final url = '$apiBaseUrl/items/$productId';

      final response = await _client
          .get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return Product.fromJson(data['data']);
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<Product>> searchProductsWithPrices(String query) async {
    final products = await searchProductsWithFallback(query);
    final List<Product> productsWithPrices = [];

    for (final product in products) {
      if (product.needsPriceFetch) {
        final detailedProduct = await getProductDetails(product.id);
        if (detailedProduct != null && !detailedProduct.needsPriceFetch) {
          productsWithPrices.add(detailedProduct);
        } else {
          productsWithPrices.add(
            Product(
              id: product.id,
              itemName: product.itemName,
              brand: product.brand,
              unit: product.unit,
              description: product.description,
              itemImages: product.itemImages,
              mrp: 0.0,
              salesPrice: 0.0,
              stock: product.stock, // Using existing stock from product
            ),
          );
        }
      } else {
        productsWithPrices.add(product);
      }
    }

    return productsWithPrices;
  }
  static Future<List<Product>> searchProductsWithFallback(String query) async {
    try {
      final results = await searchProducts(query);
      if (results.isNotEmpty) {
        return results;
      }
      return await _fallbackSearch(query);
    } catch (e) {
      return await _fallbackSearch(query);
    }
  }

  // ========================================
  // SEARCH HELPER METHODS
  // ========================================

  static List<Product> _sortByRelevance(List<Product> products, String query) {
    final queryLower = query.toLowerCase().trim();
    final List<MapEntry<Product, int>> scoredProducts = [];

    for (final product in products) {
      final nameLower = product.itemName.toLowerCase();
      final brandLower = product.brand.toLowerCase();
      final descLower = product.description.toLowerCase();

      int score = 0;

      if (nameLower == queryLower) score += 100;
      if (nameLower.startsWith(queryLower)) score += 80;
      if (nameLower.contains(queryLower)) score += 50;
      if (brandLower.contains(queryLower)) score += 40;
      if (descLower.contains(queryLower)) score += 30;

      final queryWords =
      queryLower.split(' ').where((word) => word.length > 1).toList();
      final nameWords =
      nameLower.split(' ').where((word) => word.length > 1).toList();

      for (final queryWord in queryWords) {
        for (final nameWord in nameWords) {
          if (nameWord == queryWord) {
            score += 30;
          } else if (nameWord.startsWith(queryWord)) {
            score += 25;
          } else if (nameWord.contains(queryWord)) {
            score += 20;
          } else if (queryWord.startsWith(nameWord) && nameWord.length > 2) {
            score += 15;
          }

          if (_isSimilarWord(queryWord, nameWord)) {
            score += 35;
          }
        }
      }

      if (score == 0) {
        if (_fuzzyMatch(nameLower, queryLower)) {
          score += 25;
        }
      }

      if (score > 0) {
        scoredProducts.add(MapEntry(product, score));
      }
    }

    scoredProducts.sort((a, b) => b.value.compareTo(a.value));
    return scoredProducts.map((entry) => entry.key).toList();
  }

  static bool _isSimilarWord(String word1, String word2) {
    final variations = {
      'maggie': ['maggi'],
      'maggi': ['maggie'],
      'tomato': ['tomato'],
      'sauce': ['sauce', 'ketchup'],
      'noodle': ['noodles'],
      'noodles': ['noodle'],
    };

    if (variations[word1]?.contains(word2) == true) return true;
    if (variations[word2]?.contains(word1) == true) return true;

    if ((word1.length - word2.length).abs() <= 1 &&
        word1.length > 3 &&
        word2.length > 3) {
      int differences = 0;
      int minLength = word1.length < word2.length ? word1.length : word2.length;

      for (int i = 0; i < minLength; i++) {
        if (word1[i] != word2[i]) differences++;
      }
      differences += (word1.length - word2.length).abs();

      return differences <= 1;
    }

    return false;
  }

  // Add this method to your ApiService class
  static Future<List<Product>> getPopularProducts({int limit = 10}) async {
    return await _makeRequest('popular_products_$limit', () async {
      try {
        final List<Product> allProducts = [];

        // Get categories first
        final categories = await getCategories();
        if (categories.isEmpty) {
          return <Product>[];
        }

        // Randomly select some categories to get variety
        final random = Math.Random();
        final selectedCategories =
        categories.take(Math.min(5, categories.length)).toList();

        for (final category in selectedCategories) {
          try {
            final subcategories = await getSubCategories(category.id);

            if (subcategories.isNotEmpty) {
              // Randomly select subcategories
              final selectedSubcats = subcategories
                  .take(Math.min(3, subcategories.length))
                  .toList();

              for (final subcategory in selectedSubcats) {
                try {
                  // Try to get products from subsubcategories first
                  final subsubcategories = await getSubSubCategories(
                    category.id,
                    subcategory.id,
                  );

                  if (subsubcategories.isNotEmpty) {
                    // Randomly select some subsubcategories
                    final selectedSubSubcats = subsubcategories
                        .take(Math.min(2, subsubcategories.length))
                        .toList();

                    for (final subsubcategory in selectedSubSubcats) {
                      try {
                        final products = await getItemsForSubSubCategory(
                          category.id,
                          subcategory.id,
                          subsubcategory.id,
                          limit: 5,
                        );
                        allProducts.addAll(products);

                        if (allProducts.length >= limit * 2)
                          break; // Get more than needed for randomization
                      } catch (e) {
                        continue;
                      }
                    }
                  } else {
                    // Fallback to decks if no subsubcategories
                    final decks = await getDecksView(
                      category.id,
                      subcategory.id,
                    );
                    final deckProducts =
                    decks.expand((deck) => deck.items).toList();
                    allProducts.addAll(deckProducts.take(5));
                  }

                  if (allProducts.length >= limit * 2) break;
                } catch (e) {
                  continue;
                }
              }
            }

            if (allProducts.length >= limit * 2) break;
          } catch (e) {
            continue;
          }
        }

        // Remove duplicates based on product ID
        final Map<String, Product> uniqueProducts = {};
        for (final product in allProducts) {
          uniqueProducts[product.id] = product;
        }

        final List<Product> finalProducts = uniqueProducts.values.toList();

        // Shuffle the products to make them random
        finalProducts.shuffle(random);

        // Return the requested number of products
        return finalProducts.take(limit).toList();
      } catch (e) {
        return <Product>[];
      }
    });
  }

  // Also add this helper method to get featured/trending products if available
  /*static Future<List<Product>> getFeaturedProducts({int limit = 8}) async {
      try {
        // Try to get featured products from API first
        final url = '$apiBaseUrl/items/featured?limit=$limit';

        final response = await _client.get(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ).timeout(_requestTimeout);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true && data['data'] != null) {
            return (data['data'] as List)
                .map((json) {
              try {
                return Product.fromJson(json);
              } catch (e) {
                return null;
              }
            })
                .where((product) => product != null)
                .cast<Product>()
                .toList();
          }
        }

        // Fallback to popular products if featured endpoint doesn't exist
        return await getPopularProducts(limit: limit);
      } catch (e) {
        // Fallback to popular products
        return await getPopularProducts(limit: limit);
      }
    }*/

  static bool _fuzzyMatch(String text, String query) {
    if (query.length < 3) return false;

    int matches = 0;
    for (int i = 0; i < query.length; i++) {
      if (text.contains(query[i])) matches++;
    }

    return (matches / query.length) >= 0.7;
  }

  static Future<Product> getProduct(String productId) async {
    try {
      final userData = UserData();
      final token = userData.getToken(); // Retrieve the token from UserData

      if (token == null) {
        throw Exception('No authentication token available. Please log in.');
      }

      final url =
          '$apiBaseUrl/items/$productId'; // Changed from /product to /items
      final response = await _client
          .get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization':
          'Bearer $token', // Add the token to the Authorization header
        },
      )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        foundation.debugPrint('ðŸ” Fetched product $productId: $json');
        return Product.fromJson(
          json['data'] ?? json,
        ); // Adjust if response wraps data in 'data'
      } else {
        throw Exception(
          'Failed to load product $productId: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      foundation.debugPrint('ðŸš¨ Error fetching product $productId: $e');
      throw e;
    }
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
            'expires_in':
            _cacheExpiry.inMinutes - now.difference(timestamp).inMinutes,
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

  static Map<String, dynamic> validateConfiguration() {
    return {
      'base_url': baseUrl,
      'api_base_url': apiBaseUrl,
      'image_base_url': imageBaseUrl,
      'request_timeout_seconds': _requestTimeout.inSeconds,
      'cache_expiry_minutes': _cacheExpiry.inMinutes,
      'client_initialized': _client.toString().contains('Client'),
      'cache_initialized': _cache is Map,
      'cache_timestamps_initialized': _cacheTimestamps is Map,
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

  // ========================================
  // TRENDING TILES API METHOD
  // ========================================

  static Future<Map<String, dynamic>> getTrendingTiles() async {
    return await _makeRequest('trending_tiles', () async {
      try {
        final response = await _client.get(
          Uri.parse(Base2Url),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ).timeout(_requestTimeout);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data;
        } else {
          foundation
              .debugPrint('Trending tiles API error: ${response.statusCode}');
          throw Exception('Failed to load trending tiles');
        }
      } catch (e) {
        foundation.debugPrint('Error fetching trending tiles: $e');
        rethrow;
      }
    });
  }
}