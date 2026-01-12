import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import '../Utils/booking/booking_utils.dart';
import '../Utils/booking/snackbar_utils.dart';
import '../model/van_booking/VanRoute_model.dart';
import '../utils/date_time_utils.dart';
import '../services/api_service_for_van.dart';
import '../services/navigation_service.dart';
import '../widget/booking/action_buttons_widget.dart';
import '../widget/booking/booking_widgets.dart';
import 'package:provider/provider.dart';
import '../providers/booking_provider.dart';
import '../providers/address_provider.dart';
import '../model/Address/address_model.dart';
import '../widget/booking/address_selections_dialog.dart';
import '../widget/booking/map_widget.dart';
import '../widget/main_header.dart';

class VanRoutePage extends StatefulWidget {
  const VanRoutePage({super.key});

  @override
  State<VanRoutePage> createState() => _VanRoutePageState();
}

class _VanRoutePageState extends State<VanRoutePage>
    with AutomaticKeepAliveClientMixin {
  final MapController _mapController = MapController();
  final VanRouteApiService _apiService = VanRouteApiService();

  // Timers for debouncing operations and sync
  Timer? _debounceTimer;
  Timer? _locationTimer;
  Timer? _syncTimer;

  // Current tile provider index
  int _currentTileProvider = 0;

  // Simplified tile providers
  final List<Map<String, dynamic>> _tileProviders = [
    {
      'name': 'CartoDB Light',
      'url': 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
    },
    {
      'name': 'ESRI World',
      'url':
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
    },
  ];

  // State variables
  List<UserBooking> _userBookings = [];

  // Loading states
  bool _isLoading = false;
  bool _isLoadingBookings = false;
  bool _locationLoading = false;
  bool _isFullScreenMap = false;
  bool _isAddressLoading = false;
  final bool _isMapReady = false;

  // Location data
  LatLng _currentLocation = const LatLng(28.6139, 77.2090);
  LatLng _selectedLocation = const LatLng(28.6139, 77.2090);
  String _selectedAddress = "Loading address...";

  // Address components
  String _selectedArea = '';
  String _selectedCity = '';
  String _selectedState = '';
  String _selectedPostalCode = '';
  // Track the selected saved address id (if any).
  String? _selectedAddressId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
      _startPeriodicSync();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _locationTimer?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  // Initialize app without blocking
  Future<void> _initializeApp() async {
    if (!mounted) return;

    _getCurrentLocation();

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      _loadBasicData();
    }
  }

  // Refresh page state when returning from other screens
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted) {
      _loadUserBookings();
    }
  }

  // Start periodic sync method
  void _startPeriodicSync() {
    _syncTimer?.cancel();

    _syncTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (!_apiService.isUserLoggedIn()) {
        return;
      }

      try {
        final isHealthy = await _apiService.checkApiHealthAndSync();
        if (isHealthy) {
          print('API recovered, refreshing bookings...');
          _loadUserBookings();
        }
      } catch (e) {
        print('Periodic sync error: $e');
      }
    });
  }

  // Optimized tile provider switching
  void _switchTileProvider() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _currentTileProvider =
              (_currentTileProvider + 1) % _tileProviders.length;
        });
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    if (_locationLoading || !mounted) return;

    setState(() => _locationLoading = true);

    try {
      final location = await MapLocationService.getCurrentLocation();

      if (location != null && mounted) {
        _mapController.move(location, 15.0);

        setState(() {
          _currentLocation = location;
          _selectedLocation = location;
          _locationLoading = false;
        });

        _getAddressFromLatLng(location);
      } else if (mounted) {
        setState(() => _locationLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _locationLoading = false);
      }
    }
  }

  Future<void> _getAddressFromLatLng(LatLng location) async {
    if (_isAddressLoading || !mounted) return;

    setState(() => _isAddressLoading = true);

    try {
      final addressData = await MapLocationService.getAddressFromLatLng(
        location,
      );

      if (mounted) {
        setState(() {
          _selectedAddress = addressData['address'] ?? 'Unknown Address';
          _selectedArea = addressData['area'] ?? '';
          _selectedCity = addressData['city'] ?? '';
          _selectedState = addressData['state'] ?? '';
          _selectedPostalCode = addressData['postalCode'] ?? '';
          _isAddressLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedAddress =
          '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
          _selectedArea = 'Unknown Area';
          _selectedCity = 'Unknown City';
          _selectedState = 'Unknown State';
          _selectedPostalCode = '000000';
          _isAddressLoading = false;
        });
      }
    }
  }

  Future<void> _loadBasicData() async {
    if (_isLoading || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await _apiService.getBasket().timeout(const Duration(seconds: 10));
      if (mounted) {}

      _loadUserBookings();
    } catch (e) {
      debugPrint('Error loading basic data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUserBookings() async {
    try {
      final bookingProvider = Provider.of<BookingProvider>(
        context,
        listen: false,
      );
      await bookingProvider.load();

      final localPending = bookingProvider.pendingBookings;

      setState(() {
        _userBookings =
            localPending.map((m) => UserBooking.fromJson(m)).toList();
        _isLoadingBookings = false;
      });
    } catch (e) {
      debugPrint('Error reading local bookings cache: $e');
      if (mounted) {
        setState(() {
          _userBookings = [];
          _isLoadingBookings = false;
        });
      }
    }

    unawaited(_offloadRefreshBookings());
  }

  Future<void> _offloadRefreshBookings() async {
    try {
      final bookingProvider = Provider.of<BookingProvider>(
        context,
        listen: false,
      );

      if (!_apiService.isUserLoggedIn()) return;

      final bookings = await _apiService
          .getUserBookingsWithSmartMerge()
          .timeout(const Duration(seconds: 15));

      final pendingBookings = bookings.where((booking) {
        final status = booking.status.toLowerCase();
        return status != 'completed' &&
            status != 'cancelled' &&
            status != 'failed' &&
            status != 'delivered';
      }).toList();

      final completed = bookings.where((booking) {
        final status = booking.status.toLowerCase();
        return status == 'completed' ||
            status == 'cancelled' ||
            status == 'failed' ||
            status == 'delivered';
      }).toList();

      try {
        await bookingProvider.savePendingFromDynamicList(pendingBookings);
        await bookingProvider.saveCompletedFromDynamicList(completed);
      } catch (persistErr) {
        debugPrint('Failed to persist bookings in background: $persistErr');
      }

      if (mounted) {
        setState(() {
          final List<dynamic> pb = pendingBookings.cast<dynamic>().toList();
          _userBookings = pb.map<UserBooking>((m) {
            if (m is UserBooking) return m;
            if (m is Map<String, dynamic>) return UserBooking.fromJson(m);
            return UserBooking.fromJson(
              Map<String, dynamic>.from(m as Map),
            );
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Background booking refresh failed: $e');
    }
  }

  void _toggleFullScreenMap() {
    setState(() => _isFullScreenMap = !_isFullScreenMap);
  }

  void _handleMapTap(LatLng tappedPoint) {
    if (_isFullScreenMap) {
      setState(() => _selectedLocation = tappedPoint);
      _getAddressFromLatLng(tappedPoint);
    }
  }

  void _confirmLocation() {
    _toggleFullScreenMap();
    if (mounted) {
      SnackbarUtils.showSuccess(
        context,
        'Location confirmed: $_selectedAddress',
      );
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Icon(Icons.login, color: const Color(0xFFB21E1E), size: 24),
            const SizedBox(width: 8),
            const Text(
              'Login Required',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You need to be logged in to book a van.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Please log in to continue with your booking',
                      style: TextStyle(fontSize: 14, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/login').then((_) {
                if (mounted) {
                  setState(() {});
                  _loadUserBookings();
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB21E1E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  void _showSessionExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.orange.shade600,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text(
              'Session Expired',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your login session has expired. Please log in again to continue.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
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
                      'Your bookings are safe and will be available after login',
                      style: TextStyle(fontSize: 14, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              NavigationService.goBackToHomeScreen();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
            ),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/login').then((_) {
                if (mounted) {
                  setState(() {});
                  _loadUserBookings();
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB21E1E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showAddressConfirmationDialog() async {
    final addressProvider = Provider.of<AddressProvider>(
      context,
      listen: false,
    );

    try {
      await addressProvider.loadAddresses();
    } catch (_) {}

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddressSelectionDialog(
        currentLocation: _selectedLocation,
        currentAddress: _selectedAddress,
        currentArea: _selectedArea,
        currentCity: _selectedCity,
        currentState: _selectedState,
        currentPostalCode: _selectedPostalCode,
        savedAddresses: addressProvider.addresses,
        selectedAddress: addressProvider.defaultAddress,
      ),
    );

    if (result == null) return false;

    if (result['isNewAddress'] == true) {
      final label = result['label']?.toString() ?? 'Saved Address';
      final street = result['street']?.toString() ?? '';
      final area = result['area']?.toString() ?? '';
      final city = result['city']?.toString() ?? '';
      final state = result['state']?.toString() ?? '';
      final postal = result['postalCode']?.toString() ?? '';
      final isDefault = result['isDefault'] == true;
      final coords = result['coordinates'];

      double? lat;
      double? lng;
      if (coords is List && coords.length >= 2) {
        try {
          lat = (coords[0] as num).toDouble();
          lng = (coords[1] as num).toDouble();
        } catch (_) {}
      }

      final newAddress = Address(
        id: '',
        label: label,
        street: street,
        area: area,
        city: city,
        state: state,
        country: result['country']?.toString() ?? 'India',
        postalCode: postal,
        isDefault: isDefault,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        latitude: lat,
        longitude: lng,
      );

      try {
        await addressProvider.addAddress(newAddress);
        await addressProvider.loadAddresses();

        Address? added = addressProvider.addresses.firstWhere(
              (a) => a.label == label && a.street == street,
          orElse: () => addressProvider.addresses.isNotEmpty
              ? addressProvider.addresses.last
              : newAddress,
        );

        _selectedAddress = added.street;
        _selectedArea = added.area;
        _selectedCity = added.city;
        _selectedState = added.state;
        _selectedPostalCode = added.postalCode;

        if (added.id.isNotEmpty) {
          _selectedAddressId = added.id;
        }
        if (added.latitude != null && added.longitude != null) {
          _selectedLocation = LatLng(added.latitude!, added.longitude!);
        }

        return true;
      } catch (e) {
        debugPrint('Failed to add new address: $e');
        return false;
      }
    }

    if (result.containsKey('addressId') || result.containsKey('street')) {
      if (result['addressId'] != null) {
        _selectedAddressId = result['addressId'].toString();
        final addr = addressProvider.getAddressById(_selectedAddressId!);

        if (addr != null) {
          _selectedAddressId = addr.id;
          _selectedAddress = addr.street;
          _selectedArea = addr.area;
          _selectedCity = addr.city;
          _selectedState = addr.state;
          _selectedPostalCode = addr.postalCode;
          if (addr.latitude != null && addr.longitude != null) {
            _selectedLocation = LatLng(addr.latitude!, addr.longitude!);
          }
          return true;
        }
      } else {
        _selectedAddressId = null;
      }

      _selectedAddress = result['street']?.toString() ?? _selectedAddress;
      _selectedArea = result['area']?.toString() ?? _selectedArea;
      _selectedCity = result['city']?.toString() ?? _selectedCity;
      _selectedState = result['state']?.toString() ?? _selectedState;
      _selectedPostalCode =
          result['postalCode']?.toString() ?? _selectedPostalCode;
      final coords = result['coordinates'];
      if (coords is List && coords.length >= 2) {
        try {
          final lat = (coords[0] as num).toDouble();
          final lng = (coords[1] as num).toDouble();
          _selectedLocation = LatLng(lat, lng);
        } catch (_) {}
      }

      return true;
    }

    return false;
  }

  void _showSuccessDialog(
      String title,
      String bookingId, {
        String? additionalInfo,
      }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 30,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.confirmation_number,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Booking ID: ${bookingId.length > 12 ? "${bookingId.substring(0, 12)}..." : bookingId}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedAddress,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (additionalInfo != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            additionalInfo,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Your booking will appear in the list below',
                      style: TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadUserBookings();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showBookingDetails(UserBooking booking) {
    final statusLower = booking.status.toLowerCase();
    final isInTransit = statusLower == 'intransit' ||
        statusLower == 'in_transit' ||
        statusLower == 'in-transit';
    final isAssigned = statusLower == 'assigned';
    final canModify = statusLower == 'pending' || statusLower == 'scheduled';
    final canCancel = statusLower == 'pending' || statusLower == 'scheduled';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: BookingUtils.getStatusColor(booking.status),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                BookingUtils.generateBookingReference(booking.id),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(
                'Status',
                BookingUtils.getStatusDisplayText(booking.status),
                BookingUtils.getStatusColor(booking.status),
              ),
              _buildDetailRow(
                'Type',
                BookingUtils.getBookingTypeDisplayText(booking.bookingType),
              ),
              _buildDetailRow(
                'Address',
                BookingUtils.formatAddress(
                  street: booking.pickupAddress.street,
                  area: booking.pickupAddress.area,
                  city: booking.pickupAddress.city,
                  state: booking.pickupAddress.state,
                  showState: true,
                  maxLength: 60,
                ),
              ),
              if (booking.scheduledFor != null)
                _buildDetailRow(
                  'Scheduled',
                  booking.scheduledFor!.toFullFormat(),
                ),
              if (booking.remark.isNotEmpty)
                _buildDetailRow('Remark', booking.remark),
              _buildDetailRow('Created', booking.createdAt.toFullFormat()),
              _buildDetailRow(
                'Time Ago',
                booking.createdAt.toRelativeFormat(),
              ),
              if (isInTransit) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_shipping,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Your van is on the way! The driver will arrive soon.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isAssigned) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Colors.green.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'A driver has been assigned to your booking!',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (canModify || canCancel) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      if (canModify)
                        Flexible(
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                SnackbarUtils.showInfo(
                                  context,
                                  'Modify booking feature coming soon!',
                                );
                              },
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text(
                                'Modify',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue,
                                side: BorderSide(
                                  color: Colors.blue.shade300,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (canModify && canCancel) const SizedBox(width: 8),
                      if (canCancel)
                        Flexible(
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _showCancelBookingDialog(booking);
                              },
                              icon: const Icon(Icons.cancel, size: 16),
                              label: const Text(
                                'Cancel',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: BorderSide(
                                  color: Colors.red.shade300,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
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

  Widget _buildDetailRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? Colors.black87,
                fontWeight:
                valueColor != null ? FontWeight.w600 : FontWeight.normal,
              ),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  void _scheduleVanBooking() async {
    if (!mounted) return;

    if (!_apiService.isUserLoggedIn()) {
      _showLoginRequiredDialog();
      return;
    }

    final bool? addressConfirmed = await _showAddressConfirmationDialog();
    if (addressConfirmed != true) return;

    final DateTime? selectedDate = await _showDatePicker();
    if (selectedDate == null) return;

    final TimeOfDay? selectedTime = await _showTimePicker();
    if (selectedTime == null) return;

    final DateTime scheduledDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    final DateTime now = DateTime.now();
    final DateTime minimumAllowedTime = now.add(const Duration(minutes: 30));

    if (scheduledDateTime.isBefore(minimumAllowedTime)) {
      if (mounted) {
        if (scheduledDateTime.isBefore(now)) {
          SnackbarUtils.showError(
            context,
            'You cannot schedule a van for a past time.',
          );
        } else {
          SnackbarUtils.showError(
            context,
            'Please schedule your booking at least 30 minutes in advance.',
          );
        }
      }
      return;
    }

    // --- TIME VALIDATION START ---
    if (selectedTime.hour < 9 ||
        (selectedTime.hour >= 19 && selectedTime.minute > 0)) {
      if (mounted) {
        SnackbarUtils.showError(
          context,
          'Van services are only available between 9:00 AM and 7:00 PM',
        );
      }
      return;
    }
    // --- TIME VALIDATION END ---

    if (!mounted) return;
    final String? userRemark = await _showRemarkDialog();
    if (userRemark == null) return;

    if (!mounted) return;
    final loadingSnackbar = SnackbarUtils.showLoading(
      context,
      'Scheduling van for ${scheduledDateTime.toDisplayFormat()}...',
    );

    try {
      final pickupAddress = BookingUtils.createPickupAddress(
        address: _selectedAddress,
        area: _selectedArea,
        city: _selectedCity,
        state: _selectedState,
        postalCode: _selectedPostalCode,
        location: _selectedLocation,
      );

      if (_selectedAddressId != null && _selectedAddressId!.isNotEmpty) {
        pickupAddress['id'] = _selectedAddressId;
      }

      if (_selectedAddressId == null || _selectedAddressId!.isEmpty) {
        final List<String> missing = [];
        if ((pickupAddress['street']?.toString() ?? '').trim().isEmpty)
          missing.add('street');
        if ((pickupAddress['city']?.toString() ?? '').trim().isEmpty)
          missing.add('city');
        if ((pickupAddress['state']?.toString() ?? '').trim().isEmpty)
          missing.add('state');
        if ((pickupAddress['country']?.toString() ?? '').trim().isEmpty)
          missing.add('country');
        if ((pickupAddress['postalCode']?.toString() ?? '').trim().isEmpty)
          missing.add('postalCode');

        if (missing.isNotEmpty) {
          loadingSnackbar.close();
          SnackbarUtils.showError(
            context,
            'Address incomplete: ${missing.join(', ')}. Please select or enter a complete address.',
          );
          return;
        }
      }

      final BookingResponse result = await _apiService
          .scheduleVanBooking(
        location: _selectedAddress,
        pickupAddress: pickupAddress,
        scheduledDateTime: scheduledDateTime,
        remark: userRemark,
      )
          .timeout(const Duration(seconds: 20));

      if (mounted) {
        loadingSnackbar.close();

        if (result.success && result.id.isNotEmpty) {
          _showSuccessDialog(
            'Van Scheduled Successfully!',
            result.id,
            additionalInfo:
            'Scheduled for ${scheduledDateTime.toDisplayFormat()}',
          );
          _loadUserBookings();

          SnackbarUtils.showBookingSuccess(
            context,
            result.id,
            onViewBooking: () => _loadUserBookings(),
          );
        } else {
          SnackbarUtils.showError(
            context,
            'Failed to schedule van. Please try again.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        loadingSnackbar.close();

        if (e.toString().contains('User not logged in')) {
          _showLoginRequiredDialog();
          return;
        } else if (e.toString().contains('Session expired')) {
          _showSessionExpiredDialog();
          return;
        }

        SnackbarUtils.showApiError(
          context,
          e.toString(),
          onRetry: _scheduleVanBooking,
        );
      }
    }
  }

  Future<String?> _showRemarkDialog() async {
    final TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.note_add_outlined, color: Color(0xFFB21E1E)),
            const SizedBox(width: 10),
            const Text('Add a Remark', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Any specific instructions for the driver? (Optional)',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'e.g., Please call upon arrival',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFB21E1E)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB21E1E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<DateTime?> _showDatePicker() async {
    return await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFFB21E1E)),
          ),
          child: child!,
        );
      },
    );
  }

  Future<TimeOfDay?> _showTimePicker() async {
    // 1. Calculate a valid initial time to show
    // If current time is out of bounds (before 9AM or after 7PM), default to 9:00 AM
    TimeOfDay initial = TimeOfDay.now();
    if (initial.hour < 9) {
      initial = const TimeOfDay(hour: 9, minute: 0);
    } else if (initial.hour >= 19) {
      initial = const TimeOfDay(hour: 9, minute: 0);
    }

    return await showTimePicker(
      context: context,
      initialTime: initial,
      // DIGITAL INPUT MODE
      initialEntryMode: TimePickerEntryMode.input,
      helpText: 'ENTER TIME (9:00 AM - 7:00 PM)',
      errorInvalidText: 'Enter a valid time',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFB21E1E),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            timePickerTheme: TimePickerThemeData(
              dayPeriodBorderSide: const BorderSide(color: Color(0xFFB21E1E)),
              dayPeriodTextColor: const Color(0xFFB21E1E),
              dayPeriodColor: const Color(0xFFB21E1E).withOpacity(0.1),
            ),
          ),
          child: child!,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isFullScreenMap) {
      return _buildFullScreenMap();
    }

    final bool isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    if (isIOS) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              const Padding(padding: EdgeInsets.all(16), child: MainHeader()),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildMap(),
                      _buildActionButtons(),
                      _buildBookingsSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // On Android: Intercept back button with custom navigation
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        NavigationService.goBackToHomeScreen();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              const Padding(padding: EdgeInsets.all(16), child: MainHeader()),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildMap(),
                      _buildActionButtons(),
                      _buildBookingsSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildBookingsSection() {
    final bookingWidgets = BookingWidgets(
      apiService: _apiService,
      userBookings: _userBookings,
      isLoadingBookings: _isLoadingBookings,
      retryLoadBookings: null,
      showBookingDetails: _showBookingDetails,
      context: context,
    );

    return bookingWidgets.buildBookingsSection();
  }

  Widget _buildMap() {
    final mapWidget = MapWidget(
      mapController: _mapController,
      context: context,
      currentLocation: _currentLocation,
      selectedLocation: _selectedLocation,
      selectedAddress: _selectedAddress,
      selectedArea: _selectedArea,
      selectedCity: _selectedCity,
      selectedState: _selectedState,
      selectedPostalCode: _selectedPostalCode,
      locationLoading: _locationLoading,
      isAddressLoading: _isAddressLoading,
      isMapReady: _isMapReady,
      isFullScreenMap: _isFullScreenMap,
      currentTileProvider: _currentTileProvider,
      tileProviders: _tileProviders,
      onToggleFullScreen: _toggleFullScreenMap,
      onSwitchTileProvider: _switchTileProvider,
      onMapTap: _handleMapTap,
      onConfirmLocation: _confirmLocation,
      onLocationSelected: (location) {
        setState(() {
          _selectedLocation = location;
        });
        _getAddressFromLatLng(location);
      },
      onCenterToCurrentLocation: _centerToCurrentLocation,
    );

    return mapWidget.buildMap();
  }

  Widget _buildFullScreenMap() {
    final mapWidget = MapWidget(
      mapController: _mapController,
      context: context,
      currentLocation: _currentLocation,
      selectedLocation: _selectedLocation,
      selectedAddress: _selectedAddress,
      selectedArea: _selectedArea,
      selectedCity: _selectedCity,
      selectedState: _selectedState,
      selectedPostalCode: _selectedPostalCode,
      locationLoading: _locationLoading,
      isAddressLoading: _isAddressLoading,
      isMapReady: _isMapReady,
      isFullScreenMap: _isFullScreenMap,
      currentTileProvider: _currentTileProvider,
      tileProviders: _tileProviders,
      onToggleFullScreen: _toggleFullScreenMap,
      onSwitchTileProvider: _switchTileProvider,
      onMapTap: _handleMapTap,
      onConfirmLocation: _confirmLocation,
      onLocationSelected: (location) {
        setState(() {
          _selectedLocation = location;
        });
        _getAddressFromLatLng(location);
      },
    );

    // This PopScope intercepts the back button to close the full-screen map
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _toggleFullScreenMap();
      },
      child: mapWidget.buildFullScreenMap(),
    );
  }

  Widget _buildActionButtons() {
    final actionButtonsWidget = ActionButtonsWidget(
      apiService: _apiService,
      onBookNow: _scheduleVanBooking,
      onScheduleBooking: _scheduleVanBooking,
      context: context,
    );

    return actionButtonsWidget.buildActionButtons();
  }

  Future<void> _cancelBooking(UserBooking booking) async {
    if (!mounted) return;

    late ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
    loadingSnackbar;

    try {
      loadingSnackbar = SnackbarUtils.showLoading(
        context,
        'Cancelling booking ${BookingUtils.generateBookingReference(booking.id)}...',
        showProgressIndicator: true,
      );

      final result = await _apiService.cancelBooking(booking.id);

      if (mounted) {
        loadingSnackbar.close();

        if (result.success) {
          SnackbarUtils.showSuccess(context, 'Booking cancelled successfully!');
          await _loadUserBookings();
          _showCancellationSuccessDialog(booking, result.booking);
        } else {
          SnackbarUtils.showError(
            context,
            result.message.isNotEmpty
                ? result.message
                : 'Failed to cancel booking',
            onRetry: () => _cancelBooking(booking),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        try {
          loadingSnackbar.close();
        } catch (closeError) {
          print('Error closing loading snackbar: $closeError');
        }

        print('Error cancelling booking: $e');

        if (e.toString().contains('Session expired') ||
            e.toString().contains('Authentication failed')) {
          _showSessionExpiredDialog();
        } else {
          SnackbarUtils.showApiError(
            context,
            e.toString(),
            onRetry: () => _cancelBooking(booking),
          );
        }
      }
    }
  }

  void _centerToCurrentLocation() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation, 15.0);
      setState(() {
        _selectedLocation = _currentLocation;
      });
      _getAddressFromLatLng(_currentLocation);

      if (mounted) {
        SnackbarUtils.showSuccess(
          context,
          'Centered to your current location',
        );
      }
    } else {
      _getCurrentLocation();
    }
  }

  void _showCancelBookingDialog(UserBooking booking) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('Cancel Booking'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to cancel this booking?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.confirmation_number,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        BookingUtils.generateBookingReference(booking.id),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: BookingUtils.getStatusColor(
                            booking.status,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Status: ${BookingUtils.getStatusDisplayText(booking.status)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          BookingUtils.formatAddress(
                            street: booking.pickupAddress.street,
                            area: booking.pickupAddress.area,
                            city: booking.pickupAddress.city,
                            state: booking.pickupAddress.state,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (booking.scheduledFor != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Scheduled: ${booking.scheduledFor!.toDisplayFormat()}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Colors.red.shade600,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This action cannot be undone. The booking will be permanently cancelled.',
                      style: TextStyle(fontSize: 13, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelBooking(booking);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
  }

  void _showCancellationSuccessDialog(
      UserBooking originalBooking,
      UserBooking? cancelledBooking,
      ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cancel_outlined,
                size: 30,
                color: Colors.orange.shade600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Booking Cancelled',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.confirmation_number,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Booking: ${BookingUtils.generateBookingReference(originalBooking.id)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cancelled: ${DateTime.now().toDisplayFormat()}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Cancelled by: You',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'You can create a new booking anytime using the schedule button',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _scheduleVanBooking();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB21E1E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
            child: const Text('Book Again'),
          ),
        ],
      ),
    );
  }
}