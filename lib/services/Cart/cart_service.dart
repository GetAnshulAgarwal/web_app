// lib/services/cart_service.dart
// Complete CartService with integrated delivery slots and delivery settings
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../authentication/user_data.dart';
import '../cache/cache_manager.dart';
import '../cache/isolate_operations.dart';

class CartService {
  static const String baseUrl = 'https://pos.inspiredgrow.in/vps/cart';
  static const String itemsApiUrl =
      'https://pos.inspiredgrow.in/vps/customer/items';
  static const String imageBaseUrl =
      'https://pos.inspiredgrow.in/vps/uploads/qr/items/';
  static const String deliverySlotsApiUrl =
      'https://pos.inspiredgrow.in/vps/api/delivery/slot/active';
  // NEW: Delivery settings API
  static const String deliverySettingsApiUrl =
      'https://pos.inspiredgrow.in/vps/deliverysettings';

  static final UserData _userData = UserData();

  // Static caches for ultra-fast access
  static Map<String, Map<String, dynamic>>? _itemsLookup;
  static DateTime? _itemsLookupTimestamp;
  static const Duration _cacheExpiration = Duration(minutes: 15);

  // Cache for delivery slots
  static List<Map<String, dynamic>>? _deliverySlots;
  static DateTime? _deliverySlotsTimestamp;
  static const Duration _slotsCacheExpiration = Duration(minutes: 30);

  // NEW: Cache for delivery settings
  static Map<String, dynamic>? _deliverySettings;
  static DateTime? _deliverySettingsTimestamp;
  static const Duration _deliverySettingsCacheExpiration = Duration(
    minutes: 30,
  );

  // Pre-computed headers to avoid async calls
  static Map<String, String>? _cachedHeaders;
  static DateTime? _headersTimestamp;

  static Future<Map<String, String>> _getHeaders() async {
    if (_cachedHeaders != null &&
        _headersTimestamp != null &&
        DateTime.now().difference(_headersTimestamp!) < Duration(minutes: 5)) {
      return _cachedHeaders!;
    }

    final token = _userData.getToken();
    _cachedHeaders = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
    _headersTimestamp = DateTime.now();
    return _cachedHeaders!;
  }

  // Ultra-fast image URL construction
  static String _constructImageUrl(String? imagePath) {
    return (imagePath?.isEmpty ?? true) ? '' : '$imageBaseUrl$imagePath';
  }

  // Optimized image URL extraction
  static List<String> _getImageUrls(dynamic itemImages) {
    if (itemImages is! List || itemImages.isEmpty) return const [];

    final List<String> urls = [];
    for (int i = 0; i < itemImages.length; i++) {
      final image = itemImages[i];
      if (image != null) {
        final imageStr = image.toString();
        if (imageStr.isNotEmpty) {
          urls.add('$imageBaseUrl$imageStr');
        }
      }
    }
    return urls;
  }

  static bool isAuthenticated() {
    return _userData.isLoggedIn() && _userData.getToken() != null;
  }

  // Build items lookup map for O(1) access
  static Future<Map<String, Map<String, dynamic>>> _getItemsLookup() async {
    if (_itemsLookup != null &&
        _itemsLookupTimestamp != null &&
        DateTime.now().difference(_itemsLookupTimestamp!) < _cacheExpiration) {
      return _itemsLookup!;
    }

    try {
      final response = await http
          .get(Uri.parse(itemsApiUrl))
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = await compute(parseJson, response.body);

        List<dynamic> items = [];
        if (responseData is Map<String, dynamic>) {
          items =
              responseData['data'] as List<dynamic>? ??
                  responseData['items'] as List<dynamic>? ??
                  [];
        } else if (responseData is List) {
          items = responseData;
        }

        final lookup = <String, Map<String, dynamic>>{};
        for (int i = 0; i < items.length; i++) {
          final item = items[i] as Map<String, dynamic>;
          final itemId = item['_id']?.toString();
          if (itemId != null) {
            lookup[itemId] = item;
          }
        }

        _itemsLookup = lookup;
        _itemsLookupTimestamp = DateTime.now();

        return lookup;
      }
    } catch (e) {
      print('Error fetching items lookup: $e');
    }

    return _itemsLookup ?? {};
  }

  // Process cart item data
  static Map<String, dynamic> _processCartItem(
      Map<String, dynamic> cartItem,
      Map<String, Map<String, dynamic>> itemsLookup,
      ) {
    final itemData = cartItem['item'] as Map<String, dynamic>? ?? {};
    final productId = itemData['_id']?.toString() ?? '';

    final quantityRaw = cartItem['quantity'];
    final salesPriceRaw = itemData['salesPrice'];

    final double quantity =
    quantityRaw is num
        ? quantityRaw.toDouble()
        : (double.tryParse(quantityRaw?.toString() ?? '') ?? 0.0);

    final double salesPrice =
    salesPriceRaw is num
        ? salesPriceRaw.toDouble()
        : (double.tryParse(salesPriceRaw?.toString() ?? '') ?? 0.0);

    final fullProductData = itemsLookup[productId] ?? const <String, dynamic>{};
    final imageUrls = _getImageUrls(fullProductData['itemImages']);
    final primaryImageUrl = imageUrls.isNotEmpty ? imageUrls[0] : '';

    return {
      'id': (cartItem['_id'] ?? '').toString(),
      'itemId': productId,
      'itemName':
      fullProductData['itemName'] ??
          itemData['itemName'] ??
          'Unknown Product',
      'itemCode': fullProductData['itemCode'] ?? itemData['itemCode'] ?? '',
      'itemImage': primaryImageUrl,
      'itemImages': imageUrls,
      'price': (fullProductData['mrp'] as num?)?.toDouble() ?? salesPrice,
      'salesPrice': salesPrice,
      'unit': fullProductData['unit'] ?? '',
      'brand': fullProductData['brand'] ?? '',
      'quantity': quantity.toInt(),
      'totalPrice': salesPrice * quantity,
      'addedAt': (cartItem['addedAt'] ?? '').toString(),
      'quantityForTotal': quantity,
    };
  }

  // ============== DELIVERY SETTINGS METHODS ==============

  /// Fetch delivery settings from the API
  static Future<Map<String, dynamic>> getDeliverySettings({
    bool forceRefresh = false,
  }) async {
    if (!isAuthenticated()) {
      return {'error': 'Please login to view delivery settings'};
    }

    // Return cached settings if available and not expired
    if (!forceRefresh &&
        _deliverySettings != null &&
        _deliverySettingsTimestamp != null &&
        DateTime.now().difference(_deliverySettingsTimestamp!) <
            _deliverySettingsCacheExpiration) {
      return {'success': true, 'data': _deliverySettings!, 'cached': true};
    }

    try {
      final headers = await _getHeaders();
      print('Fetching delivery settings from: $deliverySettingsApiUrl');

      final response = await http
          .get(Uri.parse(deliverySettingsApiUrl), headers: headers)
          .timeout(Duration(seconds: 15));

      print('Delivery settings response status: ${response.statusCode}');
      print('Delivery settings response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = await compute(parseJson, response.body);

        if (responseData is Map<String, dynamic> &&
            responseData['success'] == true) {
          final settingsData = responseData['data'] as Map<String, dynamic>;

          // Cache the settings
          _deliverySettings = settingsData;
          _deliverySettingsTimestamp = DateTime.now();

          return {'success': true, 'data': settingsData, 'cached': false};
        } else {
          return {'error': 'Invalid delivery settings response format'};
        }
      } else if (response.statusCode == 401) {
        _cachedHeaders = null;
        return {'error': 'Please login again'};
      } else {
        return {
          'error': 'Failed to load delivery settings (${response.statusCode})',
        };
      }
    } catch (e) {
      print('Error fetching delivery settings: $e');
      return {
        'error': 'Network error occurred while fetching delivery settings: $e',
      };
    }
  }

  /// Calculate delivery fee based on cart total and delivery settings
  static Future<Map<String, dynamic>> calculateDeliveryFee(
      double cartTotal,
      ) async {
    try {
      final settingsResult = await getDeliverySettings();

      if (settingsResult['error'] != null) {
        // Return default values if settings fetch fails
        return {
          'deliveryFee': 0.0,
          'handlingFee': 0.0,
          'totalAdditionalCharges': 0.0,
          'isFreeDelivery': true,
          'thresholdMessage': 'Unable to fetch delivery settings',
          'error': settingsResult['error'],
        };
      }

      final settings = settingsResult['data'] as Map<String, dynamic>;
      final isActive = settings['isActive'] ?? true;

      if (!isActive) {
        return {
          'deliveryFee': 0.0,
          'handlingFee': 0.0,
          'totalAdditionalCharges': 0.0,
          'isFreeDelivery': true,
          'thresholdMessage': 'Free delivery',
        };
      }

      final thresholdAmount =
          (settings['deliveryThresholdAmount'] as num?)?.toDouble() ?? 0.0;
      final deliveryFeeUnderThreshold =
          (settings['deliveryFeeUnderThreshold'] as num?)?.toDouble() ?? 0.0;
      final handlingFee = (settings['handlingFee'] as num?)?.toDouble() ?? 0.0;
      final deliveryFeeName = settings['deliveryFeeName'] ?? 'Delivery Charge';
      final handlingFeeName = settings['handlingFeeName'] ?? 'Processing Fee';
      final thresholdMessage =
          settings['thresholdMessage'] ??
              'Free delivery on orders above ₹$thresholdAmount';

      // Check if cart total meets threshold for free delivery
      final isFreeDelivery = cartTotal >= thresholdAmount;
      final deliveryFee = isFreeDelivery ? 0.0 : deliveryFeeUnderThreshold;
      final totalAdditionalCharges = deliveryFee + handlingFee;

      return {
        'deliveryFee': deliveryFee,
        'handlingFee': handlingFee,
        'totalAdditionalCharges': totalAdditionalCharges,
        'isFreeDelivery': isFreeDelivery,
        'thresholdAmount': thresholdAmount,
        'deliveryFeeName': deliveryFeeName,
        'handlingFeeName': handlingFeeName,
        'thresholdMessage': thresholdMessage,
        'amountNeededForFreeDelivery':
        isFreeDelivery ? 0.0 : (thresholdAmount - cartTotal),
      };
    } catch (e) {
      print('Error calculating delivery fee: $e');
      return {
        'deliveryFee': 0.0,
        'handlingFee': 0.0,
        'totalAdditionalCharges': 0.0,
        'isFreeDelivery': true,
        'thresholdMessage': 'Error calculating delivery fee',
        'error': e.toString(),
      };
    }
  }

  /// Clear delivery settings cache
  static void clearDeliverySettingsCache() {
    _deliverySettings = null;
    _deliverySettingsTimestamp = null;
  }

  // Ultra-optimized getCart method
  static Future<Map<String, dynamic>?> getCart() async {
    if (!isAuthenticated()) {
      return {'error': 'Please login to view your cart'};
    }

    try {
      final headers = await _getHeaders();

      final cartFuture = http
          .get(Uri.parse(baseUrl), headers: headers)
          .timeout(Duration(seconds: 15));

      final itemsLookupFuture = _getItemsLookup();

      final results = await Future.wait([cartFuture, itemsLookupFuture]);
      final cartResponse = results[0] as http.Response;
      final itemsLookup = results[1] as Map<String, Map<String, dynamic>>;

      if (cartResponse.statusCode != 200) {
        return {'error': 'Failed to load cart (${cartResponse.statusCode})'};
      }

      final responseData =
      await compute(parseJson, cartResponse.body) as Map<String, dynamic>;
      final cartItemsList = responseData['cartItems'] as List<dynamic>? ?? [];

      final totalBillRaw = responseData['totalBill'];
      final double totalBill =
      totalBillRaw is num
          ? totalBillRaw.toDouble()
          : (double.tryParse(totalBillRaw?.toString() ?? '') ?? 0.0);

      final processedItems = <Map<String, dynamic>>[];
      double totalQuantity = 0.0;

      for (int i = 0; i < cartItemsList.length; i++) {
        final cartItem = cartItemsList[i] as Map<String, dynamic>;
        final processedItem = _processCartItem(cartItem, itemsLookup);

        totalQuantity += processedItem['quantityForTotal'] as double;
        processedItem.remove('quantityForTotal');

        processedItems.add(processedItem);
      }

      return {
        'success': true,
        'data': {
          'items': processedItems,
          'totalAmount': totalBill,
          'totalItems': totalQuantity,
        },
      };
    } catch (e) {
      print('Error in getCart: $e');
      return {'error': 'Network error occurred'};
    }
  }

  // ============== DELIVERY SLOTS METHODS ==============

  static Future<Map<String, dynamic>> getDeliverySlots({
    bool forceRefresh = false,
  }) async {
    if (!isAuthenticated()) {
      return {'error': 'Please login to view delivery slots'};
    }

    if (!forceRefresh &&
        _deliverySlots != null &&
        _deliverySlotsTimestamp != null &&
        DateTime.now().difference(_deliverySlotsTimestamp!) <
            _slotsCacheExpiration) {
      return {
        'success': true,
        'data': {'slots': _deliverySlots!, 'cached': true},
      };
    }

    try {
      final headers = await _getHeaders();
      print('Fetching delivery slots from: $deliverySlotsApiUrl');

      final response = await http
          .get(Uri.parse(deliverySlotsApiUrl), headers: headers)
          .timeout(Duration(seconds: 15));

      print('Delivery slots response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = await compute(parseJson, response.body);

        List<dynamic> slots = [];
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data') &&
              responseData['data'] is List) {
            slots = responseData['data'] as List<dynamic>;
          } else if (responseData.containsKey('slots') &&
              responseData['slots'] is List) {
            slots = responseData['slots'] as List<dynamic>;
          }
        } else if (responseData is List) {
          slots = responseData;
        }

        if (slots.isEmpty) {
          return {
            'success': true,
            'data': {
              'slots': <Map<String, dynamic>>[],
              'cached': false,
              'message': 'No time slots configured in the system',
            },
          };
        }

        final processedSlots = _processDeliverySlots(slots);

        _deliverySlots = processedSlots;
        _deliverySlotsTimestamp = DateTime.now();

        return {
          'success': true,
          'data': {'slots': processedSlots, 'cached': false},
        };
      } else if (response.statusCode == 401) {
        _cachedHeaders = null;
        return {'error': 'Please login again'};
      } else {
        return {
          'error': 'Failed to load delivery slots (${response.statusCode})',
        };
      }
    } catch (e) {
      print('Error fetching delivery slots: $e');
      return {
        'error': 'Network error occurred while fetching delivery slots: $e',
      };
    }
  }

  static List<Map<String, dynamic>> _processDeliverySlots(
      List<dynamic> rawSlots,
      ) {
    final List<Map<String, dynamic>> processedSlots = [];
    final today = DateTime.now(); // 'today' now includes time

    for (int dayOffset = 0; dayOffset <= 2; dayOffset++) {
    final targetDate = today.add(Duration(days: dayOffset));
    final dateString = targetDate.toIso8601String().split('T')[0];

      for (final slot in rawSlots) {
        if (slot is Map<String, dynamic>) {
          // Pass full DateTime objects for comparison
          final processedSlot = _processIndividualSlotForDate(
            slot,
            targetDate, // Pass the full DateTime for the slot's day
            dateString,
            today, // Pass the current DateTime ("now")
          );
          if (processedSlot != null) {
            processedSlots.add(processedSlot);
          }
        }
      }
    }

    processedSlots.sort((a, b) {
      final dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime.now();
      final dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime.now();

      if (dateA.isAtSameMomentAs(dateB)) {
        final timeA = a['startTime'] ?? '';
        final timeB = b['startTime'] ?? '';
        return _compareTimeStrings(timeA, timeB);
      }

      return dateA.compareTo(dateB);
    });

    return processedSlots;
  }

  static Map<String, dynamic>? _processIndividualSlotForDate(
      Map<String, dynamic> slot,
      DateTime targetDate, // The full date of the slot (e.g., 2025-11-18 00:00)
      String targetDateString, // The date as "YYYY-MM-DD"
      DateTime now, // The current date and time
      ) {
    try {
      final slotId = slot['_id']?.toString() ?? slot['id']?.toString() ?? '';
      final startTime = slot['startTime']?.toString() ?? '';
      final endTime = slot['endTime']?.toString() ?? '';
      final fee = slot['fee'] ?? 0;
      final bool isActiveFromApi = slot['active'] ?? false;

      if (slotId.isEmpty || startTime.isEmpty || !isActiveFromApi) {
        // If no ID, no start time, or explicitly inactive, skip it.
        return null;
      }

      final DateTime slotStartDateTime = _parseSlotDateTime(targetDate, startTime);

      final Duration bookingBuffer = Duration(minutes: 00);

      final bool isBookable = !slotStartDateTime.isBefore(now.add(bookingBuffer));

      final uniqueId = '${slotId}_$targetDateString';

      return {
        'id': uniqueId,
        'originalId': slotId,
        'date': targetDateString,
        'startTime': startTime,
        'endTime': endTime,
        'fee': fee,
        'isAvailable': isBookable,
        'displayText': _formatSlotDisplayText(targetDateString, startTime, endTime),
        'dateFormatted': _formatDateForDisplay(targetDateString),
        'timeRange': endTime.isNotEmpty ? '$startTime - $endTime' : startTime,
      };
    } catch (e) {
      print('Error processing slot for date: $e');
      return null;
    }
  }

  static DateTime _parseSlotDateTime(DateTime date, String time12h) {
    try {
      final time24h = _convertTo24Hour(time12h); // e.g., "13:00"
      final parts = time24h.split(':');
      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);

      // Create a new DateTime using the slot's date, but with the slot's time.
      return DateTime(date.year, date.month, date.day, hours, minutes);
    } catch (e) {
      print('Error parsing slot date/time: $e');
      // Fallback: return a time in the past so it gets filtered out
      return DateTime(2000);
    }
  }

  static int _compareTimeStrings(String timeA, String timeB) {
    try {
      final timeAConverted = _convertTo24Hour(timeA);
      final timeBConverted = _convertTo24Hour(timeB);
      return timeAConverted.compareTo(timeBConverted);
    } catch (e) {
      return timeA.compareTo(timeB);
    }
  }

  static String _convertTo24Hour(String time12h) {
    try {
      final time = time12h.trim();
      final isAM = time.toUpperCase().contains('AM');
      final isPM = time.toUpperCase().contains('PM');

      if (!isAM && !isPM) return time; // Assume 24h format if no AM/PM

      final timeWithoutPeriod =
      time.replaceAll(RegExp(r'[APap][Mm]'), '').trim();
      final parts = timeWithoutPeriod.split(':');

      if (parts.length != 2) return time;

      int hours = int.parse(parts[0]);
      final minutes = parts[1];

      if (isPM && hours != 12) {
        hours += 12;
      } else if (isAM && hours == 12) {
        hours = 0; // Midnight
      }

      return '${hours.toString().padLeft(2, '0')}:$minutes';
    } catch (e) {
      return time12h;
    }
  }

  static String _formatSlotDisplayText(
      String date,
      String startTime,
      String endTime,
      ) {
    try {
      final dateFormatted = _formatDateForDisplay(date);
      final timeRange =
      endTime.isNotEmpty ? '$startTime - $endTime' : startTime;
      return '$dateFormatted • $timeRange';
    } catch (e) {
      return '$date $startTime';
    }
  }

  static String _formatDateForDisplay(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(Duration(days: 1));
      final slotDate = DateTime(date.year, date.month, date.day);

      if (slotDate.isAtSameMomentAs(today)) {
        return 'Today'; // Now handles "Today"
      } else if (slotDate.isAtSameMomentAs(tomorrow)) {
        return 'Tomorrow';
      } else {
        final months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

        final dayName = days[date.weekday % 7];
        final monthName = months[date.month - 1];

        return '$dayName, ${date.day} $monthName';
      }
    } catch (e) {
      return dateStr;
    }
  }

  static Future<Map<String, dynamic>> getSlotsByDate() async {
    final slotsResult = await getDeliverySlots();

    if (slotsResult['error'] != null) {
      return slotsResult;
    }

    final slots = slotsResult['data']['slots'] as List<Map<String, dynamic>>;
    final Map<String, List<Map<String, dynamic>>> slotsByDate = {};

    for (final slot in slots) {
      // --- MODIFICATION: Do NOT filter here. Group all slots. ---
      final dateFormatted = slot['dateFormatted'] as String;
      slotsByDate[dateFormatted] ??= [];
      slotsByDate[dateFormatted]!.add(slot);
      // --- END MODIFICATION ---
    }

    return {
      'success': true,
      'data': {
        'slotsByDate': slotsByDate,
        'totalDates': slotsByDate.length,
        'totalSlots': slots.length, // Total slots, not just available
      },
    };
  }

  static Future<Map<String, dynamic>> getSlotsForDate(String targetDate) async {
    final slotsResult = await getDeliverySlots();

    if (slotsResult['error'] != null) {
      return slotsResult;
    }

    final slots = slotsResult['data']['slots'] as List<Map<String, dynamic>>;
    final filteredSlots =
    slots.where((slot) {
      final slotDate = slot['date'] as String;
      return slotDate == targetDate && slot['isAvailable'] == true;
    }).toList();

    return {
      'success': true,
      'data': {
        'slots': filteredSlots,
        'date': targetDate,
        'count': filteredSlots.length,
      },
    };
  }

  static Future<bool> isSlotAvailable(String slotId) async {
    try {
      final slotsResult = await getDeliverySlots();

      if (slotsResult['error'] != null) {
        return false;
      }

      final slots = slotsResult['data']['slots'] as List<Map<String, dynamic>>;
      final slot = slots.firstWhere(
            (s) => s['id'] == slotId,
        orElse: () => <String, dynamic>{},
      );

      return slot.isNotEmpty && slot['isAvailable'] == true;
    } catch (e) {
      print('Error checking slot availability: $e');
      return false;
    }
  }

  static Future<void> preloadDeliverySlots() async {
    try {
      await getDeliverySlots();
    } catch (e) {
      print('Error preloading delivery slots: $e');
    }
  }

  static void clearDeliverySlotsCache() {
    _deliverySlots = null;
    _deliverySlotsTimestamp = null;
  }

  // ... [Rest of the existing cart methods remain the same]

  static Future<Map<String, dynamic>?> addItemsToCart({
    required List<Map<String, dynamic>> items,
  }) async {
    if (!isAuthenticated()) {
      return {'error': 'Please login to add items to cart'};
    }

    try {
      final headers = await _getHeaders();
      final response = await http
          .post(
        Uri.parse('$baseUrl/add'),
        headers: headers,
        body: json.encode({'items': items}),
      )
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          return json.decode(response.body);
        } catch (e) {
          return {'success': true, 'message': 'Item added successfully'};
        }
      } else if (response.statusCode == 401) {
        _cachedHeaders = null;
        return {'error': 'Please login again'};
      } else {
        return {'error': 'Failed to add items to cart'};
      }
    } catch (e) {
      return {'error': 'Network error occurred'};
    }
  }

  static Future<Map<String, dynamic>?> addSingleItemToCart({
    required String itemId,
    required int quantity,
  }) async {
    if (itemId.isEmpty || quantity <= 0) {
      return {'error': 'Invalid item ID or quantity'};
    }

    return addItemsToCart(
      items: [
        {'itemId': itemId, 'quantity': quantity},
      ],
    );
  }

  static Future<Map<String, dynamic>?> updateItemQuantity({
    String? cartItemId,
    required String itemId,
    required int quantity,
  }) async {
    if (!isAuthenticated()) {
      return {'error': 'Please login to update cart'};
    }

    try {
      final headers = await _getHeaders();
      final body = json.encode({'quantity': quantity, 'itemId': itemId});

      print('🔧 Attempting PATCH: $baseUrl');
      print('🔧 Body: $body');
      print('🔧 Headers: $headers');

      final response = await http
          .patch(Uri.parse('$baseUrl'), headers: headers, body: body)
          .timeout(Duration(seconds: 15));

      print('🔧 PATCH Response Status: ${response.statusCode}');
      print('🔧 PATCH Response Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          return json.decode(response.body);
        } catch (e) {
          return {'success': true, 'message': 'Quantity updated'};
        }
      } else if (response.statusCode == 401) {
        _cachedHeaders = null;
        return {'error': 'Please login again'};
      } else {
        return {
          'error': 'Failed to update quantity (Status: ${response.statusCode})',
          'details': response.body,
        };
      }
    } catch (e) {
      print('🔧 PATCH Exception: $e');
      return {'error': 'Network error occurred: $e'};
    }
  }

  static Future<Map<String, dynamic>?> removeItemFromCart({
    required String cartItemId,
    required String itemId,
  }) async {
    if (!isAuthenticated()) {
      return {'error': 'Please login to modify cart'};
    }

    try {
      final headers = await _getHeaders();
      print('🗑️ Attempting DELETE: $baseUrl/$itemId');

      var response = await http
          .delete(Uri.parse('$baseUrl/$itemId'), headers: headers)
          .timeout(Duration(seconds: 15));

      print('🗑️ DELETE Response Status: ${response.statusCode}');
      print('🗑️ DELETE Response Body: ${response.body}');

      if (response.statusCode == 400) {
        print('🗑️ Got 400, trying alternate DELETE with body...');
        response = await http
            .delete(
          Uri.parse('$baseUrl'),
          headers: headers,
          body: json.encode({'itemId': itemId}),
        )
            .timeout(Duration(seconds: 15));

        print('🗑️ Alternate DELETE Status: ${response.statusCode}');
        print('🗑️ Alternate DELETE Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        try {
          return json.decode(response.body);
        } catch (e) {
          return {'success': true, 'message': 'Item removed'};
        }
      } else if (response.statusCode == 401) {
        _cachedHeaders = null;
        return {'error': 'Please login again'};
      } else {
        return {
          'error': 'Failed to remove item (Status: ${response.statusCode})',
          'details': response.body,
        };
      }
    } catch (e) {
      print('🗑️ DELETE Exception: $e');
      return {'error': 'Failed to remove item: $e'};
    }
  }

  static Future<void> preloadItemsLookup() async {
    try {
      await _getItemsLookup();
    } catch (e) {
      print('Error preloading items lookup: $e');
    }
  }

  static void clearAllCache() {
    _itemsLookup = null;
    _itemsLookupTimestamp = null;
    _cachedHeaders = null;
    _headersTimestamp = null;
    clearDeliverySlotsCache();
    clearDeliverySettingsCache();
  }

  static Future<bool> isAPIAvailable() async {
    if (!isAuthenticated()) return false;
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse(baseUrl), headers: headers)
          .timeout(Duration(seconds: 8));
      return response.statusCode < 500;
    } catch (e) {
      return false;
    }
  }

  static Map<String, String> getUserInfo() {
    return {
      'name': _userData.getName(),
      'phone': _userData.getPhone(),
      'email': _userData.getEmail(),
      'isLoggedIn': _userData.isLoggedIn().toString(),
      'hasToken': (_userData.getToken() != null).toString(),
    };
  }

  static void debugAuth() {
    final userInfo = getUserInfo();
    print('=== Cart Service Debug Info ===');
    userInfo.forEach((key, value) {
      print('$key: $value');
    });
    print('Is Authenticated: ${isAuthenticated()}');
  }

  static Future<String> getProductImageById(String productId) async {
    try {
      final itemsLookup = await _getItemsLookup();
      final productData = itemsLookup[productId] ?? {};
      final imageUrls = _getImageUrls(productData['itemImages']);
      return imageUrls.isNotEmpty ? imageUrls[0] : '';
    } catch (e) {
      return '';
    }
  }

  static Future<List<String>> getProductImagesById(String productId) async {
    try {
      final itemsLookup = await _getItemsLookup();
      final productData = itemsLookup[productId] ?? {};
      return _getImageUrls(productData['itemImages']);
    } catch (e) {
      return [];
    }
  }

  // ---------------------- Cache helpers ----------------------
  /// Save the latest cart payload to the encrypted checkout cache box.
  static Future<void> saveCartToCache(Map<String, dynamic> cartPayload) async {
    try {
      final cache = await CacheManager.init();
      final expires = DateTime.now().add(Duration(hours: 24));
      await cache.save(
        CacheManager.checkoutBoxName,
        'cart_items',
        cartPayload,
        expires,
      );
    } catch (e) {
      print('saveCartToCache error: $e');
    }
  }

  /// Read cart payload from cache. Returns null if not available.
  static Future<Map<String, dynamic>?> readCartFromCache() async {
    try {
      final cache = await CacheManager.init();
      final data = cache.read(CacheManager.checkoutBoxName, 'cart_items');
      if (data == null) return null;
      return Map<String, dynamic>.from(data as Map);
    } catch (e) {
      print('readCartFromCache error: $e');
      return null;
    }
  }
}