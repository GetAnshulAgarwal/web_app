// Add this class to your VanRouteApiService file if it doesn't exist
import 'VanRoute_model.dart';

class BookingCancelResponse {
  final bool success;
  final String message;
  final UserBooking? booking;

  BookingCancelResponse({
    required this.success,
    required this.message,
    this.booking,
  });
}