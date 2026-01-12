import 'package:flutter/material.dart';
import '../../utils/booking/booking_utils.dart';
import '../../model/van_booking/VanRoute_model.dart';
import '../../services/api_service_for_van.dart';
import '../../utils/date_time_utils.dart';

class BookingWidgets {
  final VanRouteApiService apiService;
  final List<UserBooking> userBookings;
  final bool isLoadingBookings;
  final VoidCallback? retryLoadBookings;
  final Function(UserBooking) showBookingDetails;
  final BuildContext context;

  BookingWidgets({
    required this.apiService,
    required this.userBookings,
    required this.isLoadingBookings,
    this.retryLoadBookings,
    required this.showBookingDetails,
    required this.context,
  });

  // Enhanced booking list with pull-to-refresh and tap-to-view details
  Widget buildBookingsList() {
    if (isLoadingBookings) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: Color(0xFFB21E1E)),
        ),
      );
    }

    if (userBookings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text(
              'No active bookings',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your active van bookings will appear here.\nCompleted bookings are in the Profile section.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            // Removed the Refresh button from here
          ],
        ),
      );
    }

    // Only show RefreshIndicator if retryLoadBookings is not null
    if (retryLoadBookings != null) {
      return RefreshIndicator(
        onRefresh: () async {
          retryLoadBookings!();
          await Future.delayed(const Duration(milliseconds: 500));
        },
        color: const Color(0xFFB21E1E),
        child: ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: userBookings.length,
          itemBuilder: (context, index) {
            final booking = userBookings[index];
            return GestureDetector(
              onTap: () => showBookingDetails(booking),
              child: buildBookingCard(booking),
            );
          },
        ),
      );
    }

    // If retryLoadBookings is null, just show the list without RefreshIndicator
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: userBookings.length,
      itemBuilder: (context, index) {
        final booking = userBookings[index];
        return GestureDetector(
          onTap: () => showBookingDetails(booking),
          child: buildBookingCard(booking),
        );
      },
    );
  }

  // Enhanced booking card with more details and tap interaction
  Widget buildBookingCard(UserBooking booking) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showBookingDetails(booking),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: BookingUtils.getStatusColor(booking.status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            BookingUtils.generateBookingReference(booking.id),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            BookingUtils.getStatusDisplayText(booking.status),
                            style: TextStyle(
                              fontSize: 11,
                              color: BookingUtils.getStatusColor(booking.status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: BookingUtils.getBookingTypeColor(booking.bookingType).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        BookingUtils.getBookingTypeDisplayText(booking.bookingType),
                        style: TextStyle(
                          fontSize: 9,
                          color: BookingUtils.getBookingTypeColor(booking.bookingType),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Address
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        BookingUtils.formatAddress(
                          street: booking.pickupAddress.street,
                          area: booking.pickupAddress.area,
                          city: booking.pickupAddress.city,
                          state: booking.pickupAddress.state ?? '',
                          maxLength: 60,
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Scheduled time if available
                if (booking.scheduledFor != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Scheduled: ${booking.scheduledFor!.toBookingFormat()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],

                // Remark if available (shortened)
                if (booking.remark.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.note_outlined,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          booking.remark,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // Created date and status info
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Created: ${booking.createdAt.toRelativeFormat()}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    // Show action indicators based on booking status
                    if (BookingUtils.canCancelBooking(booking.status))
                      Icon(
                        Icons.cancel_outlined,
                        size: 12,
                        color: Colors.orange.shade600,
                      ),
                    if (BookingUtils.canModifyBooking(booking.status)) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.edit_outlined,
                        size: 12,
                        color: Colors.blue.shade600,
                      ),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      'Tap for details',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Enhanced bookings section with fallback status indicator
  Widget buildBookingsSection() {
    final isLoggedIn = apiService.isUserLoggedIn();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildBookingsHeader(),
          const SizedBox(height: 12),
          isLoggedIn ? buildBookingsList() : buildLoginPrompt(),
        ],
      ),
    );
  }

  // Enhanced bookings header with status indicator
  Widget buildBookingsHeader() {
    final debugInfo = apiService.getUserDebugInfo();
    final usingTempData = debugInfo['tempBookingsCount'] > 0;
    final isLoggedIn = apiService.isUserLoggedIn();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  "MY BOOKINGS",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF783F04),
                  ),
                ),
                if (userBookings.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${userBookings.length}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Row(
              children: [
                if (usingTempData && isLoggedIn)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Recent',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                // Only show refresh button if retryLoadBookings is not null and user is logged in
                if (isLoggedIn && retryLoadBookings != null) ...[
                  if (usingTempData) const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: retryLoadBookings,
                    tooltip: 'Refresh bookings',
                  ),
                ] else if (!isLoggedIn)
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        color: Color(0xFFB21E1E),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (usingTempData && isLoggedIn)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    retryLoadBookings != null
                        ? 'Showing recent bookings. Tap refresh to sync with server.'
                        : 'Showing recent bookings.',
                    style: const TextStyle(fontSize: 11, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Login prompt widget
  Widget buildLoginPrompt() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.login, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'Login to view your bookings',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to see your van booking history',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB21E1E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Login Now'),
          ),
        ],
      ),
    );
  }
}