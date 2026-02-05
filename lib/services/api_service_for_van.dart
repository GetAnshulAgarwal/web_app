import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // REQUIRED: Added for date parsing
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

          final currentUserId = getUserId();

          if (bookingId != null && currentUserId != null) {
            print('Attempting to trigger van booking notification...');
            await OrderNotificationManager().handleVanBooking(
              customerId: currentUserId,
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

        if (responseData is Map<String, dynamic> &&
            responseData['success'] == true &&
            responseData['data'] != null) {
          final bookingData = responseData['data']['booking'];
          final orderData = responseData['data']['order'];

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
        return utf8.decode(response.bodyBytes);
      } else {
        return response.body;
      }
    } catch (e) {
      print('Error decompressing response: $e');
      return response.body;
    }
  }

  Future<List<UserBooking>> getUserBookings() async {
    try {
      if (!isUserLoggedIn()) {
        print('User not logged in - returning empty bookings');
        return [];
      }

      final token = _userData.getToken();

      final response = await http
          .get(Uri.parse('$baseUrl/bookings/my'), headers: _headers)
          .timeout(const Duration(seconds: 15));

      print('Bookings API Response Status: ${response.statusCode}');

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

        // Fallback for old direct list structure
        if (responseData is List<dynamic>) {
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
          return tempBookings;
        }
      } catch (tempError) {
        print('Error loading temporary bookings: $tempError');
      }
      return [];
    }
  }

  UserBooking _parseBookingFromApi(Map<String, dynamic> bookingJson) {
    final bookingId = bookingJson['_id'] ?? bookingJson['id'] ?? '';

    // Normalize Customer
    final customerData = bookingJson['customer'];
    String customerId;
    if (customerData is Map<String, dynamic>) {
      customerId = customerData['_id']?.toString() ?? '';
    } else {
      customerId = customerData?.toString() ?? '';
    }

    // Normalize Pickup Address
    final pickupAddressData = bookingJson['pickupAddress'];
    PickupAddress pickupAddress;
    if (pickupAddressData is Map<String, dynamic>) {
      pickupAddress = PickupAddress.fromJson(pickupAddressData);
    } else {
      pickupAddress = PickupAddress.fromJson({
        '_id': pickupAddressData?.toString() ?? '',
      });
    }

    // Parse Order
    OrderInfo? order;
    if (bookingJson['order'] != null && bookingJson['order'] is Map) {
      order = OrderInfo.fromJson(bookingJson['order']);
    }

    // -- CRITICAL PARSING LOGIC HERE --
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
      order: order,
    );

    return booking;
  }

  List<UserBooking> _mergeBookings(
      List<UserBooking> apiBookings,
      List<UserBooking> tempBookings,
      ) {
    final Map<String, UserBooking> bookingsMap = {};

    for (final booking in apiBookings) {
      bookingsMap[booking.id] = booking;
    }

    for (final booking in tempBookings) {
      if (!bookingsMap.containsKey(booking.id)) {
        bookingsMap[booking.id] = booking;
      }
    }

    final mergedBookings = bookingsMap.values.toList();
    mergedBookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return mergedBookings;
  }

  Future<List<UserBooking>> getUserBookingsWithSmartMerge() async {
    try {
      final apiBookings = await getUserBookings();
      if (apiBookings.isNotEmpty) {
        return apiBookings;
      }
      return await _getTemporaryBookingsAsUserBookings();
    } catch (e) {
      print('Error in smart merge: $e');
      return await _getTemporaryBookingsAsUserBookings();
    }
  }

  Future<bool> checkApiHealthAndSync() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/bookings/my'), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await clearTemporaryBookings();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<List<UserBooking>> _getTemporaryBookingsAsUserBookings() async {
    try {
      final tempBookings = await _getTemporaryBookings();
      return tempBookings.map((bookingData) {
        return _parseBookingFromApi(bookingData);
      }).toList();
    } catch (e) {
      return [];
    }
  }

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

  // --- FIX: UPDATED DATE PARSER ---
  // Now handles both ISO and custom formats like "15 Jan 2026, 09:00 am"
  DateTime? _parseDateTime(dynamic dateTimeStr) {
    if (dateTimeStr == null) return null;

    final str = dateTimeStr.toString().trim();
    if (str.isEmpty) return null;

    try {
      // 1. Try ISO-8601 first (standard)
      return DateTime.parse(str);
    } catch (_) {
      // 2. Try the custom format from your API: "15 Jan 2026, 09:00 am"
      try {
        // Fix case sensitivity for AM/PM to ensure parsing works
        String normalized = str;
        if (str.toLowerCase().endsWith(' am')) {
          normalized = str.substring(0, str.length - 3) + ' AM';
        } else if (str.toLowerCase().endsWith(' pm')) {
          normalized = str.substring(0, str.length - 3) + ' PM';
        }

        return DateFormat("d MMM yyyy, h:mm a").parse(normalized);
      } catch (e) {
        print('Error parsing DateTime ($str): $e');
        // Return null instead of "now" so UI can handle it or show "N/A"
        return null;
      }
    }
  }

  Map<String, String> _extractAddressFromRemark(String remark) {
    final result = <String, String>{};
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

  Future<void> clearTemporaryBookings() async {
    _tempBookings.clear();
    print('Cleared temporary bookings');
  }

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

  Future<BookingResponse> scheduleVanBookingWithAddress({
    String? addressId,
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

    if (addressId != null && addressId.isNotEmpty) {
      return await createBookingWithAddressId(
        addressId: addressId,
        type: 'scheduled',
        scheduledFor: scheduledFor,
        remark: remark.isEmpty ? 'Scheduled booking from $location' : remark,
      );
    } else {
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
        'addressId': addressId,
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

          final currentUserId = getUserId();
          if (bookingId != null && currentUserId != null) {
            await OrderNotificationManager().handleVanBooking(
              customerId: currentUserId,
              bookingId: bookingId,
              location: 'Saved Address',
              scheduledTime: DateTime.parse(scheduledFor),
            );
          }

          if (bookingId != null) {
            await _storeTemporaryBooking(bookingData);
          }

          return BookingResponse(
            success: true,
            customer: bookingData['customer']?.toString() ?? '',
            pickupAddress: addressId,
            type: bookingData['type'] ?? type,
            scheduledFor: bookingData['scheduledFor'] ?? scheduledFor,
            remark: bookingData['remark'] ?? remark,
            status: bookingData['status'] ?? 'pending',
            id: bookingId?.toString() ?? '',
            createdAt: bookingData['createdAt'] ?? DateTime.now().toIso8601String(),
            updatedAt: bookingData['updatedAt'] ?? DateTime.now().toIso8601String(),
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

  Future<BookingResponse> scheduleVanBooking({
    required String location,
    required Map<String, dynamic> pickupAddress,
    required DateTime scheduledDateTime,
    String remark = '',
  }) async {
    if (!isUserLoggedIn()) {
      throw Exception('User not logged in');
    }

    final String? addressId = pickupAddress['id'] ?? pickupAddress['_id'];

    if (addressId != null && addressId.isNotEmpty) {
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
            bool success = false;
            String message = 'Booking cancelled successfully';
            Map<String, dynamic>? bookingData;

            if (responseData.containsKey('success')) {
              success = responseData['success'] == true;
              message = responseData['message'] ?? message;
              bookingData = responseData['data'];
            }
            else if (responseData.containsKey('_id') ||
                responseData.containsKey('id')) {
              success = true;
              bookingData = responseData;
              if (bookingData!['status'] == 'cancelled') {
                message = 'Booking cancelled successfully';
              }
            }
            else if (responseData.containsKey('message')) {
              success = true;
              message = responseData['message'];
            }

            if (success) {
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
          throw Exception('Server returned invalid JSON response');
        }
      } else {
        String errorMessage;
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? 'Unknown error occurred';
        } catch (e) {
          switch (response.statusCode) {
            case 400: errorMessage = 'Invalid request. Booking may already be cancelled.'; break;
            case 401: errorMessage = 'Authentication failed. Please login again.'; break;
            case 403: errorMessage = 'You do not have permission to cancel this booking.'; break;
            case 404: errorMessage = 'Booking not found. It may have already been cancelled.'; break;
            case 409: errorMessage = 'Booking cannot be cancelled in its current state.'; break;
            case 500: errorMessage = 'Server error. Please try again later.'; break;
            default: errorMessage = 'Failed to cancel booking (HTTP ${response.statusCode})';
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
        errorMessage = 'Request timed out. Please check your connection and try again.';
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
  }

  Future<void> _updateLocalBookingStatus(
      String bookingId,
      String newStatus,
      ) async {
    try {
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

  String getUserName() => _userData.getName();
  String getUserPhone() => _userData.getPhone();
  String getUserEmail() => _userData.getEmail();
  String getUserCity() => _userData.getCity();
  String getUserState() => _userData.getState();
  String getUserCountry() => _userData.getCountry();
  String? getUserId() => _userData.getUserId();

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
      'country': _userData.getCountry(),
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