
// lib/utils/booking_utils.dart
import 'package:eshop/Utils/date_time_utils.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class BookingUtils {
  // Private constructor to prevent instantiation
  BookingUtils._();

  // Create pickup address with parsed details
  static Map<String, dynamic> createPickupAddress({
    required String address,
    required String area,
    required String city,
    required String state,
    required String postalCode,
    required LatLng location,
    String country = 'India',
    String label = 'Selected Location',
  }) {
    return {
      'label': label,
      'street': address,
      'area': area.isNotEmpty ? area : 'Selected Area',
      'city': city.isNotEmpty ? city : 'Selected City',
      'state': state.isNotEmpty ? state : 'Selected State',
      'country': country,
      'postalCode': postalCode.isNotEmpty ? postalCode : '000000',
      'coordinates': [location.latitude, location.longitude],
    };
  }

  // Get status color
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'completed':
      case 'done':
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'assigned':
        return Colors.purple;
      case 'accepted':
        return Colors.teal;
      case 'in_progress':
      case 'in-progress':
        return Colors.indigo;
      case 'rejected':
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  // Get status display text
  static String getStatusDisplayText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'completed':
      case 'done':
        return 'Completed';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      case 'assigned':
        return 'Assigned';
      case 'accepted':
        return 'Accepted';
      case 'in_progress':
      case 'in-progress':
        return 'In Progress';
      case 'rejected':
        return 'Rejected';
      default:
        return status.toUpperCase();
    }
  }

  // Get booking type display text
  static String getBookingTypeDisplayText(String bookingType) {
    switch (bookingType.toLowerCase()) {
      case 'instant':
        return 'Instant';
      case 'scheduled':
        return 'Scheduled';
      case 'recurring':
        return 'Recurring';
      default:
        return bookingType.toUpperCase();
    }
  }

  // Get booking type color
  static Color getBookingTypeColor(String bookingType) {
    switch (bookingType.toLowerCase()) {
      case 'instant':
        return Colors.orange;
      case 'scheduled':
        return Colors.blue;
      case 'recurring':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  // Validate booking data
  static bool isValidBooking({
    required String address,
    required LatLng location,
    DateTime? scheduledFor,
  }) {
    if (address.trim().isEmpty) return false;
    if (location.latitude == 0.0 && location.longitude == 0.0) return false;
    if (scheduledFor != null && !scheduledFor.isValidBookingTime) return false;
    return true;
  }

  // Get booking priority
  static int getBookingPriority(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 1;
      case 'confirmed':
        return 2;
      case 'assigned':
        return 3;
      case 'accepted':
        return 4;
      case 'in_progress':
      case 'in-progress':
        return 5;
      case 'completed':
        return 6;
      case 'cancelled':
      case 'rejected':
        return 7;
      default:
        return 0;
    }
  }

  // Check if booking is completed (done/delivered)
  static bool isCompletedBooking(String status) {
    return ['completed', 'done', 'delivered'].contains(status.toLowerCase());
  }

  // Check if booking can be cancelled
  static bool canCancelBooking(String status) {
    return ['pending', 'confirmed', 'scheduled'].contains(status.toLowerCase());
  }

  static bool canModifyBooking(String status) {
    return ['pending', 'scheduled'].contains(status.toLowerCase());
  }

  static String generateBookingReference(String bookingId) {
    if (bookingId.length > 8) {
      return '#${bookingId.substring(bookingId.length - 8).toUpperCase()}';
    }
    return '#${bookingId.toUpperCase()}';
  }

  // Format address for display
  static String formatAddress({
    required String street,
    required String area,
    required String city,
    required String state,
    bool showState = true,
    int maxLength = 100,
  }) {
    final parts = <String>[];

    if (street.isNotEmpty) parts.add(street);
    if (area.isNotEmpty) parts.add(area);
    if (city.isNotEmpty) parts.add(city);
    if (showState && state.isNotEmpty) parts.add(state);

    final fullAddress = parts.join(', ');

    if (fullAddress.length <= maxLength) {
      return fullAddress;
    }

    return '${fullAddress.substring(0, maxLength - 3)}...';
  }
}