// lib/utils/date_time_utils.dart
import 'package:intl/intl.dart';

class DateTimeUtils {
  // Private constructor to prevent instantiation
  DateTimeUtils._();

  // Format date time for display
  static String formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bookingDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (bookingDate == today) {
      return 'Today ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (bookingDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  // Format date time with full format
  static String formatDateTimeFull(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  // Format date only
  static String formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (date == today) {
      return 'Today';
    } else if (date == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else if (date == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }

  // Format time only
  static String formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  // Format for booking display
  static String formatForBooking(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inDays == 0) {
      if (difference.inHours > 0) {
        return 'Today at ${formatTime(dateTime)}';
      } else if (difference.inMinutes > 0) {
        return 'In ${difference.inMinutes} minutes';
      } else {
        return 'Now';
      }
    } else if (difference.inDays == 1) {
      return 'Tomorrow at ${formatTime(dateTime)}';
    } else if (difference.inDays > 1 && difference.inDays <= 7) {
      return 'In ${difference.inDays} days at ${formatTime(dateTime)}';
    } else {
      return formatDateTimeFull(dateTime);
    }
  }

  // Format relative time (e.g., "2 hours ago")
  static String formatRelative(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  // Check if date is today
  static bool isToday(DateTime dateTime) {
    final now = DateTime.now();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }

  // Check if date is tomorrow
  static bool isTomorrow(DateTime dateTime) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return dateTime.year == tomorrow.year &&
        dateTime.month == tomorrow.month &&
        dateTime.day == tomorrow.day;
  }

  // Check if date is in the past
  static bool isPast(DateTime dateTime) {
    return dateTime.isBefore(DateTime.now());
  }

  // Check if date is in the future
  static bool isFuture(DateTime dateTime) {
    return dateTime.isAfter(DateTime.now());
  }

  // Get time until/since date
  static String getTimeUntil(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.isNegative) {
      return 'Overdue by ${formatDuration(difference.abs())}';
    } else {
      return 'Due in ${formatDuration(difference)}';
    }
  }

  // Format duration
  static String formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays == 1 ? '' : 's'}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours == 1 ? '' : 's'}';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} minute${duration.inMinutes == 1 ? '' : 's'}';
    } else {
      return '${duration.inSeconds} second${duration.inSeconds == 1 ? '' : 's'}';
    }
  }

  // Parse string to DateTime with error handling
  static DateTime? parseDateTime(String dateTimeString) {
    try {
      return DateTime.parse(dateTimeString);
    } catch (e) {
      print('Error parsing date time: $e');
      return null;
    }
  }

  // Validate if datetime is in valid booking range
  static bool isValidBookingTime(DateTime dateTime) {
    final now = DateTime.now();
    final minimumBookingTime = now.add(const Duration(minutes: 30));
    final maximumBookingTime = now.add(const Duration(days: 30));

    return dateTime.isAfter(minimumBookingTime) &&
        dateTime.isBefore(maximumBookingTime);
  }

  // Get next available booking slot
  static DateTime getNextAvailableSlot() {
    return DateTime.now().add(const Duration(minutes: 30));
  }
}

// Extension for easy usage on DateTime objects
extension DateTimeExtension on DateTime {
  String toDisplayFormat() => DateTimeUtils.formatDateTime(this);
  String toFullFormat() => DateTimeUtils.formatDateTimeFull(this);
  String toDateOnly() => DateTimeUtils.formatDate(this);
  String toTimeOnly() => DateTimeUtils.formatTime(this);
  String toBookingFormat() => DateTimeUtils.formatForBooking(this);
  String toRelativeFormat() => DateTimeUtils.formatRelative(this);
  bool get isToday => DateTimeUtils.isToday(this);
  bool get isTomorrow => DateTimeUtils.isTomorrow(this);
  bool get isPast => DateTimeUtils.isPast(this);
  bool get isFuture => DateTimeUtils.isFuture(this);
  bool get isValidBookingTime => DateTimeUtils.isValidBookingTime(this);
}