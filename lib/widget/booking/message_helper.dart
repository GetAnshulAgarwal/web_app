
/*import 'package:flutter/material.dart';

enum MessageType { info, success, error, warning }

class MessageHelper {
  // Main method that handles all message types
  static void showMessage({
    required BuildContext context,
    required String message,
    required MessageType type,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    if (!_isMounted(context)) return;

    final config = _getMessageConfig(type);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              config.icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: config.backgroundColor,
        duration: duration ?? config.defaultDuration,
        action: actionLabel != null && onActionPressed != null
            ? SnackBarAction(
          label: actionLabel,
          textColor: Colors.white,
          onPressed: onActionPressed,
        )
            : null,
      ),
    );
  }

  // Convenience methods for each message type
  static void showInfo({
    required BuildContext context,
    required String message,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    showMessage(
      context: context,
      message: message,
      type: MessageType.info,
      duration: duration,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
    );
  }

  static void showSuccess({
    required BuildContext context,
    required String message,
    Duration? duration,
  }) {
    showMessage(
      context: context,
      message: message,
      type: MessageType.success,
      duration: duration,
    );
  }

  static void showError({
    required BuildContext context,
    required String message,
    Duration? duration,
  }) {
    showMessage(
      context: context,
      message: message,
      type: MessageType.error,
      duration: duration,
    );
  }

  static void showWarning({
    required BuildContext context,
    required String message,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    showMessage(
      context: context,
      message: message,
      type: MessageType.warning,
      duration: duration,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
    );
  }

  // Helper method to check if context is mounted
  static bool _isMounted(BuildContext context) {
    return context.mounted;
  }

  // Get configuration for each message type
  static _MessageConfig _getMessageConfig(MessageType type) {
    switch (type) {
      case MessageType.info:
        return _MessageConfig(
          icon: Icons.info_outline,
          backgroundColor: Colors.blue,
          defaultDuration: const Duration(seconds: 4),
        );
      case MessageType.success:
        return _MessageConfig(
          icon: Icons.check_circle,
          backgroundColor: Colors.green,
          defaultDuration: const Duration(seconds: 2),
        );
      case MessageType.error:
        return _MessageConfig(
          icon: Icons.error_outline,
          backgroundColor: Colors.red,
          defaultDuration: const Duration(seconds: 3),
        );
      case MessageType.warning:
        return _MessageConfig(
          icon: Icons.warning_outlined,
          backgroundColor: Colors.orange,
          defaultDuration: const Duration(seconds: 3),
        );
    }
  }
}

// Configuration class for message types
class _MessageConfig {
  final IconData icon;
  final Color backgroundColor;
  final Duration defaultDuration;

  const _MessageConfig({
    required this.icon,
    required this.backgroundColor,
    required this.defaultDuration,
  });
}*/