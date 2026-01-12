// [File: address_model.dart]

enum AddressType { home, work, other }

class Address {
  final String id;
  final String label;
  final String street;
  final String area;
  final String city;
  final String state;
  final String country;
  final String postalCode;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? latitude;
  final double? longitude;

  Address({
    required this.id,
    required this.label,
    required this.street,
    required this.area,
    required this.city,
    required this.state,
    required this.country,
    required this.postalCode,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
    this.latitude,
    this.longitude,
  });

  bool get isValid => id.isNotEmpty && label.isNotEmpty && street.isNotEmpty;

  String get fullAddress {
    return '$street, $area, $city, $state, $country - $postalCode';
  }

  AddressType get addressType {
    switch (label.toLowerCase()) {
      case 'home':
        return AddressType.home;
      case 'work':
      case 'office':
        return AddressType.work;
      default:
        return AddressType.other;
    }
  }


  // FIXED: Handle both _id and id fields
  // --- MODIFIED: To handle new 'location' object ---
  factory Address.fromJson(Map<String, dynamic> json) {
    double? lat;
    double? lng;

    // Check for the new GeoJSON 'location' object
    if (json['location'] != null &&
        json['location']['coordinates'] is List &&
        (json['location']['coordinates'] as List).length >= 2) {
      final coords = json['location']['coordinates'] as List;
      // API format is [longitude, latitude]
      lng = coords[0]?.toDouble();
      lat = coords[1]?.toDouble();
    } else {
      // Fallback to old format (or cache format)
      lat = json['latitude']?.toDouble();
      lng = json['longitude']?.toDouble();
    }

    return Address(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      street: json['street']?.toString() ?? '',
      area: json['area']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      postalCode: json['postalCode']?.toString() ?? '',
      isDefault: json['isDefault'] == true,
      createdAt:
      json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt:
      json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      latitude: lat,
      longitude: lng,
    );
  }

  // --- MODIFIED: To send 'lat' and 'lng' keys ---
  Map<String, dynamic> toCreateJson() {
    return {
      'label': label,
      'street': street,
      'area': area,
      'city': city,
      'state': state,
      'country': country,
      'postalCode': postalCode,
      'isDefault': isDefault,
      if (latitude != null) 'lat': latitude,
      if (longitude != null) 'lng': longitude,
    };
  }

  /// JSON representation used for caching/storing locally.
  /// Includes the id and timestamps so cached records can be round-tripped.
  Map<String, dynamic> toCacheJson() {
    return {
      '_id': id,
      'id': id,
      'label': label,
      'street': street,
      'area': area,
      'city': city,
      'state': state,
      'country': country,
      'postalCode': postalCode,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      // Note: Caching uses 'latitude' and 'longitude' keys
      // This is fine, as fromJson can read them back
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  /// Alias for cache-friendly JSON representation.
  Map<String, dynamic> toJson() => toCacheJson();

  // --- MODIFIED: To send 'lat' and 'lng' keys ---
  Map<String, dynamic> toUpdateJson() {
    return {
      'label': label,
      'street': street,
      'area': area,
      'city': city,
      'state': state,
      'country': country,
      'postalCode': postalCode,
      'isDefault': isDefault,
      if (latitude != null) 'lat': latitude,
      if (longitude != null) 'lng': longitude,
    };
  }

  Address copyWith({
    String? id,
    String? label,
    String? street,
    String? area,
    String? city,
    String? state,
    String? country,
    String? postalCode,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? latitude,
    double? longitude,
  }) {
    return Address(
      id: id ?? this.id,
      label: label ?? this.label,
      street: street ?? this.street,
      area: area ?? this.area,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  bool operator == (Object other) =>
      identical(this, other) ||
          other is Address && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Address{id: $id, label: $label, fullAddress: $fullAddress, isDefault: $isDefault}';
  }
}
extension AddressHelpers on Address {
  /// Get a short display format for location header
  String getShortDisplay() {
    if (city.isNotEmpty && state.isNotEmpty) {
      return "$city, $state";
    } else if (city.isNotEmpty) {
      return city;
    } else if (area.isNotEmpty && city.isNotEmpty) {
      return "$area, $city";
    } else {
      return label;
    }
  }

  /// Get a full display format for dialogs/details
  String getFullDisplay() {
    List<String> parts = [];

    if (street.isNotEmpty) parts.add(street);
    if (area.isNotEmpty) parts.add(area);
    if (city.isNotEmpty) parts.add(city);
    if (state.isNotEmpty) parts.add(state);
    if (postalCode.isNotEmpty) parts.add(postalCode);
    if (country.isNotEmpty) parts.add(country);

    return parts.isEmpty ? label : parts.join(', ');
  }
}