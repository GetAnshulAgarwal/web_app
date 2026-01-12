// lib/providers/location_provider.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../authentication/user_data.dart';
import '../model/Address/address_model.dart';
import '../model/Login/user_model.dart';
import '../services/Location/location_change_detector.dart';
import '../services/warehouse/warehouse_service.dart';

class LocationProvider extends ChangeNotifier {
  String _location = "Getting location...";
  bool _isLoading = false;
  bool _isManualAddress = false;
  String? _selectedAddressId;
  bool _autoReloadEnabled = true;
  bool _isServiceable = true;

  String get location => _location;
  bool get isLoading => _isLoading;
  bool get isManualAddress => _isManualAddress;
  String? get selectedAddressId => _selectedAddressId;
  bool get autoReloadEnabled => _autoReloadEnabled;
  bool get isServiceable => _isServiceable;

  LocationProvider() {
    _setupLocationChangeListener();
  }

  void startLocationTracking() {
    LocationChangeDetector.instance.startListening();
  }

  void stopLocationTracking() {
    LocationChangeDetector.instance.stopListening();
  }

  // ---------------------------------------------------------------------------
  // 1. PRIMARY: Force Fetch Current Location (GPS)
  // ---------------------------------------------------------------------------
  // 🔧 UPDATED: Added forceUpdate parameter
  Future<void> fetchCurrentLocationAndCheckZone({bool forceUpdate = false}) async {
    if (_isManualAddress && !forceUpdate) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Check Location Services
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _location = "Location Disabled";
        _isServiceable = false; // Mark unserviceable
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 2. Check Permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // --- CHANGE: Don't just return, set text and stop loading ---
          _location = "Location denied";
          _isServiceable = false;
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // --- CHANGE: Set specific text ---
        _location = "Location denied";
        _isServiceable = false;
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 3. Get Actual Coordinates (Keep existing logic)
      Position? position;
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (e) {
        debugPrint('⚠️ Failed to get last known position: $e');
      }

      if (position == null) {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
      }

      // 4. Get Readable Address
      final addressName = await _getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      // 5. Check Serviceability
      final userData = UserData();
      final user = userData.getCurrentUser();

      if (user?.token != null) {
        final zoneResult = await _checkLocationInZone(
          position.latitude,
          position.longitude,
          user!.token!,
        );

        // Update the internal serviceable state
        _isServiceable = zoneResult['inside'] == true;

        if (_isServiceable) {
          await _updateUserLocation(
            position.latitude,
            position.longitude,
            addressName,
            zoneResult,
          );
          _location = addressName;
          _isManualAddress = false;
          notifyListeners();
          _notifyServiceabilityChange(true, zoneResult['zoneName']);
        } else {
          // --- CHANGE: Even if outside zone, show the address, but mark unserviceable ---
          _location = addressName;
          _isManualAddress = false;
          notifyListeners(); // UI will update to show "Unavailable" text
          _notifyServiceabilityChange(false, null);
        }
      } else {
        _location = addressName;
        notifyListeners();
      }

    } catch (e) {
      debugPrint('❌ Error fetching current location: $e');
      if (_location == "Getting location...") {
        _location = "Location Error";
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // 2. SECONDARY: Refresh / Sync Logic
  // ---------------------------------------------------------------------------
  Future<void> checkLocationUpdate() async {
    // Only check updates if we haven't manually set a location
    if (_isManualAddress) {
      debugPrint('[LocationProvider] Skipping checkLocationUpdate (Manual address set)');
      return;
    }

    bool loadedFromSave = await _loadSavedLocation();

    if (!loadedFromSave) {
      await fetchCurrentLocationAndCheckZone(forceUpdate: false);
    }
  }

  // Called when user clicks "Use Current Location" button
  Future<void> refreshLocation() async {
    // Here we pass TRUE because the user specifically asked for GPS
    await fetchCurrentLocationAndCheckZone(forceUpdate: true);
  }

  // ---------------------------------------------------------------------------
  // 3. Internal Helpers
  // ---------------------------------------------------------------------------
  Future<bool> _loadSavedLocation() async {
    try {
      final userData = UserData();
      final user = userData.getCurrentUser();

      if (user != null && user.userAddress != null && user.userAddress!.isNotEmpty) {
        final address = user.userAddress!;
        _location = _extractDisplayLocation(address);
        // If loaded from saved user profile, treat as manual so it sticks
        _isManualAddress = true;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error loading saved location: $e');
    }
    return false;
  }

  void _setupLocationChangeListener() {
    LocationChangeDetector.instance.onLocationChange.listen((position) {
      // Only update if auto-reload is enabled AND we are NOT using a manual address
      if (_autoReloadEnabled && !_isManualAddress) {
        debugPrint('🔄 Auto-reload triggered by location change');
        _handleLocationChange(position);
      }
    });
  }

  Future<void> _handleLocationChange(Position position) async {
    final userData = UserData();
    final user = userData.getCurrentUser();
    if (user?.token == null) return;

    try {
      final zoneResult = await _checkLocationInZone(position.latitude, position.longitude, user!.token!);
      if (zoneResult['inside'] == true) {
        final address = await _getAddressFromCoordinates(position.latitude, position.longitude);
        _location = address;
        // Don't change _isManualAddress here, assume false because this is auto-tracking
        await _updateUserLocation(position.latitude, position.longitude, address, zoneResult);
        notifyListeners();
        _notifyServiceabilityChange(true, zoneResult['zoneName']);
      } else {
        _notifyServiceabilityChange(false, null);
      }
    } catch (e) { debugPrint('Error checking new location: $e'); }
  }

  final _serviceabilityController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onServiceabilityChange => _serviceabilityController.stream;

  void _notifyServiceabilityChange(bool isServiceable, String? zoneName) {
    _serviceabilityController.add({
      'isServiceable': isServiceable,
      'zoneName': zoneName,
      'timestamp': DateTime.now(),
    });
  }

  Future<String> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final city = placemark.locality ?? placemark.subLocality ?? '';
        final state = placemark.administrativeArea ?? '';
        return city.isNotEmpty && state.isNotEmpty ? '$city, $state' : placemark.street ?? 'Location detected';
      }
    } catch (e) { debugPrint('Error getting address: $e'); }
    return 'Location updated';
  }

  Future<void> _updateUserLocation(double lat, double lng, String address, Map<String, dynamic> zoneResult) async {
    final userData = UserData();
    final currentUser = userData.getCurrentUser();
    if (currentUser != null) {
      final updatedUser = UserModel(
        phone: currentUser.phone,
        name: currentUser.name,
        email: currentUser.email,
        city: currentUser.city,
        state: currentUser.state,
        country: currentUser.country,
        token: currentUser.token,
        isLoggedIn: currentUser.isLoggedIn,
        createdAt: currentUser.createdAt,
        id: currentUser.id,
        selectedWarehouseId: zoneResult['storeId'],
        estimatedDeliveryTime: 15,
        isServiceable: true,
        userLatitude: lat,
        userLongitude: lng,
        userAddress: address,
      );
      await userData.saveUser(updatedUser);
    }
  }

  void setAutoReload(bool enabled) {
    _autoReloadEnabled = enabled;
    notifyListeners();
    if (enabled) {
      LocationChangeDetector.instance.startListening();
    } else {
      LocationChangeDetector.instance.stopListening();
    }
  }

  String _extractDisplayLocation(String fullAddress) {
    final parts = fullAddress.split(',');
    if (parts.length >= 2) {
      final cityIndex = parts.length >= 3 ? parts.length - 3 : 0;
      final stateIndex = parts.length >= 2 ? parts.length - 2 : parts.length - 1;
      return "${parts[cityIndex].trim()}, ${parts[stateIndex].trim()}";
    }
    return fullAddress;
  }

  Future<Map<String, dynamic>> setManualAddressWithZoneCheck(Address address) async {
    if (address.latitude == null || address.longitude == null) {
      return {'success': false, 'message': 'Invalid address coordinates'};
    }

    final userData = UserData();
    final user = userData.getCurrentUser();
    if (user?.token == null) return {'success': false, 'message': 'User not authenticated'};

    try {
      final zoneResult = await _checkLocationInZone(address.latitude!, address.longitude!, user!.token!);

      _isServiceable = zoneResult['inside'];

      if (!zoneResult['inside']) {
        await _saveAddressWithZoneInfo(address, zoneResult, user);
        _location = _formatAddressForDisplay(address);
        _isManualAddress = true;
        _selectedAddressId = address.id;
        setAutoReload(false);
        notifyListeners();
        return {'success': false, 'message': "Not delivering to this area", 'isServiceable': false};
      }

      await _saveAddressWithZoneInfo(address, zoneResult, user);

      _location = _formatAddressForDisplay(address);

      // ✅ CRITICAL: Set this to true so GPS fetch is skipped next time
      _isManualAddress = true;

      _selectedAddressId = address.id;
      setAutoReload(false);

      notifyListeners();

      return {
        'success': true,
        'isServiceable': true,
        'zoneName': zoneResult['zoneName'],
        'deliveryFee': zoneResult['deliveryFee'],
        'minOrder': zoneResult['minOrder'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> _checkLocationInZone(double lat, double lng, String token) async {
    final url = Uri.parse('${ZoneWarehouseService.baseUrl}/check-location');
    try {
      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode({'lat': lat, 'lng': lng}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['inside'] == true) {
          return {
            'inside': true,
            'zoneId': data['zoneId'],
            'zoneName': data['zoneName'],
            'storeId': data['storeId'],
            'deliveryFee': (data['deliveryFee'] ?? 0).toDouble(),
            'minOrder': (data['minOrder'] ?? 0).toDouble(),
          };
        }
      }
      return {'inside': false};
    } catch (e) { return {'inside': false}; }
  }

  Future<void> _saveAddressWithZoneInfo(Address address, Map<String, dynamic> zoneResult, UserModel currentUser) async {
    final userData = UserData();
    final updatedUser = UserModel(
      phone: currentUser.phone,
      name: currentUser.name,
      email: currentUser.email,
      city: address.city,
      state: address.state,
      country: address.country,
      token: currentUser.token,
      isLoggedIn: currentUser.isLoggedIn,
      createdAt: currentUser.createdAt,
      id: currentUser.id,
      selectedWarehouseId: zoneResult['storeId'],
      estimatedDeliveryTime: 15,
      isServiceable: true,
      userLatitude: address.latitude,
      userLongitude: address.longitude,
      userAddress: address.fullAddress,
    );
    await userData.saveUser(updatedUser);
  }

  String _formatAddressForDisplay(Address address) {
    if (address.city.isNotEmpty && address.state.isNotEmpty) return "${address.city}, ${address.state}";
    return address.label;
  }

  @override
  void dispose() {
    _serviceabilityController.close();
    LocationChangeDetector.instance.dispose();
    super.dispose();
  }
}