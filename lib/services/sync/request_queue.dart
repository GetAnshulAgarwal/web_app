import 'dart:convert';
import 'package:hive/hive.dart';

/// Minimal persistent request queue. Stores serialized requests in Hive so they
/// survive app restarts and can be replayed when network is available.
class RequestQueue {
  static const String _boxName = 'request_queue_box';

  late final Box _box;

  RequestQueue._(this._box);

  static Future<RequestQueue> init() async {
    final box = await Hive.openBox(_boxName);
    return RequestQueue._(box);
  }

  Future<void> enqueue(String id, Map<String, dynamic> request) async {
    await _box.put(id, json.encode(request));
  }

  List<Map<String, dynamic>> all() {
    return _box.values
        .map((v) {
          try {
            return Map<String, dynamic>.from(json.decode(v as String));
          } catch (_) {
            return <String, dynamic>{};
          }
        })
        .where((m) => m.isNotEmpty)
        .toList();
  }

  Future<void> remove(String id) async {
    await _box.delete(id);
  }

  Future<void> clear() async {
    await _box.clear();
  }
}
