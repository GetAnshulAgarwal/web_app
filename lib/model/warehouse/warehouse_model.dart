// models/warehouse.dart
import 'package:geolocator/geolocator.dart';

class Warehouse {
  final String id;
  final String warehouseId;
  final String name;
  final WarehouseCoords coords;
  final DateTime updatedAt;
  final bool isActive;
  final String? address;
  final String? pincode;
  final List<String> serviceAreas;
  final int deliveryRadius; // in meters
  final String? phone;
  final Map<String, dynamic>? operatingHours;

  Warehouse({
    required this.id,
    required this.warehouseId,
    required this.name,
    required this.coords,
    required this.updatedAt,
    this.isActive = true,
    this.address,
    this.pincode,
    this.serviceAreas = const [],
    this.deliveryRadius = 5000,
    this.phone,
    this.operatingHours,
  });

  factory Warehouse.fromJson(Map<String, dynamic> json) {
    return Warehouse(
      id: json['_id'] ?? '',
      warehouseId: json['warehouse'] ?? '',
      name: json['name'] ?? 'Warehouse ${json['warehouse'] ?? ''}',
      coords: WarehouseCoords.fromJson(json['coords'] ?? {}),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      isActive: json['isActive'] ?? true,
      address: json['address'],
      pincode: json['pincode'],
      serviceAreas: List<String>.from(json['serviceAreas'] ?? []),
      deliveryRadius: json['deliveryRadius'] ?? 5000,
      phone: json['phone'],
      operatingHours: json['operatingHours'],
    );
  }

  double get latitude => coords.coordinates.length > 1 ? coords.coordinates[1] : 0.0;
  double get longitude => coords.coordinates.isNotEmpty ? coords.coordinates[0] : 0.0;

  bool get isOpen {
    if (operatingHours == null) return true;

    final now = DateTime.now();
    final currentHour = now.hour;
    final dayOfWeek = now.weekday;

    // Implement your operating hours logic here
    return true; // Simplified for now
  }
}

class WarehouseCoords {
  final String type;
  final List<double> coordinates; // [longitude, latitude]

  WarehouseCoords({
    required this.type,
    required this.coordinates,
  });

  factory WarehouseCoords.fromJson(Map<String, dynamic> json) {
    final coordsList = (json['coordinates'] as List?)?.cast<num>() ?? [];
    return WarehouseCoords(
      type: json['type'] ?? 'Point',
      coordinates: coordsList.map((e) => e.toDouble()).toList(),
    );
  }
}

class UserLocation {
  final double latitude;
  final double longitude;
  final String formattedAddress;
  final String? pincode;
  final DateTime timestamp;

  UserLocation({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    this.pincode,
    required this.timestamp,
  });

  factory UserLocation.fromPosition(Position position, String address, [String? pincode]) {
    return UserLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      formattedAddress: address,
      pincode: pincode,
      timestamp: DateTime.now(),
    );
  }
}

class WarehouseWithDetails {
  final Warehouse warehouse;
  final double distance; // in meters
  final int estimatedDeliveryTime; // in minutes
  final bool canDeliver;
  final String deliveryStatus;

  WarehouseWithDetails({
    required this.warehouse,
    required this.distance,
    required this.estimatedDeliveryTime,
    required this.canDeliver,
    required this.deliveryStatus,
  });

  String get distanceFormatted {
    if (distance < 1000) {
      return '${distance.round()} m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
  }

  String get deliveryTimeFormatted {
    if (estimatedDeliveryTime < 60) {
      return '${estimatedDeliveryTime} mins';
    } else {
      final hours = (estimatedDeliveryTime / 60).floor();
      final mins = estimatedDeliveryTime % 60;
      return '${hours}h ${mins}m';
    }
  }
}