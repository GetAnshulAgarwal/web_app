import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/home/product_model.dart';
import 'home/api_service.dart';

class SearchService {
  static const String _recentSearchesKey = 'recent_searches';
  static const int _maxRecentSearches = 10;

  // ✅ UPDATED: Reduced cache duration to 5 seconds
  static final Map<String, List<Product>> _searchCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(seconds: 5); // ✅ Changed from 5 minutes to 5 seconds

  static final List<String> _popularSearches = [
    'RICE',
    'DAL',
    'MAGGIE',
    'Sauce',
    'cell',
    'sweets',
  ];

  // Get popular searches
  static List<String> getPopularSearches() => _popularSearches;

  // ✅ Check if cache is still valid (5 seconds)
  static bool _isCacheValid(String key) {
    if (!_cacheTimestamps.containsKey(key)) return false;
    final age = DateTime.now().difference(_cacheTimestamps[key]!);
    return age < _cacheDuration;
  }

  // ✅ Optimized search with 5-second caching
  static Future<List<Product>> searchProducts(String query) async {
    if (query.trim().isEmpty) return [];

    final cacheKey = query.toLowerCase().trim();

    // Return cached results if valid (within 5 seconds)
    if (_isCacheValid(cacheKey) && _searchCache.containsKey(cacheKey)) {
      debugPrint('✅ Returning cached results for: $query (age: ${DateTime.now().difference(_cacheTimestamps[cacheKey]!).inSeconds}s)');
      return _searchCache[cacheKey]!;
    }

    // Fetch fresh data
    debugPrint('🔍 Fetching fresh results for: $query (cache expired or not found)');
    final results = await ApiService.searchProductsWithPrices(query);

    // Cache the results with timestamp
    _searchCache[cacheKey] = results;
    _cacheTimestamps[cacheKey] = DateTime.now();

    // Clean up old cache entries
    _cleanupExpiredCache();

    return results;
  }

  // ✅ NEW: Clean up expired cache entries automatically
  static void _cleanupExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    _cacheTimestamps.forEach((key, timestamp) {
      if (now.difference(timestamp) >= _cacheDuration) {
        expiredKeys.add(key);
      }
    });

    for (final key in expiredKeys) {
      _searchCache.remove(key);
      _cacheTimestamps.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      debugPrint('🧹 Cleaned up ${expiredKeys.length} expired cache entries');
    }
  }

  // ✅ NEW: Manual cache clear method
  static void clearCache() {
    _searchCache.clear();
    _cacheTimestamps.clear();
    debugPrint('🧹 All search cache cleared manually');
  }

  // ✅ NEW: Get cache statistics (for debugging)
  static Map<String, dynamic> getCacheStats() {
    final now = DateTime.now();
    final validEntries = _cacheTimestamps.entries
        .where((entry) => now.difference(entry.value) < _cacheDuration)
        .length;

    return {
      'total_entries': _searchCache.length,
      'valid_entries': validEntries,
      'expired_entries': _searchCache.length - validEntries,
      'cache_duration_seconds': _cacheDuration.inSeconds,
    };
  }

  // Load recent searches from SharedPreferences
  static Future<List<String>> getRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_recentSearchesKey) ?? [];
    } catch (e) {
      return [];
    }
  }

  // Save a search term to recent searches
  static Future<void> saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> recentSearches =
          prefs.getStringList(_recentSearchesKey) ?? [];

      // Remove if already exists
      recentSearches.remove(query);
      // Add to beginning
      recentSearches.insert(0, query);
      // Keep only max items
      if (recentSearches.length > _maxRecentSearches) {
        recentSearches = recentSearches.take(_maxRecentSearches).toList();
      }

      await prefs.setStringList(_recentSearchesKey, recentSearches);
    } catch (e) {
      // Handle error silently
    }
  }

  // Clear all recent searches
  static Future<void> clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
    } catch (e) {
      // Handle error silently
    }
  }

  // Generate search suggestions based on query
  static List<String> generateSuggestions(
      String query,
      List<String> recentSearches,
      ) {
    if (query.trim().isEmpty) return [];

    final suggestions = <String>[];
    final lowerQuery = query.toLowerCase();

    // Add matching popular searches
    for (final popular in _popularSearches) {
      if (popular.toLowerCase().contains(lowerQuery) &&
          suggestions.length < 5) {
        suggestions.add(popular);
      }
    }

    // Add matching recent searches
    for (final recent in recentSearches) {
      if (recent.toLowerCase().contains(lowerQuery) &&
          !suggestions.contains(recent) &&
          suggestions.length < 8) {
        suggestions.add(recent);
      }
    }

    return suggestions;
  }
}