// model/Login/user_model.dart
import 'package:hive/hive.dart';

part 'user_model.g.dart'; // Generated file

@HiveType(typeId: 0)
class UserModel extends HiveObject {
  @HiveField(0)
  final String phone;

  @HiveField(1)
  final String? name;

  @HiveField(2)
  final String? email;

  @HiveField(3)
  final String? city;

  @HiveField(4)
  final String? state;

  @HiveField(5)
  final String? country;

  @HiveField(6)
  final String? token;

  @HiveField(7)
  final bool isLoggedIn;

  @HiveField(8)
  final DateTime? createdAt;

  @HiveField(9)
  final String? id;

  // NEW FIELDS for warehouse info (hidden from user)
  @HiveField(10)
  final String? selectedWarehouseId;

  @HiveField(11)
  final int? estimatedDeliveryTime; // in minutes

  @HiveField(12)
  final bool? isServiceable;

  @HiveField(13)
  final double? userLatitude;

  @HiveField(14)
  final double? userLongitude;

  @HiveField(15)
  final String? userAddress;

  UserModel({
    required this.phone,
    this.name,
    this.email,
    this.city,
    this.state,
    this.country,
    this.token,
    this.isLoggedIn = false,
    this.createdAt,
    this.id,
    // New warehouse fields
    this.selectedWarehouseId,
    this.estimatedDeliveryTime,
    this.isServiceable,
    this.userLatitude,
    this.userLongitude,
    this.userAddress,
  });

  // Helper methods for delivery info (what user sees)
  String get deliveryStatus {
    if (!isServiceable!) return "Not serviceable";
    if (estimatedDeliveryTime == null) return "Delivery available";

    if (estimatedDeliveryTime! <= 15) return "Express delivery";
    if (estimatedDeliveryTime! <= 30) return "Fast delivery";
    return "Standard delivery";
  }

  String get deliveryTimeDisplay {
    if (!isServiceable! || estimatedDeliveryTime == null) return "N/A";
    return "${estimatedDeliveryTime} mins";
  }

  bool get hasWarehouseInfo {
    return selectedWarehouseId != null && isServiceable != null;
  }
}