import 'package:flutter/foundation.dart';

class CacheStrategy {
  /// Returns true if the cached item is stale based on [cachedAt] and [ttl].
  static bool isStale(DateTime cachedAt, Duration ttl) {
    try {
      return DateTime.now().difference(cachedAt) > ttl;
    } catch (e) {
      if (kDebugMode) print('CacheStrategy.isStale error: $e');
      return true;
    }
  }

  /// Compute expiration date for a given ttl.
  static DateTime expiresAt(Duration ttl) => DateTime.now().add(ttl);
}
