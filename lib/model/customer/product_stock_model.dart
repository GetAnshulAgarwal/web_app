class ProductStockModel {
  final String id;
  final String itemName;
  final String variant;
  final double salesPrice;
  final int stock;
  final String itemImageUrl;
  final bool isAvailable;

  ProductStockModel({
    required this.id,
    required this.itemName,
    required this.variant,
    required this.salesPrice,
    required this.stock,
    required this.itemImageUrl,
    required this.isAvailable,
  });

  // Customer-focused stock properties
  bool get isOutOfStock => stock <= 0 || !isAvailable;
  bool get isLimitedStock => stock > 0 && stock <= 3;
  bool get canAddToCart => stock > 0 && isAvailable;

  String? get stockMessage {
    if (isOutOfStock) return 'Out of Stock';
    if (isLimitedStock) return 'Only $stock left';
    return null;
  }

  factory ProductStockModel.fromJson(Map<String, dynamic> json) {
    return ProductStockModel(
      id: json['_id'] ?? '',
      itemName: json['itemName'] ?? '',
      variant: json['variant'] ?? '',
      salesPrice: (json['salesPrice'] ?? 0).toDouble(),
      stock: json['stock'] ?? 0,
      itemImageUrl: json['itemImage'] ?? '',
      isAvailable: json['isOnline'] ?? false,
    );
  }
}
