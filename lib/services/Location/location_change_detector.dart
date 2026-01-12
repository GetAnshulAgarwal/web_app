// lib/services/Location/location_change_detector.dart

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class LocationChangeDetector {
  static LocationChangeDetector? _instance;
  static LocationChangeDetector get instance {
    _instance ??= LocationChangeDetector._();
    return _instance!;
  }

  LocationChangeDetector._();

  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _lastKnownPosition;
  final _locationChangeController = StreamController<Position>.broadcast();

  // Minimum distance in meters to trigger a location change event
  static const double _significantDistanceThreshold = 500.0; // 500 meters

  bool _isListening = false;

  Stream<Position> get onLocationChange => _locationChangeController.stream;

  Future<void> startListening() async {
    if (_isListening) {
      debugPrint('📍 Location listener already active');
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

      // Quick start: Try last known first to avoid waiting
      _lastKnownPosition = await Geolocator.getLastKnownPosition();

      // If no last known, get current (but with medium accuracy for speed)
      if (_lastKnownPosition == null) {
        _lastKnownPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium, // CHANGED: 'balanced' -> 'medium'
            timeLimit: Duration(seconds: 5),
          ),
        );
      }

      debugPrint('✅ Started listening (Background)');

      // Start listening to position stream with Medium accuracy
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.medium, // CHANGED: 'balanced' -> 'medium'
        distanceFilter: 200, // Increased to 200m to reduce noise
      );

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _onPositionUpdate,
        onError: (error) {
          debugPrint('❌ Location stream error: $error');
        },
      );

      _isListening = true;
    } catch (e) {
      debugPrint('❌ Error starting location listener: $e');
    }
  }

  void _onPositionUpdate(Position position) {
    if (_lastKnownPosition == null) {
      _lastKnownPosition = position;
      return;
    }

    double distanceInMeters = Geolocator.distanceBetween(
      _lastKnownPosition!.latitude,
      _lastKnownPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    if (distanceInMeters >= _significantDistanceThreshold) {
      debugPrint('🚶 Significant location change detected ($distanceInMeters m)');
      _lastKnownPosition = position;
      _locationChangeController.add(position);
    }
  }

  void stopListening() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _isListening = false;
  }

  bool get isListening => _isListening;
  Position? get lastKnownPosition => _lastKnownPosition;

  void dispose() {
    stopListening();
    _locationChangeController.close();
  }
}