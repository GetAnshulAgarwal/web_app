// lib/widget/booking/action_buttons_widget.dart
import 'package:flutter/material.dart';
import '../../services/api_service_for_van.dart';

class ActionButtonsWidget {
  final VanRouteApiService apiService;
  final VoidCallback onBookNow;
  final VoidCallback onScheduleBooking;
  final BuildContext context;

  ActionButtonsWidget({
    required this.apiService,
    required this.onBookNow,
    required this.onScheduleBooking,
    required this.context,
  });

  // Main action buttons container
  Widget buildActionButtons() {
    final isLoggedIn = apiService.isUserLoggedIn();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Login status indicator (only show if not logged in)
          if (!isLoggedIn)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Login required to book a van',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange.shade700,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                    child: const Text('Login'),
                  ),
                ],
              ),
            ),

          // Action buttons row
          Row(
            children: [
              // Book Now Button
              ElevatedButton(
                onPressed: isLoggedIn ? onBookNow : null, // This now correctly points to _scheduleVanBooking
                style: ElevatedButton.styleFrom(
                  backgroundColor:  Colors.red,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade400,
                  disabledForegroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Book Now',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Divider
              Container(
                width: 1,
                height: 60,
                color: Colors.grey.shade300,
              ),

              const SizedBox(width: 16),



              // Schedule VAN Booking section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schedule VAN',
                      style: TextStyle(
                        color: const Color(0xFFB21E1E),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'BOOKING',
                      style: TextStyle(
                        color: const Color(0xFFB21E1E),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Book for later',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Schedule icon button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white),
                ),
                child: IconButton(
                  onPressed: isLoggedIn ? onScheduleBooking : null, // This also correctly points to _scheduleVanBooking
                  icon: Icon(
                    Icons.schedule,
                    color: isLoggedIn ? Colors.red : Colors.red,
                    size: 25,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  // Individual action button widget
  Widget buildActionButton({
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
    bool enabled = true,
    bool isComingSoon = false,
  }) {
    return GestureDetector(
      onTap: enabled && !isComingSoon ? onTap : null, // Disable tap if coming soon
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isComingSoon
                              ? Colors.orange.shade600
                              : (enabled
                              ? const Color(0xFFB21E1E)
                              : Colors.grey),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isComingSoon
                              ? Colors.orange.shade600
                              : (enabled
                              ? const Color(0xFFB21E1E)
                              : Colors.grey),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          color: isComingSoon
                              ? Colors.orange.shade600
                              : (enabled
                              ? Colors.grey.shade600
                              : Colors.grey.shade400),
                          fontSize: 10,
                          fontWeight: isComingSoon
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  icon,
                  color: isComingSoon
                      ? Colors.orange.shade600
                      : (enabled
                      ? const Color(0xFFB21E1E)
                      : Colors.grey.shade400),
                  size: 24,
                ),
              ],
            ),
            // Coming soon badge
            if (isComingSoon)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Text(
                    'SOON',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Alternative: Build action buttons with custom configuration
  Widget buildCustomActionButtons({
    required List<ActionButtonConfig> buttons,
    bool showLoginPrompt = true,
  }) {
    final isLoggedIn = apiService.isUserLoggedIn();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          // Login status indicator
          if (!isLoggedIn && showLoginPrompt)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                      Icons.info_outline,
                      color: Colors.red
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Login required for some features',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                    child: const Text('Login'),
                  ),
                ],
              ),
            ),

          // Action buttons row
          Row(
            children: buttons.map((button) => Expanded(
              child: Row(
                children: [
                  if (buttons.indexOf(button) > 0)
                    Container(width: 1, height: 60, color: Colors.grey.shade300),
                  Expanded(
                    child: buildActionButton(
                      title: button.title,
                      subtitle: button.subtitle,
                      description: button.getDescription(isLoggedIn),
                      icon: button.icon,
                      onTap: button.onTap,
                      enabled: button.isEnabled(isLoggedIn),
                      isComingSoon: button.isComingSoon,
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

// Configuration class for flexible action buttons
class ActionButtonConfig {
  final String title;
  final String subtitle;
  final String loggedInDescription;
  final String loggedOutDescription;
  final IconData icon;
  final VoidCallback onTap;
  final bool requiresLogin;
  final bool isComingSoon;

  ActionButtonConfig({
    required this.title,
    required this.subtitle,
    required this.loggedInDescription,
    required this.loggedOutDescription,
    required this.icon,
    required this.onTap,
    this.requiresLogin = false,
    this.isComingSoon = false,
  });

  String getDescription(bool isLoggedIn) {
    return isLoggedIn ? loggedInDescription : loggedOutDescription;
  }

  bool isEnabled(bool isLoggedIn) {
    return !requiresLogin || isLoggedIn;
  }
}