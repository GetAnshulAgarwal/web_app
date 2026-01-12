import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class BookingProvider extends ChangeNotifier {
  static const String _pendingBox = 'pending_bookings';
  static const String _completedBox = 'completed_bookings';

  Box? _pending;
  Box? _completed;

  List<Map<String, dynamic>> get pendingBookings =>
      _pending?.values.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];

  List<Map<String, dynamic>> get completedBookings =>
      _completed?.values.map((e) => Map<String, dynamic>.from(e)).toList() ??
      [];

  /// Ensure boxes are open (idempotent).
  Future<void> _ensureBoxes() async {
    if (_pending == null || !_pending!.isOpen) {
      _pending = await Hive.openBox(_pendingBox);
    }
    if (_completed == null || !_completed!.isOpen) {
      _completed = await Hive.openBox(_completedBox);
    }
  }

  /// Replace all pending bookings with the provided list (useful after sync).
  Future<void> savePendingBookings(List<Map<String, dynamic>> bookings) async {
    await _ensureBoxes();
    await _pending!.clear();
    for (var b in bookings) {
      final id =
          b['_id'] ??
          b['id'] ??
          DateTime.now().millisecondsSinceEpoch.toString();
      await _pending!.put(id.toString(), b);
    }
    notifyListeners();
  }

  /// Accepts a dynamic list returned by API or models. Tries to convert each
  /// item to a Map. Useful when you have List<UserBooking> or List<Map>.
  Future<void> savePendingFromDynamicList(List<dynamic> bookings) async {
    await _ensureBoxes();
    await _pending!.clear();
    for (var item in bookings) {
      Map<String, dynamic> map;
      if (item is Map<String, dynamic>) {
        map = item;
      } else {
        try {
          // Try model.toJson()
          map = Map<String, dynamic>.from((item as dynamic).toJson());
        } catch (e) {
          // Fallback: attempt basic fields
          map = {
            '_id':
                (item as dynamic).id ??
                (item as dynamic).bookingId ??
                DateTime.now().millisecondsSinceEpoch.toString(),
            'status': (item as dynamic).status ?? '',
            'createdAt':
                (item as dynamic).createdAt?.toString() ??
                DateTime.now().toIso8601String(),
          };
        }
      }

      final id =
          map['_id'] ??
          map['id'] ??
          DateTime.now().millisecondsSinceEpoch.toString();
      await _pending!.put(id.toString(), map);
    }
    notifyListeners();
  }

  /// Save a list of completed bookings coming from API or models.
  Future<void> saveCompletedFromDynamicList(List<dynamic> bookings) async {
    await _ensureBoxes();
    await _completed!.clear();
    print('Saving ${bookings.length} completed bookings to local storage.');

    for (var item in bookings) {
      Map<String, dynamic> map;

      // Rich debug: attempt to print the full shape of the incoming booking item.
      try {
        if (item is Map<String, dynamic>) {
          map = item;
          print('Debug: booking item is Map => $map');
        } else {
          // Try model.toJson() first
          try {
            map = Map<String, dynamic>.from((item as dynamic).toJson());
            print('Debug: booking item.toJson() => $map');
          } catch (e) {
            // toJson() not available or failed: extract common fields as fallback
            final dyn = item as dynamic;
            final extractedId =
                dyn.id ?? dyn._id ?? dyn.bookingId ?? dyn.booking_id;
            final extractedStatus =
                dyn.status ?? dyn.bookingStatus ?? dyn.booking_status;
            String? extractedCreated;
            try {
              extractedCreated =
                  dyn.createdAt?.toString() ?? dyn.created_at?.toString();
            } catch (_) {
              extractedCreated = null;
            }

            dynamic extractedPickup;
            try {
              extractedPickup =
                  dyn.pickupAddress ??
                  dyn.pickup_address ??
                  dyn.pickup ??
                  dyn.address;
            } catch (_) {
              extractedPickup = null;
            }

            map = {
              '_id':
                  extractedId ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
              'status': extractedStatus ?? '',
              'createdAt': extractedCreated ?? DateTime.now().toIso8601String(),
            };
            if (extractedPickup != null) map['pickupAddress'] = extractedPickup;

            print('Debug: booking item (extracted) => $map');
            print(
              'Debug: original runtimeType=${item.runtimeType}, toString=${(item as dynamic).toString()}',
            );
          }
        }
      } catch (e) {
        // Last-resort guard: ensure we still persist a minimal map
        print(
          'Debug: failed to inspect booking item: $e, runtimeType=${item.runtimeType}',
        );
        map = {
          '_id': DateTime.now().millisecondsSinceEpoch.toString(),
          'status': '',
          'createdAt': DateTime.now().toIso8601String(),
        };
      }
      final id =
          map['_id'] ??
          map['id'] ??
          DateTime.now().millisecondsSinceEpoch.toString();
      await _completed!.put(id.toString(), map);
    }
    notifyListeners();
  }

  /// Add or update a single pending booking
  Future<void> upsertPendingBooking(Map<String, dynamic> booking) async {
    await _ensureBoxes();
    final id =
        booking['_id'] ??
        booking['id'] ??
        DateTime.now().millisecondsSinceEpoch.toString();
    await _pending!.put(id.toString(), booking);
    notifyListeners();
  }

  /// Move a booking from pending -> completed (by id). Returns true if moved.
  Future<bool> markBookingCompleted(String id) async {
    await _ensureBoxes();
    final key = id.toString();
    if (!_pending!.containsKey(key)) return false;
    final booking = Map<String, dynamic>.from(_pending!.get(key));
    // Optionally set completedAt
    booking['completedAt'] = DateTime.now().toIso8601String();
    await _completed!.put(key, booking);
    await _pending!.delete(key);
    notifyListeners();
    return true;
  }

  /// Save a completed booking directly
  Future<void> saveCompletedBooking(Map<String, dynamic> booking) async {
    await _ensureBoxes();
    final id =
        booking['_id'] ??
        booking['id'] ??
        DateTime.now().millisecondsSinceEpoch.toString();
    await _completed!.put(id.toString(), booking);
    // If it's present in pending, remove it
    await _pending?.delete(id.toString());
    notifyListeners();
  }

  /// Load both boxes into memory (noop because getters read boxes on demand)
  Future<void> load() async {
    await _ensureBoxes();
    notifyListeners();
  }

  /// Clear all local cached bookings
  Future<void> clearAll() async {
    await _ensureBoxes();
    await _pending!.clear();
    await _completed!.clear();
    notifyListeners();
  }
}
