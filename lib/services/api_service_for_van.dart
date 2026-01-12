import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../authentication/user_data.dart';
import '../model/van_booking/VanRoute_model.dart';
import '../model/van_booking/response_model.dart';
import 'Notification/order_notification_manager.dart';

class VanRouteApiService {
  static final VanRouteApiService _instance = VanRouteApiService._internal();
  factory VanRouteApiService() => _instance;
  VanRouteApiService._internal();

  final UserData _userData = UserData();
  final String baseUrl = 'https://pos.inspiredgrow.in/vps/api';

  bool isUserLoggedIn() => _userData.isLoggedIn();
  String? get _authToken => _userData.getToken();

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': '*/*',
    'Accept-Encoding': 'gzip, deflate,',
    'Connection': 'keep-alive',
    'User-Agent': 'PostmanRuntime/7.4.41',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

  // Enhanced createBooking method with success tracking
  Future<BookingResponse> createBooking({
    required String type,
    required String scheduledFor,
    required String remark,
    required String label,
    required String street,
    required String area,
    required String city,
    required String state,
    required String country,
    required String postalCode,
    List<double>? coordinates,
  }) async {
    try {
      final Map<String, dynamic> requestBody = {
        'type': type,
        'scheduledFor': scheduledFor,
        'remark': remark,
        'label': label,
        'street': street,
        'area': area,
        'city': city,
        'state': state,
        'country': country,
        'postalCode': postalCode,
        if (coordinates != null && coordinates.length >= 2)
          'coordinates': coordinates,
      };

      print('Creating booking with request body: ${json.encode(requestBody)}');

      final response = await http
          .post(
            Uri.parse('$baseUrl/bookings'),
            headers: _headers,
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      print('Booking API Response Status: ${response.statusCode}');
      print('Booking API Response Body: ${response.body}');

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true && responseData['data'] != null) {
          final bookingData = responseData['data'];

          // Fix: Get the correct ID from the booking data
          final bookingId = bookingData['_id'] ?? bookingData['id'];
          print('Created booking with ID: $bookingId');

          // --- ADD THESE LINES ---
          final currentUserId = getUserId();
          print('DEBUG CHECK: Checking condition to send notification...');
          print('DEBUG CHECK: bookingId is -> $bookingId');
          print('DEBUG CHECK: currentUserId is -> $currentUserId');
          // --- END OF ADDED LINES ---

          // --- MODIFIED IF-STATEMENT ---
          if (bookingId != null && currentUserId != null) {
            print('Attempting to trigger van booking notification...');
            await OrderNotificationManager().handleVanBooking(
              customerId: currentUserId, // Use the variable here
              bookingId: bookingId,
              location: '$street, $city',
              scheduledTime: DateTime.parse(scheduledFor),
            );
          }

          // Store the successful booking temporarily for immediate display
          if (bookingId != null) {
            await _storeTemporaryBooking(bookingData);
          }

          return BookingResponse(
            success: true,
            customer: bookingData['customer']?.toString() ?? '',
            pickupAddress: bookingData['pickupAddress']?.toString() ?? '',
            type: bookingData['type'] ?? type,
            scheduledFor: bookingData['scheduledFor'] ?? scheduledFor,
            remark: bookingData['remark'] ?? remark,
            status: bookingData['status'] ?? 'pending',
            id: bookingId?.toString() ?? '',
            createdAt:
                bookingData['createdAt'] ?? DateTime.now().toIso8601String(),
            updatedAt:
                bookingData['updatedAt'] ?? DateTime.now().toIso8601String(),
            v: bookingData['__v'] ?? 0,
          );
        } else {
          throw Exception('Invalid response format: ${response.body}');
        }
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['message'] ?? 'Failed to create booking';
        throw Exception('API Error ${response.statusCode}: $errorMessage');
      }
    } catch (e) {
      print('Error creating booking: $e');
      rethrow;
    }
  }

  // Store temporary booking for immediate display
  Future<void> _storeTemporaryBooking(Map<String, dynamic> bookingData) async {
    try {
      final tempBookings = await _getTemporaryBookings();
      tempBookings.add(bookingData);

      // Store in local storage (you can use Hive or SharedPreferences)
      // For now, we'll use a simple in-memory storage
      _tempBookings = tempBookings;

      print('Stored temporary booking: ${bookingData['id']}');
    } catch (e) {
      print('Error storing temporary booking: $e');
    }
  }

  // In-memory storage for temporary bookings
  List<Map<String, dynamic>> _tempBookings = [];

  Future<List<Map<String, dynamic>>> _getTemporaryBookings() async {
    return List.from(_tempBookings);
  }

  // In api_service_for_van.dart

  // In api_service_for_van.dart

  Future<UserBooking?> getBookingDetails(String bookingId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/bookings/$bookingId/details'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));

      print('Booking details API Response Status: ${response.statusCode}');
      print('Booking details API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);

        // --- START OF FIX ---
        // Handle the { "success": true, "data": { "booking": {...}, "order": {...} } } structure
        if (responseData is Map<String, dynamic> &&
            responseData['success'] == true &&
            responseData['data'] != null) {
          final bookingData = responseData['data']['booking'];
          final orderData = responseData['data']['order'];
          // <-- Get the order object

          print("------------------------------");
          print('Booking Data: for order');

          print(orderData);

          if (bookingData is Map<String, dynamic>) {
            // 1. Parse the booking
            final booking = _parseBookingFromApi(bookingData);

            // 2. Parse the order (if it exists)
            final OrderInfo? order =
                (orderData != null) ? OrderInfo.fromJson(orderData) : null;

            // 3. Return the booking with the order injected using copyWith
            return booking.copyWith(order: order);
          }
        }
        // --- END OF FIX ---
      }
      return null;
    } catch (e) {
      print('Error loading booking details: $e');
      return null;
    }
  }

 

  Future<String> _getResponseBody(http.Response response) async {
    try {
      final contentEncoding =
          response.headers['content-encoding']?.toLowerCase();

      if (contentEncoding == 'gzip') {
        print('Response is GZIP compressed - decompressing...');
        return utf8.decode(gzip.decode(response.bodyBytes));
      } else if (contentEncoding == 'deflate') {
        print('Response is deflate compressed - decompressing...');
        // Handle deflate if needed
        return utf8.decode(response.bodyBytes);
      } else {
        return response.body;
      }
    } catch (e) {
      print('Error decompressing response: $e');
      // Fallback to original body
      return response.body;
    }
  }

  // In api_service_for_van.dart

  // In api_service_for_van.dart

  Future<List<UserBooking>> getUserBookings() async {
    try {
      if (!isUserLoggedIn()) {
        print('User not logged in - returning empty bookings');
        return [];
      }

      final token = _userData.getToken();
      print(
        'Making bookings request with token: ${token?.substring(0, 20)}...',
      );

      final response = await http
          .get(Uri.parse('$baseUrl/bookings/my'), headers: _headers)
          .timeout(const Duration(seconds: 15));

      print('Bookings API Response Status: ${response.statusCode}');
      print('Response Headers: ${response.headers}');

      String responseBody;
      try {
        responseBody = await _getResponseBody(response);
        print('Bookings API Response Body: $responseBody');
      } catch (decompressionError) {
        print('Decompression failed: $decompressionError');
        return await _getTemporaryBookingsAsUserBookings();
      }

      if (response.statusCode == 200) {
        dynamic responseData;
        try {
          responseData = json.decode(responseBody);
        } catch (jsonError) {
          print('JSON decode error: $jsonError');
          return await _getTemporaryBookingsAsUserBookings();
        }

        List<UserBooking> apiBookings = [];

        // --- START OF FIX ---
        // Handle the { "success": true, "data": [...] } structure
        if (responseData is Map<String, dynamic> &&
            responseData['success'] == true) {
          final bookingsData = responseData['data'];

          

          if (bookingsData is List) {
            print('Parsing ${bookingsData.length} bookings from "data" array');
            try {
              apiBookings =
                  bookingsData.map((bookingJson) {
                    return _parseBookingFromApi(
                      bookingJson as Map<String, dynamic>,
                    );
                  }).toList();

                    

              await clearTemporaryBookings();
              return apiBookings;
            } catch (parseError) {
              print('Error parsing booking array: $parseError');
              return await _getTemporaryBookingsAsUserBookings();
            }
          }
        }
        // --- END OF FIX ---

        // Fallback for old direct list structure
        if (responseData is List<dynamic>) {
          print('Parsing ${responseData.length} bookings from direct array');
          apiBookings =
              responseData.map((bookingJson) {
                return _parseBookingFromApi(
                  bookingJson as Map<String, dynamic>,
                );
              }).toList();

          await clearTemporaryBookings();
          return apiBookings;
        }

        print(
          'Unexpected response format for bookings: ${responseData.runtimeType}',
        );
        return await _getTemporaryBookingsAsUserBookings();
      } else if (response.statusCode == 500) {
        print('Server error 500 - falling back to temporary bookings');
        return await _getTemporaryBookingsAsUserBookings();
      } else if (response.statusCode == 401) {
        print('Unauthorized - session may be expired');
        await _userData.setLoggedOut();
        throw Exception('Session expired. Please login again.');
      } else {
        print(
          'API Error: ${response.statusCode} - returning temporary bookings',
        );
        return await _getTemporaryBookingsAsUserBookings();
      }
    } catch (e) {
      print('Error loading bookings: $e');
      try {
        final tempBookings = await _getTemporaryBookingsAsUserBookings();
        if (tempBookings.isNotEmpty) {
          print(
            'Returning ${tempBookings.length} temporary bookings as fallback',
          );
          return tempBookings;
        }
      } catch (tempError) {
        print('Error loading temporary bookings: $tempError');
      }
      return [];
    }
  }
  // Enhanced booking parser to handle the full pickup address object
  // In api_service_for_van.dart

  // In api_service_for_van.dart

  UserBooking _parseBookingFromApi(Map<String, dynamic> bookingJson) {
    final bookingId = bookingJson['_id'] ?? bookingJson['id'] ?? '';
    print('Parsing booking: $bookingId');
    print('-----------------------------');
    print(bookingJson);

    // --- FIX CUSTOMER NORMALIZATION ---
    final customerData = bookingJson['customer'];
    print(bookingJson['order']);

    String customerId;
    if (customerData is Map<String, dynamic>) {
      customerId = customerData['_id']?.toString() ?? '';
    } else {
      customerId = customerData?.toString() ?? '';
    }

    // --- FIX PICKUP ADDRESS NORMALIZATION ---
    final pickupAddressData = bookingJson['pickupAddress'];
    PickupAddress pickupAddress;
    if (pickupAddressData is Map<String, dynamic>) {
      pickupAddress = PickupAddress.fromJson(pickupAddressData);
    } else {
      pickupAddress = PickupAddress.fromJson({
        '_id': pickupAddressData?.toString() ?? '',
      });
    }

    // --- NEW: PARSE ORDER IF PRESENT ---
    OrderInfo? order;
    if (bookingJson['order'] != null && bookingJson['order'] is Map) {
      order = OrderInfo.fromJson(bookingJson['order']);
    }

    final booking = UserBooking(
      id: bookingId,
      customer: customerId,
      pickupAddress: pickupAddress,
      bookingType: bookingJson['type'] ?? 'scheduled',
      scheduledFor: _parseDateTime(bookingJson['scheduledFor']),
      remark: bookingJson['remark'] ?? '',
      status: bookingJson['status'] ?? 'pending',
      createdAt: _parseDateTime(bookingJson['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(bookingJson['updatedAt']) ?? DateTime.now(),
      v: bookingJson['__v'] ?? 0,
      order: order, // <-- FIXED: AUTO-PARSED
    );

    print('Successfully parsed booking: ${booking.id} - ${booking.status}');
    return booking;
  }

  // Add method to merge API bookings with temporary bookings (avoid duplicates)
  List<UserBooking> _mergeBookings(
    List<UserBooking> apiBookings,
    List<UserBooking> tempBookings,
  ) {
    final Map<String, UserBooking> bookingsMap = {};

    // Add API bookings first (they take precedence)
    for (final booking in apiBookings) {
      bookingsMap[booking.id] = booking;
    }

    // Add temporary bookings only if not already present
    for (final booking in tempBookings) {
      if (!bookingsMap.containsKey(booking.id)) {
        bookingsMap[booking.id] = booking;
      }
    }

    // Sort by creation date (newest first)
    final mergedBookings = bookingsMap.values.toList();
    mergedBookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return mergedBookings;
  }

  // Enhanced method to get user bookings with smart merging
  Future<List<UserBooking>> getUserBookingsWithSmartMerge() async {
    try {
      // Get bookings from API
      final apiBookings = await getUserBookings();

      // If API worked, return API bookings
      if (apiBookings.isNotEmpty) {
        return apiBookings;
      }

      // If API returned empty but we have temp bookings, return temp bookings
      final tempBookings = await _getTemporaryBookingsAsUserBookings();
      return tempBookings;
    } catch (e) {
      print('Error in smart merge: $e');
      // Fallback to temporary bookings
      return await _getTemporaryBookingsAsUserBookings();
    }
  }

  // Method to check API health and auto-clear temp data when API recovers
  Future<bool> checkApiHealthAndSync() async {
    try {
      print('Checking API health...');

      final response = await http
          .get(Uri.parse('$baseUrl/bookings/my'), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('API is healthy - syncing data');

        // API is working, clear temporary data and return fresh data
        await clearTemporaryBookings();
        return true;
      } else {
        print('API still has issues: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('API health check failed: $e');
      return false;
    }
  }

  // Convert temporary bookings to UserBooking objects
  Future<List<UserBooking>> _getTemporaryBookingsAsUserBookings() async {
    try {
      final tempBookings = await _getTemporaryBookings();
      return tempBookings.map((bookingData) {
        return _parseBookingFromApi(bookingData);
      }).toList();
    } catch (e) {
      print('Error converting temporary bookings: $e');
      return [];
    }
  }

  // Enhanced booking parser

  // Helper method to parse coordinates
  List<double> _parseCoordinates(dynamic coordinates) {
    if (coordinates is List && coordinates.length >= 2) {
      try {
        return [
          double.parse(coordinates[0].toString()),
          double.parse(coordinates[1].toString()),
        ];
      } catch (e) {
        print('Error parsing coordinates: $e');
      }
    }
    return [0.0, 0.0];
  }

  // --- START: FIX FROM SCREENSHOT ---
  // Helper method to parse DateTime
  DateTime? _parseDateTime(dynamic dateTimeStr) {
    if (dateTimeStr == null) return null;
    try {
      // <-- Removed the period from "try {."
      return DateTime.parse(dateTimeStr.toString());
    } catch (e) {
      print('Error parsing DateTime: $e');
      return null; // Return null to match nullable type
    }
  }
  // --- END: FIX FROM SCREENSHOT ---

  // Extract address info from remark (fallback)
  Map<String, String> _extractAddressFromRemark(String remark) {
    final result = <String, String>{};

    // Try to extract address from remark like "Scheduled booking from 785, Sipri Bazar, Jhansi"
    if (remark.contains('from ')) {
      final addressPart = remark.split('from ').last;
      final addressParts = addressPart.split(', ');

      if (addressParts.isNotEmpty) {
        result['street'] = addressParts.first;
        if (addressParts.length > 1) {
          result['area'] = addressParts[1];
        }
        if (addressParts.length > 2) {
          result['city'] = addressParts.last;
        }
      }
    }

    return result;
  }

  // Clear temporary bookings (call this when API is working again)
  Future<void> clearTemporaryBookings() async {
    _tempBookings.clear();
    print('Cleared temporary bookings');
  }

  // Method to retry getting bookings from API
  Future<List<UserBooking>> retryGetBookingsFromAPI() async {
    try {
      print('Retrying to get bookings from API...');

      final response = await http
          .get(Uri.parse('$baseUrl/bookings/my'), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('API is working again - clearing temporary bookings');
        await clearTemporaryBookings();

        final dynamic responseData = json.decode(response.body);
        List<UserBooking> apiBookings = [];

        if (responseData is List<dynamic>) {
          apiBookings =
              responseData.map((bookingJson) {
                return _parseBookingFromApi(bookingJson);
              }).toList();
        } else if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data') &&
              responseData['data'] is List) {
            final List<dynamic> bookingsData = responseData['data'];
            apiBookings =
                bookingsData.map((bookingJson) {
                  return _parseBookingFromApi(bookingJson);
                }).toList();
          }
        }

        return apiBookings;
      } else {
        throw Exception('API still returning error: ${response.statusCode}');
      }
    } catch (e) {
      print('Retry failed: $e');
      return await _getTemporaryBookingsAsUserBookings();
    }
  }

  // Book instant van
  /*Future<BookingResponse> bookInstantVan({
    required String location,
    required Map<String, dynamic> pickupAddress,
  }) async {
    if (!isUserLoggedIn()) {
      throw Exception('User not logged in');
    }

    final String scheduledFor = DateTime.now().toUtc().toIso8601String();

    return await createBooking(
      type: 'instant',
      scheduledFor: scheduledFor,
      remark: 'Instant booking from $location',
      label: pickupAddress['label'] ?? 'Selected Location',
      street: pickupAddress['street'] ?? location,
      area: pickupAddress['area'] ?? 'Unknown Area',
      city: pickupAddress['city'] ?? 'Unknown City',
      state: pickupAddress['state'] ?? 'Unknown State',
      country: pickupAddress['country'] ?? 'India',
      postalCode: pickupAddress['postalCode'] ?? '000000',
      coordinates: pickupAddress['coordinates']?.cast<double>(),
    );
  }*/

  // REMOVED bookVanNow method as requested

  Future<BookingResponse> scheduleVanBookingWithAddress({
    String?
    addressId, // If provided, use existing address instead of creating new
    required String location,
    required String street,
    required String area,
    required String city,
    required String state,
    required String postalCode,
    required List<double> coordinates,
    required DateTime scheduledDateTime,
    String remark = '',
  }) async {
    if (!isUserLoggedIn()) {
      throw Exception('User not logged in');
    }

    final String scheduledFor = scheduledDateTime.toUtc().toIso8601String();

    // CRITICAL: If addressId is provided, use it. Otherwise, create new address.
    if (addressId != null && addressId.isNotEmpty) {
      // Use existing address - DON'T send address details
      return await createBookingWithAddressId(
        addressId: addressId,
        type: 'scheduled',
        scheduledFor: scheduledFor,
        remark: remark.isEmpty ? 'Scheduled booking from $location' : remark,
      );
    } else {
      // Create new address (for current location or if save failed)
      return await createBooking(
        type: 'scheduled',
        scheduledFor: scheduledFor,
        remark: remark.isEmpty ? 'Scheduled booking from $location' : remark,
        label: 'Selected Location',
        street: street,
        area: area,
        city: city,
        state: state,
        country: 'India',
        postalCode: postalCode,
        coordinates: coordinates,
      );
    }
  }

  // Schedule van booking
  Future<BookingResponse> createBookingWithAddressId({
    required String addressId,
    required String type,
    required String scheduledFor,
    required String remark,
  }) async {
    try {
      final Map<String, dynamic> requestBody = {
        'type': type,
        'scheduledFor': scheduledFor,
        'remark': remark,
        'addressId':
            addressId, // Send only the address ID, not full address data
      };

      print('Creating booking with address ID: ${json.encode(requestBody)}');

      final response = await http
          .post(
            Uri.parse('$baseUrl/bookings'),
            headers: _headers,
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      print('Booking API Response Status: ${response.statusCode}');
      print('Booking API Response Body: ${response.body}');

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true && responseData['data'] != null) {
          final bookingData = responseData['data'];
          final bookingId = bookingData['_id'] ?? bookingData['id'];

          print(
            'Created booking with ID: $bookingId using address ID: $addressId',
          );

          // Trigger notification
          final currentUserId = getUserId();
          if (bookingId != null && currentUserId != null) {
            print('Attempting to trigger van booking notification...');
            await OrderNotificationManager().handleVanBooking(
              customerId: currentUserId,
              bookingId: bookingId,
              location: 'Saved Address',
              scheduledTime: DateTime.parse(scheduledFor),
            );
          }

          // Store the successful booking temporarily
          if (bookingId != null) {
            await _storeTemporaryBooking(bookingData);
          }

          return BookingResponse(
            success: true,
            customer: bookingData['customer']?.toString() ?? '',
            pickupAddress: addressId, // Return the address ID
            type: bookingData['type'] ?? type,
            scheduledFor: bookingData['scheduledFor'] ?? scheduledFor,
            remark: bookingData['remark'] ?? remark,
            status: bookingData['status'] ?? 'pending',
            id: bookingId?.toString() ?? '',
            createdAt:
                bookingData['createdAt'] ?? DateTime.now().toIso8601String(),
            updatedAt:
                bookingData['updatedAt'] ?? DateTime.now().toIso8601String(),
            v: bookingData['__v'] ?? 0,
          );
        } else {
          throw Exception('Invalid response format: ${response.body}');
        }
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['message'] ?? 'Failed to create booking';
        throw Exception('API Error ${response.statusCode}: $errorMessage');
      }
    } catch (e) {
      print('Error creating booking with address ID: $e');
      rethrow;
    }
  }

  // UPDATE the existing scheduleVanBooking method to use the new one
  Future<BookingResponse> scheduleVanBooking({
    required String location,
    required Map<String, dynamic> pickupAddress,
    required DateTime scheduledDateTime,
    String remark = '',
  }) async {
    if (!isUserLoggedIn()) {
      throw Exception('User not logged in');
    }

    // Check if pickupAddress contains an ID (existing address)
    final String? addressId = pickupAddress['id'] ?? pickupAddress['_id'];

    print(
      'Scheduling van booking at $location on $scheduledDateTime using address ID: $addressId',
    );

    if (addressId != null && addressId.isNotEmpty) {
      // Use existing address
      return await scheduleVanBookingWithAddress(
        addressId: addressId,
        location: location,
        street: pickupAddress['street'] ?? location,
        area: pickupAddress['area'] ?? 'Unknown Area',
        city: pickupAddress['city'] ?? 'Unknown City',
        state: pickupAddress['state'] ?? 'Unknown State',
        postalCode: pickupAddress['postalCode'] ?? '000000',
        coordinates: pickupAddress['coordinates']?.cast<double>() ?? [0.0, 0.0],
        scheduledDateTime: scheduledDateTime,
        remark: remark,
      );
    } else {
      // Create new address
      return await scheduleVanBookingWithAddress(
        addressId: null,
        location: location,
        street: pickupAddress['street'] ?? location,
        area: pickupAddress['area'] ?? 'Unknown Area',
        city: pickupAddress['city'] ?? 'Unknown City',
        state: pickupAddress['state'] ?? 'Unknown State',
        postalCode: pickupAddress['postalCode'] ?? '000000',
        coordinates: pickupAddress['coordinates']?.cast<double>() ?? [0.0, 0.0],
        scheduledDateTime: scheduledDateTime,
        remark: remark,
      );
    }
  }

  // Mock bookings
  List<UserBooking> _getMockBookings() {
    return [
      UserBooking(
        id: 'mock_recent_${DateTime.now().millisecondsSinceEpoch}',
        customer: '686b4ecacabd4d427f0589e7',
        pickupAddress: PickupAddress(
          id: 'mock_addr_001',
          street: '785, Sipri Bazar',
          area: 'Sipri Bazar',
          city: 'Jhansi',
          state: 'Uttar Pradesh',
          country: 'India',
          postalCode: '284003',
          coordinates: [25.4567877, 78.5464999],
        ),
        bookingType: 'scheduled',
        scheduledFor: DateTime.now().add(const Duration(hours: 1)),
        remark: 'Scheduled booking from 785, Sipri Bazar, Jhansi',
        status: 'pending',
        createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 2)),
        v: 0,
      ),
    ];
  }

  // Keep other methods as they were...
  Future<List<String>> getTodayRoutes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/van-routes/today'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return List<String>.from(data);
      } else {
        throw Exception('Failed to load routes: ${response.statusCode}');
      }
    } catch (e) {
      return [];
    }
  }

  Future<List<VanRouteLocation>> getRouteLocations() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/van-routes/locations'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => VanRouteLocation.fromJson(json)).toList();
      } else {
        throw Exception(
          'Failed to load route locations: ${response.statusCode}',
        );
      }
    } catch (e) {
      return [];
    }
  }

  Future<RouteProgress> getRouteProgress() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/van-routes/progress'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return RouteProgress.fromJson(data);
      } else {
        throw Exception(
          'Failed to load route progress: ${response.statusCode}',
        );
      }
    } catch (e) {
      return RouteProgress(
        currentProgress: 0.3,
        startTime: "6AM",
        distance: "16KM",
      );
    }
  }

  Future<Basket> getBasket() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/basket'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return Basket.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load basket: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading basket: $e');
      return Basket(itemCount: 0, items: [], totalAmount: 0.0);
    }
  }

  // In your VanRouteApiService, make sure the cancelBooking method looks like this:
  // In your VanRouteApiService, update the cancelBooking method:
  // In your VanRouteApiService, replace the existing cancelBooking method:
  Future<BookingCancelResponse> cancelBooking(String bookingId) async {
    try {
      print('Attempting to cancel booking: $bookingId');

      final response = await http
          .post(
            Uri.parse('$baseUrl/bookings/$bookingId/cancel'),
            headers: _headers,
            body: json.encode({
              'action': 'cancel',
              'reason': 'Cancelled by user',
            }),
          )
          .timeout(const Duration(seconds: 30));

      print('Cancel booking API Response Status: ${response.statusCode}');
      print('Cancel booking API Response Body: ${response.body}');

      // Check if response is HTML (error page) instead of JSON
      if (response.body.trim().startsWith('<!DOCTYPE html>') ||
          response.body.trim().startsWith('<html')) {
        String errorMessage;
        switch (response.statusCode) {
          case 404:
            errorMessage = 'Booking not found or cancel endpoint not available';
            break;
          case 405:
            errorMessage = 'Cancel method not allowed. Please contact support.';
            break;
          case 500:
            errorMessage = 'Server error occurred while cancelling booking';
            break;
          default:
            errorMessage = 'Server returned HTML error page instead of JSON';
        }

        throw Exception(errorMessage);
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final responseData = json.decode(response.body);

          if (responseData is Map<String, dynamic>) {
            // Handle different response formats your API might return
            bool success = false;
            String message = 'Booking cancelled successfully';
            Map<String, dynamic>? bookingData;

            // Format 1: {success: true, data: {...}, message: "..."}
            if (responseData.containsKey('success')) {
              success = responseData['success'] == true;
              message = responseData['message'] ?? message;
              bookingData = responseData['data'];
            }
            // Format 2: Direct booking object with status
            else if (responseData.containsKey('_id') ||
                responseData.containsKey('id')) {
              success = true;
              bookingData = responseData;
              // Check if status is actually cancelled
              if (bookingData!['status'] == 'cancelled') {
                message = 'Booking cancelled successfully';
              }
            }
            // Format 3: Simple confirmation message
            else if (responseData.containsKey('message')) {
              success = true;
              message = responseData['message'];
            }

            if (success) {
              // Update local temporary storage
              await _updateLocalBookingStatus(bookingId, 'cancelled');

              return BookingCancelResponse(
                success: true,
                message: message,
                booking:
                    bookingData != null
                        ? _parseBookingFromApi(bookingData)
                        : null,
              );
            } else {
              return BookingCancelResponse(
                success: false,
                message:
                    message.isNotEmpty ? message : 'Failed to cancel booking',
                booking: null,
              );
            }
          } else {
            throw Exception('Invalid response format: expected JSON object');
          }
        } catch (jsonError) {
          print('JSON decode error: $jsonError');
          print('Raw response: ${response.body}');
          throw Exception('Server returned invalid JSON response');
        }
      } else {
        // Handle different HTTP error status codes
        String errorMessage;

        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? 'Unknown error occurred';
        } catch (e) {
          // If we can't parse JSON error, use status code
          switch (response.statusCode) {
            case 400:
              errorMessage =
                  'Invalid request. Booking may already be cancelled.';
              break;
            case 401:
              errorMessage = 'Authentication failed. Please login again.';
              break;
            case 403:
              errorMessage =
                  'You do not have permission to cancel this booking.';
              break;
            case 404:
              errorMessage =
                  'Booking not found. It may have already been cancelled.';
              break;
            case 409:
              errorMessage =
                  'Booking cannot be cancelled in its current state.';
              break;
            case 500:
              errorMessage = 'Server error. Please try again later.';
              break;
            default:
              errorMessage =
                  'Failed to cancel booking (HTTP ${response.statusCode})';
          }
        }

        return BookingCancelResponse(
          success: false,
          message: errorMessage,
          booking: null,
        );
      }
    } catch (e) {
      print('Error cancelling booking: $e');

      String errorMessage;
      if (e.toString().contains('TimeoutException')) {
        errorMessage =
            'Request timed out. Please check your connection and try again.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('FormatException')) {
        errorMessage = 'Server returned invalid response. Please try again.';
      } else {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      }

      return BookingCancelResponse(
        success: false,
        message: errorMessage,
        booking: null,
      );
    }
  } // Helper method to update local booking status

  Future<void> _updateLocalBookingStatus(
    String bookingId,
    String newStatus,
  ) async {
    try {
      // Update temporary bookings
      for (int i = 0; i < _tempBookings.length; i++) {
        if (_tempBookings[i]['_id'] == bookingId ||
            _tempBookings[i]['id'] == bookingId) {
          _tempBookings[i]['status'] = newStatus;
          _tempBookings[i]['updatedAt'] = DateTime.now().toIso8601String();
          if (newStatus == 'cancelled') {
            _tempBookings[i]['cancelledAt'] = DateTime.now().toIso8601String();
            _tempBookings[i]['cancelledBy'] = getUserId();
          }
          break;
        }
      }
      print('Updated local booking status for $bookingId to $newStatus');
    } catch (e) {
      print('Error updating local booking status: $e');
    }
  }

  // Simple boolean version (if you prefer the original approach)
  Future<bool> cancelBookingSimple(String bookingId) async {
    try {
      final result = await cancelBooking(bookingId);
      return result.success;
    } catch (e) {
      print('Error in simple cancel booking: $e');
      return false;
    }
  }

  Future<bool> updateBookingStatus(String bookingId, String status) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/bookings/$bookingId/status'),
        headers: _headers,
        body: json.encode({'status': status}),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Helper methods
  String getUserName() => _userData.getName();
  String getUserPhone() => _userData.getPhone();
  String getUserEmail() => _userData.getEmail();
  String getUserCity() => _userData.getCity();
  String getUserState() => _userData.getState();
  String getUserCountry() => _userData.getCountry();
  String? getUserId() => _userData.getUserId();

  // Enhanced debug info
  Map<String, dynamic> getUserDebugInfo() {
    final user = _userData.getCurrentUser();

    return {
      'isLoggedIn': isUserLoggedIn(),
      'hasToken': _authToken != null,
      'tokenPrefix': _authToken?.substring(0, min(20, _authToken?.length ?? 0)),
      'hasUserData': user != null,
      'userId': _userData.getUserId() ?? 'N/A',
      'name': _userData.getName(),
      'phone': _userData.getPhone(),
      'email': _userData.getEmail(),
      'city': _userData.getCity(),
      'state': _userData.getState(),
      // --- START: FIX FROM SCREENSHOT ---
      'country':
          _userData.getCountry(), // <-- Fixed .Country() to .getCountry()
      // --- END: FIX FROM SCREENSHOT ---
      'tempBookingsCount': _tempBookings.length,
      'userModelData':
          user != null
              ? {
                'phone': user.phone,
                'name': user.name,
                'hasToken': user.token != null,
                'isLoggedInFlag': user.isLoggedIn,
              }
              : null,
    };
  }
}
