import 'dart:convert';
import 'package:hive/hive.dart';
import '../../model/cache/cache_metadata.dart';

/// Simple cache manager backed by Hive boxes.
///
/// NOTE: This implementation focuses on correctness and extensibility. It
/// intentionally keeps compression/delta-sync out of the first iteration and
/// provides clear extension points. For stronger encryption of the checkout
/// box, integrate `flutter_secure_storage` to hold the encryption key.
class CacheManager {
  static const String homeBoxName = 'home_cache_box';
  static const String checkoutBoxName = 'checkout_cache_box';
  static const String metadataBoxName = 'cache_metadata_box';

  static CacheManager? _instance;

  final Box _homeBox;
  final Box _checkoutBox;
  final Box _metaBox;

  CacheManager._(this._homeBox, this._checkoutBox, this._metaBox);

  static Future<CacheManager> init() async {
    if (_instance != null) return _instance!;

    final home = await Hive.openBox(homeBoxName);
    final checkout = await Hive.openBox(checkoutBoxName);
    final meta = await Hive.openBox(metadataBoxName);

    _instance = CacheManager._(home, checkout, meta);
    return _instance!;
  }

  /// Save JSON-serializable [value] under [key] in the specified [boxName].
  /// Also stores CacheMetadata for TTL checks.
  Future<void> save(
    String boxName,
    String key,
    dynamic value,
    DateTime expiresAt, {
    int version = 1,
    String checksum = '',
  }) async {
    final serialized = json.encode(value);
    final box = _boxForName(boxName);
    if (box == null) return;

    await box.put(key, serialized);

    final meta = CacheMetadata(
      key: key,
      cachedAt: DateTime.now(),
      expiresAt: expiresAt,
      version: version,
      checksum: checksum,
    );

    await _metaBox.put(key, meta.toJson());
  }

  /// Read cached item and decode JSON. Returns null if not found or decode fails.
  dynamic read(String boxName, String key) {
    final box = _boxForName(boxName);
    if (box == null) return null;

    final raw = box.get(key);
    if (raw == null) return null;
    try {
      return json.decode(raw as String);
    } catch (e) {
      // Corrupted cache - remove entry and return null
      box.delete(key);
      _metaBox.delete(key);
      return null;
    }
  }

  CacheMetadata? metadata(String key) {
    final raw = _metaBox.get(key);
    if (raw == null) return null;
    try {
      return CacheMetadata.fromJson(Map<String, dynamic>.from(raw));
    } catch (e) {
      _metaBox.delete(key);
      return null;
    }
  }

  Future<void> delete(String boxName, String key) async {
    final box = _boxForName(boxName);
    if (box == null) return;
    await box.delete(key);
    await _metaBox.delete(key);
  }

  Box? _boxForName(String name) {
    switch (name) {
      case homeBoxName:
        return _homeBox;
      case checkoutBoxName:
        return _checkoutBox;
      default:
        return null;
    }
  }

  /// Basic cleanup: remove entries older than [maxAge].
  Future<void> cleanupOlderThan(Duration maxAge) async {
    final now = DateTime.now();
    final keys = _metaBox.keys.cast<String>().toList();
    for (final key in keys) {
      try {
        final meta = CacheMetadata.fromJson(
          Map<String, dynamic>.from(_metaBox.get(key)),
        );
        if (now.difference(meta.cachedAt) > maxAge) {
          await delete(homeBoxName, key);
        }
      } catch (_) {
        await _metaBox.delete(key);
      }
    }
  }
}
