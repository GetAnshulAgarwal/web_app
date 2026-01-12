import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';

class MapWidget extends StatelessWidget {
  final MapController mapController;
  final BuildContext context;

  // Location data
  final LatLng? currentLocation;
  final LatLng selectedLocation;
  final String selectedAddress;
  final String selectedArea;
  final String selectedCity;
  final String selectedState;
  final String selectedPostalCode;

  // Loading states
  final bool locationLoading;
  final bool isAddressLoading;
  final bool isMapReady;
  final bool isFullScreenMap;

  // Tile provider
  final int currentTileProvider;
  final List<Map<String, dynamic>> tileProviders;

  // Callbacks
  final VoidCallback onToggleFullScreen;
  final VoidCallback onSwitchTileProvider;
  final Function(LatLng) onMapTap;
  final VoidCallback onConfirmLocation;
  final Function(LatLng) onLocationSelected;
  final VoidCallback? onCenterToCurrentLocation; // NEW: Added this parameter

  const MapWidget({
    super.key,
    required this.mapController,
    required this.context,
    this.currentLocation,
    required this.selectedLocation,
    required this.selectedAddress,
    required this.selectedArea,
    required this.selectedCity,
    required this.selectedState,
    required this.selectedPostalCode,
    required this.locationLoading,
    required this.isAddressLoading,
    required this.isMapReady,
    required this.isFullScreenMap,
    required this.currentTileProvider,
    required this.tileProviders,
    required this.onToggleFullScreen,
    required this.onSwitchTileProvider,
    required this.onMapTap,
    required this.onConfirmLocation,
    required this.onLocationSelected,
    this.onCenterToCurrentLocation, // NEW: Added this parameter
  });

  @override
  Widget build(BuildContext context) {
    if (isFullScreenMap) {
      return buildFullScreenMap();
    }
    return buildMap();
  }

  // Build tile layer
  Widget buildTileLayer() {
    return TileLayer(
      urlTemplate: tileProviders[currentTileProvider]['url'],
      userAgentPackageName: 'com.example.app',
      maxZoom: MapConfig.maxZoom,
    );
  }

  // Build main map widget (compact view)
  Widget buildMap() {
    if (locationLoading || currentLocation == null) {
      return Container(
        height: 250,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[100],
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFB21E1E)),
        ),
      );
    }

    return GestureDetector(
      onTap: onToggleFullScreen,
      child: Container(
        height: 250,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: currentLocation!,
                  initialZoom: 17.0,
                  onTap: (tapPosition, point) => onMapTap(point),
                ),
                children: [
                  buildTileLayer(),
                  buildMarkers(),
                ],
              ),
              buildMapOverlays(),
              buildLocationIndicator(),
              // NEW: Center to current location button in compact view
              if (onCenterToCurrentLocation != null)
                Positioned(
                  bottom: 50,
                  right: 10,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    elevation: 4,
                    child: InkWell(
                      onTap: onCenterToCurrentLocation,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.my_location,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildFullScreenMap() {
    return Scaffold(
      body: Stack(
        children: [
          // Map layer
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: selectedLocation,
              initialZoom: MapConfig.fullScreenZoom,
              onTap: (tapPosition, point) => onMapTap(point),
            ),
            children: [
              buildTileLayer(),
              buildMarkers(), // Use the same markers for full screen
            ],
          ),

          // Top header
          buildFullScreenHeader(),

          // Bottom location confirmation card
          buildLocationConfirmationCard(),

          // NEW: Center to current location button - MORE VISIBLE POSITION
          if (onCenterToCurrentLocation != null)
            Positioned(
              right: 16,
              bottom: 220, // Positioned above the location card
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                elevation: 8,
                child: InkWell(
                  onTap: onCenterToCurrentLocation,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.shade100,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.my_location,
                          color: Colors.blue.shade700,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // SIMPLE MARKERS - NO CustomPainter
  Widget buildMarkers() {
    if (currentLocation == null) {
      return MarkerLayer(markers: []);
    }

    return MarkerLayer(
      markers: [
        // GPS Location Marker - Like Google Maps pin
        Marker(
          point: currentLocation!,
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Blue accuracy circle (outermost)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue.withOpacity(0.5), width: 2),
                ),
              ),
              // Blue center dot
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              // Black location pin
              const Positioned(
                top: 10,
                child: Icon(
                  Icons.place,
                  size: 50,
                  color: Colors.black,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              // White dot in center of pin
              Positioned(
                top: 25,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Selected location marker (if different from current)
        if (selectedLocation.latitude != currentLocation!.latitude ||
            selectedLocation.longitude != currentLocation!.longitude)
          Marker(
            point: selectedLocation,
            width: 50,
            height: 50,
            child: const Icon(
              Icons.place,
              size: 50,
              color: Color(0xFFB21E1E),
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget buildLocationIndicator() {
    return Positioned(
      top: 10,
      right: 50,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade600,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.gps_fixed,
              color: Colors.white,
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              currentLocation != null ? 'GPS' : 'NO GPS',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMapOverlays() {
    return Stack(
      children: [
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.layers, size: 20),
              onPressed: onSwitchTileProvider,
              tooltip: tileProviders[currentTileProvider]['name'],
            ),
          ),
        ),
        if (locationLoading)
          const Positioned(
            top: 10,
            right: 10,
            child: CircularProgressIndicator(
              color: Color(0xFFB21E1E),
              strokeWidth: 2,
            ),
          ),
        Positioned(
          bottom: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Text(
              'Tap to expand',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildFullScreenHeader() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onToggleFullScreen,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'Select Location',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.layers),
              onPressed: onSwitchTileProvider,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              tooltip: tileProviders[currentTileProvider]['name'],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildLocationConfirmationCard() {
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedAddress.isEmpty ? 'Loading address...' : selectedAddress,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (selectedArea.isNotEmpty || selectedCity.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${selectedArea.isNotEmpty ? '$selectedArea, ' : ''}$selectedCity',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isAddressLoading)
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
            if (selectedState.isNotEmpty || selectedPostalCode.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.grey.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${selectedState.isNotEmpty ? '$selectedState ' : ''}$selectedPostalCode',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.gps_fixed,
                  color: Colors.grey.shade600,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${selectedLocation.latitude.toStringAsFixed(6)}, ${selectedLocation.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onConfirmLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB21E1E),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'CONFIRM LOCATION',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// MapLocationService - NO CHANGES
class MapLocationService {
  static Future<LatLng?> getCurrentLocation() async {
    try {
      print('🗺️ Checking location permissions...');

      final hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        print('❌ Location permission denied');
        return null;
      }

      print('✅ Location permission granted, getting position...');

      final isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationServiceEnabled) {
        print('❌ Location services are disabled');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      print('✅ Got current location: ${position.latitude}, ${position.longitude}');

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('❌ Error getting current location: $e');

      try {
        print('🔄 Trying to get last known position...');
        final lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          print('✅ Got last known location: ${lastPosition.latitude}, ${lastPosition.longitude}');
          return LatLng(lastPosition.latitude, lastPosition.longitude);
        }
      } catch (e2) {
        print('❌ Error getting last known position: $e2');
      }

      return null;
    }
  }

  static Future<Map<String, String>> getAddressFromLatLng(LatLng location) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        String address = '';
        String area = '';
        String city = '';
        String state = '';
        String postalCode = '';

        List<String> addressParts = [];
        if (place.name?.isNotEmpty == true) addressParts.add(place.name!);
        if (place.street?.isNotEmpty == true) addressParts.add(place.street!);
        if (place.subLocality?.isNotEmpty == true) addressParts.add(place.subLocality!);

        address = addressParts.join(', ');
        if (address.isEmpty) {
          address = '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
        }

        area = place.subLocality ?? place.locality ?? '';
        city = place.locality ?? place.subAdministrativeArea ?? '';
        state = place.administrativeArea ?? '';
        postalCode = place.postalCode ?? '';

        return {
          'address': address,
          'area': area,
          'city': city,
          'state': state,
          'postalCode': postalCode,
        };
      }
    } catch (e) {
      print('❌ Error getting address: $e');
    }

    return {
      'address': '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
      'area': '',
      'city': '',
      'state': '',
      'postalCode': '',
    };
  }

  static Future<bool> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    print('🔍 Current permission: $permission');

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      print('🔍 Permission after request: $permission');
    }

    if (permission == LocationPermission.deniedForever) {
      print('❌ Location permission denied forever');
      return false;
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  static StreamSubscription<Position>? _positionStream;

  static Stream<LatLng> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).map((position) => LatLng(position.latitude, position.longitude));
  }

  static void stopLocationStream() {
    _positionStream?.cancel();
    _positionStream = null;
  }
}

// MapConfig - NO CHANGES
class MapConfig {
  static const double defaultZoom = 16.0;
  static const double fullScreenZoom = 17.0;
  static const double maxZoom = 19.0;
  static const double minZoom = 3.0;
  static const Duration locationTimeout = Duration(seconds: 10);
  static const Duration addressTimeout = Duration(seconds: 5);

  static const List<Map<String, dynamic>> defaultTileProviders = [
    {
      'name': 'CartoDB Light',
      'url': 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
      'attribution': '© OpenStreetMap contributors © CARTO',
    },
    {
      'name': 'OpenStreetMap',
      'url': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      'attribution': '© OpenStreetMap contributors',
    },
    {
      'name': 'ESRI World Imagery',
      'url': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      'attribution': '© Esri',
    },
    {
      'name': 'ESRI World Street',
      'url': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
      'attribution': '© Esri',
    },
  ];
}