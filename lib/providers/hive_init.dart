import 'dart:math';
import 'dart:typed_data';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Initializes Hive and opens commonly used boxes. Also prepares a persistent
/// encryption key for the checkout encrypted box. NOTE: For production, store
/// the encryption key in a secure store such as `flutter_secure_storage`.
Future<void> initHive() async {
  await Hive.initFlutter();

  // Open a small box to hold app keys (encryption key bootstrap)
  final keysBox = await Hive.openBox('app_keys');

  // Generate a 32-byte key if none exists
  if (!keysBox.containsKey('checkout_encryption_key')) {
    final rnd = Random.secure();
    final key = Uint8List.fromList(
      List<int>.generate(32, (_) => rnd.nextInt(256)),
    );
    await keysBox.put('checkout_encryption_key', key);
  }

  // Ensure main cache boxes exist (will be used by CacheManager)
  await Hive.openBox('home_cache_box');
  await Hive.openBox('cache_metadata_box');
  // checkout_cache_box will be opened by CacheManager with the encryption key
}
