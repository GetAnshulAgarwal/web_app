// lib/utils/snackbar_utils.dart
import 'package:flutter/material.dart';

import 'booking_utils.dart';

class SnackbarUtils {
  // Private constructor to prevent instantiation
  SnackbarUtils._();

  // Default durations
  static const Duration _defaultInfoDuration = Duration(seconds: 4);
  static const Duration _defaultSuccessDuration = Duration(seconds: 2);
  static const Duration _defaultErrorDuration = Duration(seconds: 3);
  static const Duration _defaultWarningDuration = Duration(seconds: 3);

  // Show info message with retry action
  static void showInfo(
      BuildContext context,
      String message, {
        VoidCallback? onRetry,
        String retryLabel = 'Retry',
        Duration? duration,
        bool showIcon = true,
      }) {
    if (!_isContextValid(context)) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (showIcon) ...[
              const Icon(Icons.info_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: duration ?? _defaultInfoDuration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: onRetry != null
            ? SnackBarAction(
          label: retryLabel,
          textColor: Colors.white,
          onPressed: onRetry,
        )
            : null,
      ),
    );
  }

  // Show success message
  static void showSuccess(
      BuildContext context,
      String message, {
        Duration? duration,
        bool showIcon = true,
        VoidCallback? onAction,
        String actionLabel = 'OK',
      }) {
    if (!_isContextValid(context)) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (showIcon) ...[
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: duration ?? _defaultSuccessDuration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: onAction != null
            ? SnackBarAction(
          label: actionLabel,
          textColor: Colors.white,
          onPressed: onAction,
        )
            : null,
      ),
    );
  }

  // Show error message
  static void showError(
      BuildContext context,
      String message, {
        Duration? duration,
        bool showIcon = true,
        VoidCallback? onRetry,
        String retryLabel = 'Retry',
      }) {
    if (!_isContextValid(context)) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (showIcon) ...[
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: duration ?? _defaultErrorDuration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: onRetry != null
            ? SnackBarAction(
          label: retryLabel,
          textColor: Colors.white,
          onPressed: onRetry,
        )
            : null,
      ),
    );
  }

  // Show warning message
  static void showWarning(
      BuildContext context,
      String message, {
        Duration? duration,
        bool showIcon = true,
        VoidCallback? onAction,
        String actionLabel = 'OK',
      }) {
    if (!_isContextValid(context)) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (showIcon) ...[
              const Icon(Icons.warning_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: duration ?? _defaultWarningDuration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: onAction != null
            ? SnackBarAction(
          label: actionLabel,
          textColor: Colors.white,
          onPressed: onAction,
        )
            : null,
      ),
    );
  }

  // Show custom snackbar with custom colors and styling
  static void showCustom(
      BuildContext context,
      String message, {
        required Color backgroundColor,
        Color textColor = Colors.white,
        IconData? icon,
        Duration? duration,
        VoidCallback? onAction,
        String actionLabel = 'Action',
        Color? actionTextColor,
      }) {
    if (!_isContextValid(context)) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: textColor),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration ?? _defaultInfoDuration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: onAction != null
            ? SnackBarAction(
          label: actionLabel,
          textColor: actionTextColor ?? textColor,
          onPressed: onAction,
        )
            : null,
      ),
    );
  }

  // Show loading message with progress indicator
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showLoading(
      BuildContext context,
      String message, {
        bool showProgressIndicator = true,
      }) {
    if (!_isContextValid(context)) {
      throw Exception('Invalid context provided to showLoading');
    }

    return ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (showProgressIndicator) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF2196F3),
        duration: const Duration(minutes: 1), // Long duration for loading
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // Hide current snackbar
  static void hide(BuildContext context) {
    if (!_isContextValid(context)) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  // Clear all snackbars
  static void clearAll(BuildContext context) {
    if (!_isContextValid(context)) return;
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  // Show API error with specific handling
// Add this method to your existing SnackbarUtils class
  static void showApiError(
      BuildContext context,
      String error, {
        VoidCallback? onRetry,
        Duration? duration,
      }) {
    String message = 'Something went wrong. Please try again.';

    // Parse common API errors
    if (error.contains('TimeoutException')) {
      message = 'Request timed out. Please check your connection.';
    } else if (error.contains('SocketException')) {
      message = 'No internet connection. Please check your network.';
    } else if (error.contains('Authentication failed')) {
      message = 'Authentication failed. Please login again.';
    } else if (error.contains('Session expired')) {
      message = 'Session expired. Please login again.';
    } else if (error.contains('API Error')) {
      final match = RegExp(r'API Error \d+: (.+)').firstMatch(error);
      if (match != null) {
        message = match.group(1) ?? message;
      }
    } else if (error.contains('Failed to cancel booking:')) {
      message = error.replaceFirst('Failed to cancel booking:', '').trim();
      if (message.isEmpty) message = 'Unable to cancel booking right now.';
    }

    showError(
      context,
      message,
      onRetry: onRetry,
      duration: duration ?? const Duration(seconds: 5),
    );
  }

  // Show booking-specific success message
  static void showBookingSuccess(
      BuildContext context,
      String bookingId, {
        VoidCallback? onViewBooking,
      }) {
    showSuccess(
      context,
      'Booking created successfully! ID: ${bookingId.substring(0, 8)}',
      onAction: onViewBooking,
      actionLabel: 'View',
      duration: const Duration(seconds: 4),
    );
  }

  // Show network status message
  static void showNetworkStatus(
      BuildContext context,
      bool isOnline,
      ) {
    if (isOnline) {
      showSuccess(
        context,
        'Connection restored',
        duration: const Duration(seconds: 2),
      );
    } else {
      showWarning(
        context,
        'No internet connection. Some features may not work.',
        duration: const Duration(seconds: 5),
      );
    }
  }

  // Validation helper
  static bool _isContextValid(BuildContext context) {
    return context.mounted;
  }
}

// Enum for predefined snackbar types
enum SnackbarType {
  info,
  success,
  error,
  warning,
}

// Extension for easy usage
extension SnackbarExtension on BuildContext {
  void showInfoSnackbar(String message, {VoidCallback? onRetry}) {
    SnackbarUtils.showInfo(this, message, onRetry: onRetry);
  }

  void showSuccessSnackbar(String message) {
    SnackbarUtils.showSuccess(this, message);
  }

  void showErrorSnackbar(String message, {VoidCallback? onRetry}) {
    SnackbarUtils.showError(this, message, onRetry: onRetry);
  }

  void showWarningSnackbar(String message) {
    SnackbarUtils.showWarning(this, message);
  }
}

// Add this to the bottom of your SnackbarUtils file
extension BookingSnackbarExtension on BuildContext {
  void showBookingCancelled(String bookingId, {VoidCallback? onBookAgain}) {
    SnackbarUtils.showCustom(
      this,
      'Booking ${BookingUtils.generateBookingReference(bookingId)} cancelled successfully',
      backgroundColor: Colors.orange,
      icon: Icons.cancel_outlined,
      onAction: onBookAgain,
      actionLabel: 'Book Again',
      duration: const Duration(seconds: 4),
    );
  }

  void showCancellationFailed(String error, {VoidCallback? onRetry}) {
    SnackbarUtils.showError(
      this,
      'Failed to cancel booking: $error',
      onRetry: onRetry,
      duration: const Duration(seconds: 6),
    );
  }
}