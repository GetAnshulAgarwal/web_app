// lib/model/cart/cart_item_model.dart
class CartItem {
  final String id;
  final String itemId;
  final String itemName;
  final String itemCode;
  final String itemImage;
  final double price;
  final double salesPrice;
  final String unit;
  final String brand;
  final int quantity;
  final double totalPrice;
  final String addedAt;

  // Fields for Coupon Validation
  final String categoryId;
  final String subCategoryId;
  final String subSubCategoryId; // New Field

  CartItem({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.itemCode,
    required this.itemImage,
    required this.price,
    required this.salesPrice,
    required this.unit,
    required this.brand,
    required this.quantity,
    required this.totalPrice,
    required this.addedAt,
    this.categoryId = '',
    this.subCategoryId = '',
    this.subSubCategoryId = '', // Default empty
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    // Helper to extract nested ID safely
    String extractId(dynamic field) {
      if (field is Map) return field['_id']?.toString() ?? '';
      if (field is String) return field;
      return '';
    }

    return CartItem(
      id: json['id']?.toString() ?? '',
      itemId: json['itemId']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? 'Unknown Product',
      itemCode: json['itemCode']?.toString() ?? '',
      itemImage: json['itemImage']?.toString() ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      salesPrice: (json['salesPrice'] ?? 0.0).toDouble(),
      unit: json['unit']?.toString() ?? '',
      brand: json['brand']?.toString() ?? '',
      quantity: (json['quantity'] ?? 0).toInt(),
      totalPrice: (json['totalPrice'] ?? 0.0).toDouble(),
      addedAt: json['addedAt']?.toString() ?? '',

      // Validation IDs
      categoryId: extractId(json['category']),
      subCategoryId: extractId(json['subCategory']),
      subSubCategoryId: extractId(json['subSubCategory'] ?? json['subsubCategory']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'itemId': itemId,
      'itemName': itemName,
      'itemCode': itemCode,
      'itemImage': itemImage,
      'price': price,
      'salesPrice': salesPrice,
      'unit': unit,
      'brand': brand,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'addedAt': addedAt,
      'category': categoryId,
      'subCategory': subCategoryId,
      'subSubCategory': subSubCategoryId,
    };
  }
}