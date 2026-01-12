import 'dart:math';

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../services/van_booking_service.dart';
import '../../utils/booking/booking_utils.dart';
import 'package:provider/provider.dart';
import '../../providers/booking_provider.dart';

class MyVanBookingsScreen extends StatefulWidget {
  const MyVanBookingsScreen({super.key});

  @override
  State<MyVanBookingsScreen> createState() => _MyVanBookingsScreenState();
}

class _MyVanBookingsScreenState extends State<MyVanBookingsScreen> {
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = false;
  String? _errorMessage;
  final dummyBooking = {
    "_id": "69159d20e3f28238920698c1",
    "status": "completed",
    "type": "instant",
    "createdAt": "2025-02-01T10:30:00Z",
    "pickupAddress": {
      "house": "221B",
      "area": "Baker Street",
      "city": "London",
    },
    "order": {
      "_id": "ORDER123",
      "items": [
        {
          "itemName": "Cinnamon (Dalchini), 200 g",
          "quantity": 6,
          "price": 20,
          "subtotal": 120,
        },
        {
          "itemName": "Cinnamon (Dalchini), 200 g",
          "quantity": 6,
          "price": 20,
          "subtotal": 120,
        },
        {
          "itemName": "Cinnamon (Dalchini), 200 g",
          "quantity": 7,
          "price": 20,
          "subtotal": 120,
        },
      ],
      "totalAmount": 120,
      "payments": [
        {"paymentType": "Cash", "amount": 120},
      ],
    },
  };

  // Listen to provider changes to update UI instantly when bookings change
  late final BookingProvider? _bookingProvider;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Try to load completed bookings from local Hive cache first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Keep a reference to the provider so we can listen for updates
      _bookingProvider = Provider.of<BookingProvider>(context, listen: false);

      // Load initial bookings and then listen for provider changes
      _loadBookings();

      // Update UI instantly when provider notifies (e.g., saveCompletedBooking)
      _bookingProvider?.addListener(_onBookingProviderChanged);

      // Also perform a periodic silent refresh in background (every 30s)
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) unawaited(_offloadRefreshCompletedBookings());
      });
    });
  }

  void _onBookingProviderChanged() {
    if (!mounted) return;
    setState(() {
      _bookings = _bookingProvider?.completedBookings ?? [];
      _isLoading = false;
    });
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bookingProvider = Provider.of<BookingProvider>(
        context,
        listen: false,
      );

      // Load provider boxes (ensures Hive boxes opened)
      await bookingProvider.load();

      final localCompleted = bookingProvider.completedBookings;
      // If we have cached completed bookings, show them immediately.
      if (localCompleted.isNotEmpty) {
        setState(() {
          _bookings = localCompleted;
          _isLoading = false;
          print('Loaded local completed bookings:');
          print(_bookings);
        });
        return;
      }

      // No cached completed bookings: show empty state immediately and
      // offload a background refresh to populate Hive so UI can update later.
      setState(() {
        _bookings = [];
        _isLoading = false;
      });

      // Offload network refresh in background (do not await)
      unawaited(_offloadRefreshCompletedBookings());
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load bookings: $e';
        _isLoading = false;
      });
    }
  }

  /// Background fetch to update completed bookings in Hive without blocking UI.
  Future<void> _offloadRefreshCompletedBookings() async {
    try {
      final bookingProvider = Provider.of<BookingProvider>(
        context,
        listen: false,
      );

      final bookings = await VanBookingService.getMyBookings();
      final completed =
          bookings
              .where(
                (b) =>
                    !(b['status'] != null &&
                        BookingUtils.canCancelBooking(b['status'])),
              )
              .toList();

      if (completed.isNotEmpty) {
        await bookingProvider.saveCompletedFromDynamicList(completed);

        // If this screen is still mounted, reload local completed from provider
        if (mounted) {
          final local = bookingProvider.completedBookings;
          setState(() {
            _bookings = local;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Background completed bookings refresh failed: $e');
    }
  }

  Future<void> _onRefresh() async {
    try {
      setState(() => _isLoading = true);
      final bookings = await VanBookingService.getMyBookings();
      final completed =
          bookings
              .where(
                (b) =>
                    !(b['status'] != null &&
                        BookingUtils.canCancelBooking(b['status'])),
              )
              .toList();
      final bookingProvider = Provider.of<BookingProvider>(
        context,
        listen: false,
      );
      if (completed.isNotEmpty)
        await bookingProvider.saveCompletedFromDynamicList(completed);
      setState(() {
        _bookings = completed.isNotEmpty ? completed : bookings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Refresh failed: $e')));
    }
  }

  @override
  void dispose() {
    try {
      _bookingProvider?.removeListener(_onBookingProviderChanged);
    } catch (_) {}
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _showBookingDetails(
    String bookingId, [
    Map<String, dynamic>? existingBookingData,
  ]) async {
    // Use existing booking data if available to show details immediately
    if (existingBookingData != null) {
      _showBookingDetailsDialog(existingBookingData);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final details = await VanBookingService.getBookingDetails(bookingId);
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (details != null) {
        // Merge existing data with fetched details (fetched details take priority)
        final mergedDetails =
            existingBookingData != null
                ? {...existingBookingData, ...details}
                : details;

        // Close previous dialog if it exists and show updated one
        if (existingBookingData != null && mounted) {
          Navigator.pop(context);
        }

        _showBookingDetailsDialog(mergedDetails);

        // Debug: Print what we got from API
        print(
          '📋 [Booking Details] API Response keys: ${details.keys.toList()}',
        );
        print('📋 [Booking Details] Full response: $details');
      } else {
        // If API call fails, still show what we have from existing data
        if (existingBookingData != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Showing cached booking data. Some details may be incomplete.',
              ),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load booking details')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // If we have existing data, still show it
      if (existingBookingData != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Using cached data. Error loading details: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showBookingDetailsDialog(Map<String, dynamic> details) {
    // Debug: Print all available keys in the details map
    print('🔍 [Booking Dialog] Available keys: ${details.keys.toList()}');
    print('🔍 [Booking Dialog] Details: $details');

    // Helper function to safely extract values with multiple fallbacks
    String safeGet(dynamic value, [String defaultValue = 'N/A']) {
      if (value == null) return defaultValue;
      final str = value.toString().trim();
      return str.isEmpty ? defaultValue : str;
    }

    // helper id formatter removed (previously unused)

    // Helper to extract nested values
    dynamic getNested(Map<String, dynamic> map, List<String> keys) {
      for (final key in keys) {
        if (map.containsKey(key) && map[key] != null) {
          return map[key];
        }
      }
      return null;
    }

    // Extract all available fields with comprehensive fallbacks
    // Try direct access first, then nested access
    final rawBookingId =
        getNested(details, ['_id', 'id', 'bookingId', 'booking_id']) ??
        details['_id'] ??
        details['id'] ??
        details['bookingId'] ??
        details['booking_id'];
    final bookingId = rawBookingId != null ? rawBookingId.toString() : 'N/A';

    final typeValue =
        getNested(details, ['type', 'bookingType', 'booking_type']) ??
        details['type'] ??
        details['bookingType'] ??
        details['booking_type'];
    // Prefer explicit type fields; fall back to 'instant' to avoid showing 'N/A'
    final type =
        (typeValue ?? details['type'] ?? details['bookingType'] ?? 'instant')
            .toString()
            .toUpperCase();

    final statusValue =
        getNested(details, [
          'status',
          'Status',
          'bookingStatus',
          'booking_status',
        ]) ??
        details['status'] ??
        details['Status'] ??
        details['bookingStatus'] ??
        details['booking_status'];
    final status = safeGet(statusValue, 'N/A').toUpperCase();

    final remarkValue =
        getNested(details, [
          'remark',
          'remarks',
          'notes',
          'message',
          'description',
        ]) ??
        details['remark'] ??
        details['remarks'] ??
        details['notes'] ??
        details['message'] ??
        details['description'];
    final remark = safeGet(remarkValue, '');

    // Date fields - try multiple formats
    final createdAt =
        getNested(details, [
          'createdAt',
          'created_at',
          'created',
          'createdAt',
        ]) ??
        details['createdAt'] ??
        details['created_at'] ??
        details['created'];
    final scheduledFor =
        getNested(details, [
          'scheduledFor',
          'scheduled_for',
          'scheduled',
          'scheduledDateTime',
          'scheduled_date_time',
        ]) ??
        details['scheduledFor'] ??
        details['scheduled_for'] ??
        details['scheduled'] ??
        details['scheduledDateTime'] ??
        details['scheduled_date_time'];
    final updatedAt =
        getNested(details, [
          'updatedAt',
          'updated_at',
          'updated',
          'modifiedAt',
          'modified_at',
        ]) ??
        details['updatedAt'] ??
        details['updated_at'] ??
        details['updated'] ??
        details['modifiedAt'] ??
        details['modified_at'];
    final completedAt =
        getNested(details, [
          'completedAt',
          'completed_at',
          'completed',
          'completedDateTime',
        ]) ??
        details['completedAt'] ??
        details['completed_at'] ??
        details['completed'] ??
        details['completedDateTime'];
    final deliveredAt =
        getNested(details, [
          'deliveredAt',
          'delivered_at',
          'delivered',
          'deliveredDateTime',
        ]) ??
        details['deliveredAt'] ??
        details['delivered_at'] ??
        details['delivered'] ??
        details['deliveredDateTime'];

    // Address extraction - handle both direct and nested structures
    final pickupAddress =
        getNested(details, [
          'pickupAddress',
          'pickup_address',
          'address',
          'pickup',
        ]) ??
        details['pickupAddress'] ??
        details['pickup_address'] ??
        details['address'] ??
        details['pickup'];

    final deliveryAddress =
        getNested(details, [
          'deliveryAddress',
          'delivery_address',
          'delivery',
        ]) ??
        details['deliveryAddress'] ??
        details['delivery_address'] ??
        details['delivery'];

    // Additional fields
    final bookingTypeValue =
        getNested(details, ['bookingType', 'booking_type', 'type']) ??
        details['bookingType'] ??
        details['booking_type'] ??
        type;
    final bookingType = bookingTypeValue?.toString() ?? type;

    final userId =
        getNested(details, [
          'userId',
          'user_id',
          'user',
          'customerId',
          'customer_id',
        ]) ??
        details['userId'] ??
        details['user_id'] ??
        details['user'] ??
        details['customerId'] ??
        details['customer_id'];

    final vanId =
        getNested(details, [
          'vanId',
          'van_id',
          'van',
          'vehicleId',
          'vehicle_id',
        ]) ??
        details['vanId'] ??
        details['van_id'] ??
        details['van'] ??
        details['vehicleId'] ??
        details['vehicle_id'];

    final driverId =
        getNested(details, ['driverId', 'driver_id', 'driver']) ??
        details['driverId'] ??
        details['driver_id'] ??
        details['driver'];

    final routeId =
        getNested(details, ['routeId', 'route_id', 'route']) ??
        details['routeId'] ??
        details['route_id'] ??
        details['route'];

    // Avoid analyzer unused variable warnings by logging extracted ids in debug mode
    debugPrint(
      'Booking related ids -> user: $userId, van: $vanId, driver: $driverId, route: $routeId',
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Row(
              children: [
                Icon(
                  VanBookingService.getStatusIcon(status),
                  color: VanBookingService.getStatusColor(status),
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Booking Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Basic Information
                  _buildDetailRow(
                    'Booking ID',
                    bookingId,
                    null,
                    true,
                  ), // Always show Booking ID
                  _buildDetailRow(
                    'Type',
                    bookingType.toString().toUpperCase(),
                    null,
                    true,
                  ),
                  _buildDetailRow(
                    'Status',
                    status,
                    VanBookingService.getStatusColor(status),
                    true,
                  ), // Always show Status

                  const Divider(),

                  // Address Information
                  const Text(
                    'Pickup Address:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatAddress(pickupAddress),
                    style: const TextStyle(fontSize: 13),
                  ),

                  // Delivery Address if different from pickup
                  if (deliveryAddress != null &&
                      deliveryAddress != pickupAddress) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Delivery Address:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatAddress(deliveryAddress),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],

                  const Divider(),

                  // Date/Time Information
                  if (scheduledFor != null)
                    _buildDetailRow(
                      'Scheduled For',
                      VanBookingService.formatBookingDateTime(
                        scheduledFor.toString(),
                      ),
                    ),

                  if (createdAt != null)
                    _buildDetailRow(
                      'Created At',
                      VanBookingService.formatBookingDateTime(
                        createdAt.toString(),
                      ),
                    ),

                  if (updatedAt != null && updatedAt != createdAt)
                    _buildDetailRow(
                      'Last Updated',
                      VanBookingService.formatBookingDateTime(
                        updatedAt.toString(),
                      ),
                    ),

                  if (completedAt != null)
                    _buildDetailRow(
                      'Completed At',
                      VanBookingService.formatBookingDateTime(
                        completedAt.toString(),
                      ),
                    ),

                  if (deliveredAt != null)
                    _buildDetailRow(
                      'Delivered At',
                      VanBookingService.formatBookingDateTime(
                        deliveredAt.toString(),
                      ),
                    ),

                  // Additional Information
                  if (remark.isNotEmpty && remark != 'N/A') ...[
                    const Divider(),
                    _buildDetailRow('Remark', remark),
                  ],

                  // Related IDs (if available)
                  // if (vanId != null && vanId != 'N/A') ...[
                  //   const Divider(),
                  //   const Text(
                  //     'Related Information:',
                  //     style: TextStyle(
                  //       fontWeight: FontWeight.bold,
                  //       fontSize: 12,
                  //     ),
                  //   ),
                  //   const SizedBox(height: 4),
                  //   if (userId != null && userId != 'N/A')
                  //     _buildDetailRow(
                  //       'User ID',
                  //       safeGetId(userId),
                  //       Colors.grey,
                  //     ),
                  //   if (vanId != null && vanId != 'N/A')
                  //     _buildDetailRow('Van ID', safeGetId(vanId), Colors.grey),
                  //   if (driverId != null && driverId != 'N/A')
                  //     _buildDetailRow(
                  //       'Driver ID',
                  //       safeGetId(driverId),
                  //       Colors.grey,
                  //     ),
                  //   if (routeId != null && routeId != 'N/A')
                  //     _buildDetailRow(
                  //       'Route ID',
                  //       safeGetId(routeId),
                  //       Colors.grey,
                  //     ),
                  // ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, [
    Color? valueColor,
    bool alwaysShow = false,
  ]) {
    // Don't show rows with N/A or empty values (except for required fields like Booking ID, Status)
    // Use alwaysShow flag for important fields that should always be displayed
    if (!alwaysShow && (value == 'N/A' || value.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'N/A' : value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? Colors.black87,
                fontWeight:
                    valueColor != null ? FontWeight.w600 : FontWeight.normal,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAddress(dynamic address) {
    if (address == null) return 'N/A';

    // If it's already a map, normalize keys and format
    if (address is Map<String, dynamic>) {
      final m = address;
      final street =
          m['street'] ??
          m['Street'] ??
          m['streetAddress'] ??
          m['street_address'] ??
          '';
      final area = m['area'] ?? m['Area'] ?? m['locality'] ?? '';
      final city = m['city'] ?? m['City'] ?? m['town'] ?? '';
      final state = m['state'] ?? m['State'] ?? '';
      final postalCode = m['postalCode'] ?? m['postal_code'] ?? m['zip'] ?? '';
      final coordinates =
          m['coordinates'] ?? m['Coordinates'] ?? m['location'] ?? m['latlng'];

      final addressParts =
          [street, area, city, state, postalCode]
              .where((part) => part != null && part.toString().isNotEmpty)
              .map((part) => part.toString())
              .toList();

      final formattedAddress = addressParts.join(', ');

      if (formattedAddress.isEmpty && coordinates != null) {
        if (coordinates is List && coordinates.length >= 2) {
          return '${coordinates[0]}, ${coordinates[1]}';
        }
        return coordinates.toString();
      }

      if (formattedAddress.isEmpty) {
        final label = m['label'] ?? m['Label'] ?? '';
        if (label.toString().isNotEmpty) return label.toString();
        final fullAddress =
            m['address'] ?? m['Address'] ?? m['fullAddress'] ?? '';
        if (fullAddress.toString().isNotEmpty) return fullAddress.toString();
        return 'N/A';
      }

      return formattedAddress;
    }

    // If it's not a map, try to convert model objects to a map via toJson()
    try {
      final json = (address as dynamic).toJson();
      if (json is Map<String, dynamic>) return _formatAddress(json);
    } catch (_) {}

    // Try to access common properties on model objects (dynamic access)
    try {
      final dyn = address as dynamic;
      final street = dyn.street ?? dyn.streetAddress ?? '';
      final area = dyn.area ?? '';
      final city = dyn.city ?? '';
      final state = dyn.state ?? '';
      final postalCode = dyn.postalCode ?? dyn.postal_code ?? '';
      final label = dyn.label ?? '';
      final coordinates = dyn.coordinates ?? dyn.location ?? null;

      final addressParts =
          [street, area, city, state, postalCode]
              .where((part) => part != null && part.toString().isNotEmpty)
              .map((part) => part.toString())
              .toList();

      if (addressParts.isNotEmpty) return addressParts.join(', ');
      if (label != null && label.toString().isNotEmpty) return label.toString();
      if (coordinates != null) {
        if (coordinates is List && coordinates.length >= 2) {
          return '${coordinates[0]}, ${coordinates[1]}';
        }
        return coordinates.toString();
      }
      final fullAddress = dyn.address ?? dyn.fullAddress ?? '';
      if (fullAddress != null && fullAddress.toString().isNotEmpty)
        return fullAddress.toString();
    } catch (_) {}

    // Fallback: string representation
    final addressString = address.toString().trim();
    return addressString.isEmpty ? 'N/A' : addressString;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.grey[300],
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'My Van Bookings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? _buildErrorView()
                : _bookings.isEmpty
                ? _buildEmptyView()
                : _buildBookingsList(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadBookings,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB21E1E),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No completed bookings yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your delivered bookings will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bookings.length,
      itemBuilder: (context, index) {
        final booking = _bookings[index];
        return _buildBookingCard(booking);
      },
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final bookingId =
        booking['booking']['_id'] ?? booking['booking']['id'] ?? '';
    final status = booking['booking']['status']?.toString() ?? 'unknown';

    // Resolve booking type safely
    final typeRaw =
        booking['booking']['type'] ??
        booking['booking']['bookingType'] ??
        booking['booking']['booking_type'] ??
        booking['booking']['typeName'];
    final type = typeRaw?.toString() ?? 'instant';

    final createdAt = booking['booking']['createdAt']?.toString() ?? '';
    final scheduledFor = booking['booking']['scheduledFor']?.toString();

    // Normalize pickup address
    final pickupRaw =
        booking['booking']['pickupAddress'] ??
        booking['booking']['pickup_address'] ??
        booking['booking']['pickup'] ??
        booking['booking']['address'];

    final order = booking['order']; // <-- if not null, show VIEW ORDER button

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showBookingDetails(bookingId, booking['booking']),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------- HEADER ----------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: VanBookingService.getStatusColor(
                        status,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          VanBookingService.getStatusIcon(status),
                          size: 14,
                          color: VanBookingService.getStatusColor(status),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: VanBookingService.getStatusColor(status),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ---------------- BOOKING ID ----------------
              Row(
                children: [
                  Icon(
                    Icons.confirmation_number_outlined,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Booking ID: ${bookingId.substring(0, min(12, bookingId.length))}...',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ---------------- TYPE ----------------
              Row(
                children: [
                  Icon(
                    type.toLowerCase() == 'instant'
                        ? Icons.flash_on
                        : Icons.schedule,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Type: ${type.toUpperCase()}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ---------------- ADDRESS ----------------
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatAddress(pickupRaw),
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // ---------------- FOOTER ----------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        scheduledFor != null
                            ? 'Scheduled: ${VanBookingService.formatBookingDate(scheduledFor)}'
                            : 'Created: ${VanBookingService.formatBookingDate(createdAt)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),

                  // -------- SHOW ORDER BUTTON IF ORDER EXISTS --------
                  if (order != null)
                    InkWell(
                      onTap: () => _showOrderDetails(order),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'View Order',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Order Details",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),

              ...order['items'].map<Widget>((item) {
                return ListTile(
                  title: Text(item['itemName']),
                  subtitle: Text("Qty: ${item['quantity']}"),
                  trailing: Text(
                    "₹${item['subtotal']}",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                );
              }).toList(),

              const Divider(),
              Text(
                "Total: ₹${order['totalAmount']}",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      },
    );
  }
}
