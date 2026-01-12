import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:io';
// Note: NetworkTest utilities exist at lib/Utils/network_test.dart. We use a
// small InternetAddress lookup here to detect connectivity without requiring
// a public helper.
import 'request_queue.dart';

/// Lightweight sync manager that processes queued requests when network is available.
class SyncManager {
  final RequestQueue _queue;
  Timer? _periodicTimer;

  SyncManager._(this._queue);

  static Future<SyncManager> init() async {
    final q = await RequestQueue.init();
    final mgr = SyncManager._(q);
    return mgr;
  }

  /// Start a simple periodic processor (placeholder for WorkManager integration).
  void start({Duration interval = const Duration(minutes: 5)}) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) => _processIfOnline());
  }

  void stop() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  Future<void> _processIfOnline() async {
    try {
      // Quick network check - simple lookup instead of private helper
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty) {
        if (kDebugMode) print('SyncManager: DNS lookup returned empty');
        return;
      }
    } catch (e) {
      if (kDebugMode) print('SyncManager: offline, skipping sync: $e');
      return;
    }

    final items = _queue.all();
    for (final item in items) {
      try {
        // Placeholder: invoke request handler
        if (kDebugMode) print('SyncManager: would process ${item}');
        // After successful processing remove from queue by a known id
        // TODO: implement actual request replay and remove on success
      } catch (e) {
        if (kDebugMode) print('SyncManager: failed to process item: $e');
      }
    }
  }
}
