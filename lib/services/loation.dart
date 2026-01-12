import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../widget/booking/map_widget.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({Key? key}) : super(key: key);

  @override
  _LocationScreenState createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final MapController _mapController = MapController();

  // Location states
  LatLng? _currentLocation;
  LatLng? _selectedLocation;
  bool _locationLoading = true;
  bool _isAddressLoading = false;
  bool _isMapReady = false;
  bool _isFullScreenMap = false;

  // Address details
  String _selectedAddress = '';
  String _selectedArea = '';
  String _selectedCity = '';
  String _selectedState = '';
  String _selectedPostalCode = '';

  // Map config
  int _currentTileProvider = 0;
  final List<Map<String, dynamic>> _tileProviders =
      MapConfig.defaultTileProviders;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  // ... (keep all your existing methods: _loadCurrentLocation, _loadAddressForLocation, etc.)

  @override
  @override
  Widget build(BuildContext context) {
    final mapWidget = MapWidget(
      mapController: _mapController,
      context: context,
      currentLocation: _currentLocation,
      selectedLocation:
      _selectedLocation ??
          _currentLocation ??
          const LatLng(28.7548, 77.4949), // Use your exact coordinates
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
      onToggleFullScreen: _toggleFullScreen,
      onSwitchTileProvider: _switchTileProvider,
      onMapTap: _onMapTap,
      onConfirmLocation: _confirmLocation,
      onLocationSelected: (location) {
        _onMapTap(location);
      },
    );

    if (_isFullScreenMap) {
      return mapWidget;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        backgroundColor: const Color(0xFFB21E1E),
        foregroundColor: Colors.white,
        actions: [
          if (_currentLocation != null)
            IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: _centerMapOnCurrentLocation,
              tooltip: 'Center on my location',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // DEBUG INFO - Add this temporarily to see coordinates
            if (_currentLocation != null)
              Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  'Current: ${_currentLocation!.latitude.toStringAsFixed(6)}, ${_currentLocation!.longitude.toStringAsFixed(6)}\n'
                      'This should show Muradnagar area, not Delhi',
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),

            // Location info card
            if (!_locationLoading && _currentLocation != null)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Your Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB21E1E),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'GPS ACTIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Colors.red.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedAddress.isEmpty
                                ? 'Loading address...'
                                : _selectedAddress,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (_isAddressLoading)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFB21E1E),
                            ),
                          ),
                      ],
                    ),
                    if (_selectedArea.isNotEmpty ||
                        _selectedCity.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${_selectedArea.isNotEmpty ? _selectedArea + ', ' : ''}${_selectedCity}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Map widget
            mapWidget,

            const SizedBox(height: 16),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _locationLoading ? null : _loadCurrentLocation,
                      icon:
                      _locationLoading
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.refresh, size: 20),
                      label: Text(_locationLoading ? 'Loading...' : 'Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Center map button with better label
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                      _currentLocation != null
                          ? _centerMapOnCurrentLocation
                          : null,
                      icon: const Icon(Icons.center_focus_strong, size: 20),
                      label: const Text('Center'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Confirm location button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                      _selectedLocation != null ? _confirmLocation : null,
                      icon: const Icon(Icons.check_circle, size: 20),
                      label: const Text('Confirm'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB21E1E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Instructions with better guidance
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.amber.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentLocation != null
                            ? '📍 Blue marker = Your GPS location\n🔴 Red pin = Selected location\nTap "Center" if map shows wrong area'
                            : 'Tap "Refresh" to get your GPS location, or tap on map to select manually.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
  void _forceMapReset() {
    if (_currentLocation != null) {
      print('🔄 FORCING complete map reset to Muradnagar');

      // Reset map state
      setState(() {
        _isMapReady = false;
      });

      // Wait and recreate
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _selectedLocation = _currentLocation;
            _isMapReady = true;
          });

          // Force move after rebuild
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              print('📍 Final force move to: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');
              _mapController.move(_currentLocation!, 17.0);
            }
          });
        }
      });
    }
  }

  // Add all the missing methods from the previous implementation
  Future<void> _loadCurrentLocation() async {
    print('🚀 Starting location loading...');

    setState(() {
      _locationLoading = true;
    });

    try {
      final location = await MapLocationService.getCurrentLocation();

      if (location != null && mounted) {
        print(
          '📍 Successfully got location: ${location.latitude}, ${location.longitude}',
        );

        setState(() {
          _currentLocation = location;
          _selectedLocation = location; // This is crucial
          _locationLoading = false;
          _isMapReady = true;
        });

        // Load address for current location
        await _loadAddressForLocation(location);

        // FORCE map to center on the correct location
        await Future.delayed(const Duration(milliseconds: 1500));
        if (_isMapReady && mounted) {
          print(
            '🗺️ CENTERING map on Muradnagar: ${location.latitude}, ${location.longitude}',
          );

          // Multiple approaches to ensure it works
          _mapController.move(location, 16.0); // Higher zoom for better view

          await Future.delayed(const Duration(milliseconds: 500));

          // Try fit bounds for the area
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds(
                LatLng(location.latitude - 0.005, location.longitude - 0.005),
                LatLng(location.latitude + 0.005, location.longitude + 0.005),
              ),
              padding: const EdgeInsets.all(20),
            ),
          );
        }
      } else {
        print('❌ Could not get current location');
        await _handleLocationFailure();
      }
    } catch (e) {
      print('💥 Exception in _loadCurrentLocation: $e');
      await _handleLocationFailure();
    }
  }

  void _centerMapOnCurrentLocation() {
    if (_currentLocation != null) {
      print(
        '🎯 Centering on: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}',
      );

      // Use higher zoom level for Muradnagar area
      _mapController.move(_currentLocation!, 16.0);

      // Also update selected location to current
      setState(() {
        _selectedLocation = _currentLocation;
      });

      // Reload address to make sure it's correct
      _loadAddressForLocation(_currentLocation!);
    }
  }

  Future<void> _loadAddressForLocation(LatLng location) async {
    setState(() {
      _isAddressLoading = true;
    });

    try {
      final addressData = await MapLocationService.getAddressFromLatLng(
        location,
      );

      if (mounted) {
        setState(() {
          _selectedAddress = addressData['address'] ?? '';
          _selectedArea = addressData['area'] ?? '';
          _selectedCity = addressData['city'] ?? '';
          _selectedState = addressData['state'] ?? '';
          _selectedPostalCode = addressData['postalCode'] ?? '';
          _isAddressLoading = false;
        });
      }
    } catch (e) {
      print('Error loading address: $e');
      if (mounted) {
        setState(() {
          _isAddressLoading = false;
        });
      }
    }
  }

  void _onMapTap(LatLng point) {
    setState(() {
      _selectedLocation = point;
    });
    _loadAddressForLocation(point);
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreenMap = !_isFullScreenMap;
    });
  }

  void _switchTileProvider() {
    setState(() {
      _currentTileProvider = (_currentTileProvider + 1) % _tileProviders.length;
    });
  }

  void _confirmLocation() {
    if (_selectedLocation != null) {
      print('Location confirmed: $_selectedLocation');
      Navigator.pop(context, {
        'location': _selectedLocation,
        'address': _selectedAddress,
        'area': _selectedArea,
        'city': _selectedCity,
        'state': _selectedState,
        'postalCode': _selectedPostalCode,
      });
    }
  }

  @override
  void dispose() {
    MapLocationService.stopLocationStream();
    super.dispose();
  }

  Future<void> _handleLocationFailure() async {
    if (mounted) {
      setState(() {
        _locationLoading = false;
      });

      // Show options dialog
      final result = await showDialog<String>(
        context: context,
        builder:
            (context) => AlertDialog(
          title: const Text('Location Access'),
          content: const Text(
            'Unable to get your current location. You can:\n\n'
                '1. Use default location (Muradnagar)\n'
                '2. Select location manually on map\n'
                '3. Check location settings',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'settings'),
              child: const Text('Settings'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'default'),
              child: const Text('Use Default'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'retry'),
              child: const Text('Retry'),
            ),
          ],
        ),
      );

      switch (result) {
        case 'retry':
          _loadCurrentLocation();
          break;
        case 'settings':
          await Geolocator.openLocationSettings();
          break;
        case 'default':
        default:
          _useDefaultLocation();
          break;
      }
    }
  }

  // Also add this helper method for using default location
  void _useDefaultLocation() {
    // Use coordinates closer to Muradnagar instead of New Delhi
    final muradnagarLocation = const LatLng(
      28.7547,
      77.4948,
    ); // Your actual coordinates

    if (mounted) {
      setState(() {
        _currentLocation = muradnagarLocation;
        _selectedLocation = muradnagarLocation;
        _locationLoading = false;
        _isMapReady = true;
      });

      _loadAddressForLocation(muradnagarLocation);

      // Move map to Muradnagar
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _mapController.move(muradnagarLocation, MapConfig.defaultZoom);
        }
      });
    }
  }
}