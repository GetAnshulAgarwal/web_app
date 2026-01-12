// models/order_model.dart
class OrderModel {
  final String id;
  final String orderNumber;
  final String customerId;
  final String customerName;
  final String status;
  final double totalAmount;
  final double tax;
  final double shippingFee;
  final double discountApplied;
  final double finalAmount;
  final String paymentMethod;
  final bool paymentVerified;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderItemModel> items;
  final OrderAddressModel address;
  final OrderDeliveryModel? delivery;
  final OrderBillingModel billing;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    required this.status,
    required this.totalAmount,
    required this.tax,
    required this.shippingFee,
    required this.discountApplied,
    required this.finalAmount,
    required this.paymentMethod,
    required this.paymentVerified,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    required this.address,
    required this.billing,
    this.delivery,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['_id'] ?? '',
      orderNumber: json['orderNumber'] ?? '',
      customerId: json['customer'] ?? '',
      customerName: json['customerName'] ?? '',
      status: json['status'] ?? 'Pending',
      totalAmount: (json['amount'] ?? 0).toDouble(),
      tax: (json['tax'] ?? 0).toDouble(),
      shippingFee: (json['shippingFee'] ?? 0).toDouble(),
      discountApplied: (json['discountApplied'] ?? 0).toDouble(),
      finalAmount: (json['finalAmount'] ?? 0).toDouble(),
      paymentMethod: json['paymentMethod'] ?? 'COD',
      paymentVerified: json['paymentVerified'] ?? false,
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
      items:
          (json['items'] as List<dynamic>? ?? [])
              .map((item) => OrderItemModel.fromJson(item))
              .toList(),
      address: OrderAddressModel.fromJson(json['address'] ?? {}),
      billing: OrderBillingModel.fromJson(json['billing'] ?? {}),
      delivery:
          json['delivery'] != null
              ? OrderDeliveryModel.fromJson(json['delivery'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'orderNumber': orderNumber,
      'customer': customerId,
      'customerName': customerName,
      'status': status,
      'amount': totalAmount,
      'tax': tax,
      'shippingFee': shippingFee,
      'discountApplied': discountApplied,
      'finalAmount': finalAmount,
      'paymentMethod': paymentMethod,
      'paymentVerified': paymentVerified,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
      'address': address.toJson(),
      'billing': billing.toJson(),
      if (delivery != null) 'delivery': delivery!.toJson(),
    };
  }
}

class OrderItemModel {
  final String itemId;
  final String itemName;
  final String itemImage;
  final double itemPrice;
  final int quantity;
  final double totalPrice;
  final String weight;

  OrderItemModel({
    required this.itemId,
    required this.itemName,
    required this.itemImage,
    required this.itemPrice,
    required this.quantity,
    required this.totalPrice,
    required this.weight,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      itemId: json['itemId'] ?? '',
      itemName: json['itemName'] ?? '',
      itemImage: json['itemImage'] ?? '',
      itemPrice: (json['itemPrice'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 0,
      totalPrice: (json['totalPrice'] ?? 0).toDouble(),
      weight: json['weight'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'itemImage': itemImage,
      'itemPrice': itemPrice,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'weight': weight,
    };
  }
}

class OrderAddressModel {
  final String country;
  final String state;
  final String city;
  final String houseNo;
  final String area;
  final String postalCode;
  final String locationLink;

  OrderAddressModel({
    required this.country,
    required this.state,
    required this.city,
    required this.houseNo,
    required this.area,
    required this.postalCode,
    required this.locationLink,
  });

  factory OrderAddressModel.fromJson(Map<String, dynamic> json) {
    return OrderAddressModel(
      country: json['country'] ?? '',
      state: json['state'] ?? '',
      city: json['city'] ?? '',
      houseNo: json['houseNo'] ?? '',
      area: json['area'] ?? '',
      postalCode: json['postalCode'] ?? '',
      locationLink: json['locationLink'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'country': country,
      'state': state,
      'city': city,
      'houseNo': houseNo,
      'area': area,
      'postalCode': postalCode,
      'locationLink': locationLink,
    };
  }
}

class OrderDeliveryModel {
  final String? deliveryAgentId;
  final String? deliveryAgentName;
  final String? deliveryAgentModel;
  final String? deliveryType;
  final DateTime? assignedAt;
  final DateTime? deliveredAt;

  OrderDeliveryModel({
    this.deliveryAgentId,
    this.deliveryAgentName,
    this.deliveryAgentModel,
    this.deliveryType,
    this.assignedAt,
    this.deliveredAt,
  });

  factory OrderDeliveryModel.fromJson(Map<String, dynamic> json) {
    return OrderDeliveryModel(
      deliveryAgentId: json['deliveryAgentId'],
      deliveryAgentName: json['deliveryAgentName'],
      deliveryAgentModel: json['deliveryAgentModel'],
      deliveryType: json['deliveryType'],
      assignedAt:
          json['assignedAt'] != null
              ? DateTime.parse(json['assignedAt'])
              : null,
      deliveredAt:
          json['deliveredAt'] != null
              ? DateTime.parse(json['deliveredAt'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (deliveryAgentId != null) 'deliveryAgentId': deliveryAgentId,
      if (deliveryAgentName != null) 'deliveryAgentName': deliveryAgentName,
      if (deliveryAgentModel != null) 'deliveryAgentModel': deliveryAgentModel,
      if (deliveryType != null) 'deliveryType': deliveryType,
      if (assignedAt != null) 'assignedAt': assignedAt!.toIso8601String(),
      if (deliveredAt != null) 'deliveredAt': deliveredAt!.toIso8601String(),
    };
  }
}

class OrderBillingModel {
  final double itemsTotal;
  final double deliveryCharge;
  final double platformCharges;
  final double cartCharges;
  final double tip;
  final double donation;
  final double grandTotal;

  OrderBillingModel({
    required this.itemsTotal,
    required this.deliveryCharge,
    required this.platformCharges,
    required this.cartCharges,
    required this.tip,
    required this.donation,
    required this.grandTotal,
  });

  factory OrderBillingModel.fromJson(Map<String, dynamic> json) {
    return OrderBillingModel(
      itemsTotal: (json['itemsTotal'] ?? 0).toDouble(),
      deliveryCharge: (json['deliveryCharge'] ?? 0).toDouble(),
      platformCharges: (json['platformCharges'] ?? 0).toDouble(),
      cartCharges: (json['cartCharges'] ?? 0).toDouble(),
      tip: (json['tip'] ?? 0).toDouble(),
      donation: (json['donation'] ?? 0).toDouble(),
      grandTotal: (json['grandTotal'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemsTotal': itemsTotal,
      'deliveryCharge': deliveryCharge,
      'platformCharges': platformCharges,
      'cartCharges': cartCharges,
      'tip': tip,
      'donation': donation,
      'grandTotal': grandTotal,
    };
  }
}

class CheckoutSessionModel {
  final String checkoutSessionId;
  final double amount;
  final List<OrderItemModel> items;
  final DateTime expiresAt;
  final String razorpayId;

  CheckoutSessionModel({
    required this.checkoutSessionId,
    required this.amount,
    required this.items,
    required this.expiresAt,
    required this.razorpayId,
  });

  factory CheckoutSessionModel.fromJson(Map<String, dynamic> json) {
    return CheckoutSessionModel(
      checkoutSessionId: json['checkoutSessionId'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      items:
          (json['items'] as List<dynamic>? ?? [])
              .map((item) => OrderItemModel.fromJson(item))
              .toList(),
      expiresAt: DateTime.parse(
        json['expiresAt'] ?? DateTime.now().toIso8601String(),
      ),
      razorpayId: json['razorpayId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'checkoutSessionId': checkoutSessionId,
      'amount': amount,
      'items': items.map((item) => item.toJson()).toList(),
      'expiresAt': expiresAt.toIso8601String(),
      'razorpayId': razorpayId,
    };
  }
}
