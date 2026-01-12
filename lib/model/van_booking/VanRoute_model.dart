import 'package:latlong2/latlong.dart';

class VanRouteLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  VanRouteLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  factory VanRouteLocation.fromJson(Map<String, dynamic> json) {
    return VanRouteLocation(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  LatLng toLatLng() {
    return LatLng(latitude, longitude);
  }
}

// Updated BookingResponse model
class BookingResponse {
  final bool success;
  final String customer;
  final String pickupAddress;
  final String type;
  final String scheduledFor;
  final String remark;
  final String status;
  final String id;
  final String createdAt;
  final String updatedAt;
  final int v;

  BookingResponse({
    required this.success,
    required this.customer,
    required this.pickupAddress,
    required this.type,
    required this.scheduledFor,
    required this.remark,
    required this.status,
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.v,
  });

  factory BookingResponse.fromJson(Map<String, dynamic> json) {
    return BookingResponse(
      success: json['success'] ?? true,
      customer: json['data']['customer'] ?? '',
      pickupAddress: json['data']['pickupAddress'] ?? '',
      type: json['data']['type'] ?? '',
      scheduledFor: json['data']['scheduledFor'] ?? '',
      remark: json['data']['remark'] ?? '',
      status: json['data']['status'] ?? '',
      id: json['data']['_id'] ?? '',
      createdAt: json['data']['createdAt'] ?? '',
      updatedAt: json['data']['updatedAt'] ?? '',
      v: json['data']['__v'] ?? 0,
    );
  }

  // For backward compatibility
  String get bookingId => id;
  String get message => 'Booking created successfully';
}

// Updated UserBooking model
// In your UserBooking model
// In VanRoute_model.dart

// In VanRoute_model.dart

class UserBooking {
  final String id;
  final String customer;
  final PickupAddress pickupAddress;
  final String bookingType;
  final DateTime? scheduledFor;
  final String remark;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int v;
  final OrderInfo? order; // <-- ADDED THIS FIELD

  UserBooking({
    required this.id,
    required this.customer,
    required this.pickupAddress,
    required this.bookingType,
    this.scheduledFor,
    required this.remark,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.v,
    this.order, // <-- ADDED THIS
  });

  // Factory now defaults order to null
  factory UserBooking.fromJson(Map<String, dynamic> json) {
    return UserBooking(
      id: json['_id'] ?? json['id'] ?? '',
      customer: json['customer'] ?? '',
      pickupAddress: PickupAddress.fromJson(json['pickupAddress'] ?? {}),
      bookingType: json['type'] ?? 'instant',
      scheduledFor:
      json['scheduledFor'] != null
          ? DateTime.tryParse(json['scheduledFor'])
          : null,
      remark: json['remark'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      v: json['__v'] ?? 0,
      order: null, // <-- List view doesn't have order, so default to null
    );
  }

  // <-- ADD THIS ENTIRE METHOD -->
  // This lets us add the order details after parsing the booking
  UserBooking copyWith({
    String? id,
    String? customer,
    PickupAddress? pickupAddress,
    String? bookingType,
    DateTime? scheduledFor,
    String? remark,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? v,
    OrderInfo? order,
  }) {
    return UserBooking(
      id: id ?? this.id,
      customer: customer ?? this.customer,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      bookingType: bookingType ?? this.bookingType,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      remark: remark ?? this.remark,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      v: v ?? this.v,
      order: order ?? this.order,
    );
  }
}

class PickupAddress {
  final String id;
  final String street;
  final String area;
  final String city;
  final String state;
  final String country;
  final String postalCode;
  final List<double> coordinates;

  PickupAddress({
    required this.id,
    required this.street,
    required this.area,
    required this.city,
    required this.state,
    required this.country,
    required this.postalCode,
    required this.coordinates,
  });

  factory PickupAddress.fromJson(Map<String, dynamic> json) {
    return PickupAddress(
      id: json['_id'] ?? json['id'] ?? '',
      street: json['street'] ?? '',
      area: json['area'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      country: json['country'] ?? 'India',
      postalCode: json['postalCode'] ?? '',
      coordinates:
          json['coordinates'] != null
              ? List<double>.from(json['coordinates'].map((x) => x.toDouble()))
              : [0.0, 0.0],
    );
  }
}
// PickupAddress model

// Updated BookingDetails model
class BookingDetails {
  final String id;
  final String customer;
  final PickupAddress pickupAddress;
  final String type;
  final DateTime? scheduledFor;
  final String remark;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int v;
  final DateTime? assignedAt;
  final String? assignedBy;
  final String? van;
  final DateTime? acceptedAt;
  final String? acceptedBy;
  final OrderInfo? order;

  BookingDetails({
    required this.id,
    required this.customer,
    required this.pickupAddress,
    required this.type,
    this.scheduledFor,
    required this.remark,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.v,
    this.assignedAt,
    this.assignedBy,
    this.van,
    this.acceptedAt,
    this.acceptedBy,
    this.order,
  });

  factory BookingDetails.fromJson(Map<String, dynamic> json) {
    return BookingDetails(
      id: json['_id'] ?? '',
      customer: json['customer'] ?? '',
      pickupAddress: PickupAddress.fromJson(json['pickupAddress'] ?? {}),
      type: json['type'] ?? '',
      scheduledFor:
          json['scheduledFor'] != null
              ? DateTime.parse(json['scheduledFor'])
              : null,
      remark: json['remark'] ?? '',
      status: json['status'] ?? '',
      createdAt:
          json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : DateTime.now(),
      updatedAt:
          json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt'])
              : DateTime.now(),
      v: json['__v'] ?? 0,
      assignedAt:
          json['assignedAt'] != null
              ? DateTime.parse(json['assignedAt'])
              : null,
      assignedBy: json['assignedBy'],
      van: json['van'],
      acceptedAt:
          json['acceptedAt'] != null
              ? DateTime.parse(json['acceptedAt'])
              : null,
      acceptedBy: json['acceptedBy'],
      order: json['order'] != null ? OrderInfo.fromJson(json['order']) : null,
    );
  }
}

// OrderInfo model
// class OrderInfo {
//   final String id;
//   final List<OrderItem> items;

//   OrderInfo({required this.id, required this.items});

//   factory OrderInfo.fromJson(Map<String, dynamic> json) {
//     return OrderInfo(
//       id: json['_id'] ?? '',
//       items:
//           json['items'] != null
//               ? List<OrderItem>.from(
//                 json['items'].map((x) => OrderItem.fromJson(x)),
//               )
//               : [],
//     );
//   }
// }
class OrderInfo {
  final String id;
  final List<OrderItem> items;
  final num totalAmount;
  final num totalDiscount;
  final num balanceDue;
  final num changeReturn;
  final List<PaymentInfo> payments;

  OrderInfo({
    required this.id,
    required this.items,
    required this.totalAmount,
    required this.totalDiscount,
    required this.balanceDue,
    required this.changeReturn,
    required this.payments,
  });

  factory OrderInfo.fromJson(Map<String, dynamic> json) {
    return OrderInfo(
      id: json['_id']?.toString() ?? '',
      items: json['items'] != null
          ? List<OrderItem>.from(
              json['items'].map((x) => OrderItem.fromJson(x)),
            )
          : [],
      totalAmount: json['totalAmount'] ?? 0,
      totalDiscount: json['totalDiscount'] ?? 0,
      balanceDue: json['balanceDue'] ?? 0,
      changeReturn: json['changeReturn'] ?? 0,
      payments: json['payments'] != null
          ? List<PaymentInfo>.from(
              json['payments'].map((x) => PaymentInfo.fromJson(x)),
            )
          : [],
    );
  }
}
class PaymentInfo {
  final String paymentType;
  final num amount;

  PaymentInfo({
    required this.paymentType,
    required this.amount,
  });

  factory PaymentInfo.fromJson(Map<String, dynamic> json) {
    return PaymentInfo(
      paymentType: json['paymentType'] ?? '',
      amount: json['amount'] ?? 0,
    );
  }
}


// OrderItem model
class OrderItem {
  final String itemName;
  final int quantity;
  final double price;
  final double subtotal;

  OrderItem({
    required this.itemName,
    required this.quantity,
    required this.price,
    required this.subtotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      itemName: json['itemName'] ?? '',
      quantity: json['quantity'] ?? 0,
      price: (json['price'] ?? 0).toDouble(),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
    );
  }
}

// Keep your existing models (VanRouteLocation, RouteProgress, Basket)

class RouteProgress {
  final double currentProgress;
  final String startTime;
  final String distance;

  RouteProgress({
    required this.currentProgress,
    required this.startTime,
    required this.distance,
  });

  factory RouteProgress.fromJson(Map<String, dynamic> json) {
    return RouteProgress(
      currentProgress: (json['currentProgress'] ?? 0).toDouble(),
      startTime: json['startTime'] ?? '',
      distance: json['distance'] ?? '',
    );
  }
}

class Basket {
  final int itemCount;
  final List<dynamic> items;
  final double totalAmount;

  Basket({
    required this.itemCount,
    required this.items,
    required this.totalAmount,
  });

  factory Basket.fromJson(Map<String, dynamic> json) {
    return Basket(
      itemCount: json['itemCount'] ?? 0,
      items: json['items'] ?? [],
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
    );
  }
}
