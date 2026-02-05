import 'dart:convert';
import 'package:eshop/services/home/api_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../authentication/user_data.dart';

// Fixed by Balaji: Service class to handle van booking API calls
// Provides methods to fetch all user bookings and detailed booking information
class VanBookingService {
  // Balaji: Base URL for van booking APIs
  static const String baseUrl = 'https://pos.inspiredgrow.in/vps/api/bookings';

  // Balaji: Get bearer token from UserData
  // Returns the authentication token needed for API calls
  static Future<String?> _getToken() async {
    final userData = UserData();
    return userData.getToken();
  }

  // Balaji: Fetch all van bookings for the logged-in user
  // Returns a list of bookings or empty list if error occurs
  // Only returns bookings with status 'completed', 'delivered', 'done', or 'cancelled'
  static Future<List<Map<String, dynamic>>> getMyBookings() async {
    try {
      final token = await _getToken();

      // Balaji: Check if user is authenticated
      if (token == null || token.isEmpty) {
        print(' [VanBooking] No authentication token found');
        return [];
      }

      // Balaji: Make API call to get user's bookings
      final response = await http.get(
        Uri.parse('$baseUrl/my'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print(' [VanBooking] API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);

        // Balaji: Extract bookings array from response
        // API might return data in different formats, handle both
        List<dynamic> bookings = [];

        if (responseData is List) {
          // Response is directly an array
          bookings = responseData;
        } else if (responseData is Map<String, dynamic>) {
          // Response is wrapped in an object
          if (responseData['bookings'] != null) {
            bookings = responseData['bookings'] as List<dynamic>;
          } else if (responseData['data'] != null) {
            bookings = responseData['data'] as List<dynamic>;
          }
        }

        // Balaji: Filter bookings to show completed, delivered, done, and cancelled bookings
        // Convert to List<Map<String, dynamic>> and filter by status
        final List<Map<String, dynamic>> allBookings =
        bookings.map((booking) => booking as Map<String, dynamic>).toList();

        final filteredBookings =
        allBookings.where((booking) {
          final status = booking['status']?.toString().toLowerCase() ?? '';
          return status == 'completed' ||
              status == 'delivered' ||
              status == 'done' ||
              status == 'cancelled';
        }).toList();

        final detailedBookingFutures =
        filteredBookings.map((booking) {
          // prefer _id, fall back to id; if neither exists produce a null future
          final id = booking['_id'] ?? booking['id'];
          if (id == null) return Future<Map<String, dynamic>?>.value(null);
          return getBookingDetails(id.toString());
        }).toList();

        // Await all detail fetches and filter out any null results
        final detailedBookingResults = await Future.wait(
          detailedBookingFutures,
        );
        final detailedBookings =
        detailedBookingResults.whereType<Map<String, dynamic>>().toList();

        if (detailedBookings.isNotEmpty) {
          print(
            ' [VanBooking] Fetched detailed info for ${detailedBookings.length} bookings',
          );

          print(detailedBookings);
          return detailedBookings;
        }

        print(
          ' [VanBooking] Found ${filteredBookings.length} finished bookings out of ${allBookings.length} total',
        );
        return filteredBookings;
      } else {
        print(
          ' [VanBooking] API Error: ${response.statusCode} - ${response.body}',
        );
        return [];
      }
    } catch (e) {
      print(' [VanBooking] Exception occurred: $e');
      return [];
    }
  }


  static Future<Map<String, dynamic>?> getBookingDetails(
      String bookingId,
      ) async {
    try {
      final token = await _getToken();

      if (token == null || token.isEmpty) {
        print('[VanBooking] No authentication token found');
        return null;
      }

      // Balaji: Make API call to get specific booking details
      final response = await http.get(
        Uri.parse('$baseUrl/$bookingId/details'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print(
        '📡 [VanBooking] Details API Response Status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['booking'] != null) {
          return data['booking'] as Map<String, dynamic>;
        } else if (data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        } else {
          return data;
        }
      } else {
        print('[VanBooking] Details API Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print(' [VanBooking] Details Exception: $e');
      return null;
    }
  }

  // Balaji: Helper method to format booking date
  // Converts ISO date string to readable format
  static String formatBookingDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';

    try {
      final DateTime date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString; // Return original if parsing fails
    }
  }

  // Balaji: Helper method to format booking date with time
  // Converts ISO date string to readable format with time
  static String formatBookingDateTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';

    try {
      final DateTime date = DateTime.parse(dateString);
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    } catch (e) {
      return dateString; // Return original if parsing fails
    }
  }

  // Balaji: Helper method to format booking time
  // Extracts time from ISO datetime string
  static String formatBookingTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';

    try {
      final DateTime date = DateTime.parse(dateString);
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (e) {
      return 'N/A';
    }
  }

  // Balaji: Get status color based on booking status
  // Returns appropriate color for each status
  static Color getStatusColor(String? status) {
    if (status == null) return Colors.grey;

    switch (status.toLowerCase()) {
      case 'completed':
      case 'delivered':
      case 'done':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  // Balaji: Get status icon based on booking status
  static IconData getStatusIcon(String? status) {
    if (status == null) return Icons.help_outline;

    switch (status.toLowerCase()) {
      case 'completed':
      case 'delivered':
      case 'done':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.local_shipping;
    }
  }
}
