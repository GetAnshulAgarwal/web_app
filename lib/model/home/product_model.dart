class Product {
  final String id;
  final String itemName;
  final String brand;
  final String unit;
  final String description;
  final List<String> itemImages;
  final double mrp;
  final double salesPrice;
  final int stock;

  // ✅ ADDED VARIANT FIELDS
  final String? itemGroup;
  final String? parentItemId;
  final String? variantName;
  final List<Product>? variants; // Holds sibling variants

  Product({
    required this.id,
    required this.itemName,
    required this.brand,
    required this.unit,
    required this.description,
    required this.itemImages,
    required this.mrp,
    required this.salesPrice,
    required this.stock,
    this.itemGroup,
    this.parentItemId,
    this.variantName,
    this.variants,
  });

  // ✅ HELPER: Clean name without "Previous/Latest variant"
  String get displayName {
    String name = itemName;
    // Remove specific variant suffixes
    name = name.replaceAll(RegExp(r' -? ?Previous variant', caseSensitive: false), '')
        .replaceAll(RegExp(r' -? ?Latest variant', caseSensitive: false), '')
        .trim();
    return name;
  }

  static Product empty() {
    return Product(
      id: '', itemName: '', brand: '', unit: '', description: '',
      itemImages: [], mrp: 0.0, salesPrice: 0.0, stock: 0,
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    List<String> images = _parseImages(json);
    String productId = json['_id']?.toString() ?? '';

    double parsedMrp = 0.0;
    if (json['mrp'] != null) parsedMrp = double.tryParse(json['mrp'].toString()) ?? 0.0;

    double parsedSalesPrice = 0.0;
    if (json['salesPrice'] != null) parsedSalesPrice = double.tryParse(json['salesPrice'].toString()) ?? 0.0;

    if (parsedMrp == 0.0 && parsedSalesPrice == 0.0) {
      parsedMrp = -1.0; parsedSalesPrice = -1.0;
    }

    String productBrand = json['brand']?.toString() ?? '';
    if (productBrand == 'null') productBrand = '';

    String productDescription = json['description']?.toString() ?? '';
    if (productDescription == 'null' || productDescription.isEmpty) {
      productDescription = json['barcode']?.toString() ?? '';
    }

    int stockQuantity = 0;
    if (json['currentStock'] != null) {
      stockQuantity = int.tryParse(json['currentStock'].toString()) ?? 0;
    } else if (json['stock'] != null) {
      stockQuantity = int.tryParse(json['stock'].toString()) ?? 0;
    } else if (json['quantity'] != null) {
      stockQuantity = int.tryParse(json['quantity'].toString()) ?? 0;
    }

    return Product(
      id: productId,
      itemName: json['itemName']?.toString() ?? json['name']?.toString() ?? '',
      brand: productBrand,
      unit: json['unit']?.toString() ?? 'piece',
      description: productDescription,
      itemImages: images,
      mrp: parsedMrp,
      salesPrice: parsedSalesPrice,
      stock: stockQuantity,
      // ✅ Map new fields
      itemGroup: json['itemGroup']?.toString(),
      parentItemId: json['parentItemId']?.toString(),
      variantName: json['variantName']?.toString(),
    );
  }

  static List<String> _parseImages(Map<String, dynamic> json) {
    final List<String> images = [];
    if (json['itemImages'] != null && json['itemImages'] is List) {
      for (final img in json['itemImages']) {
        if (img != null && img.toString().isNotEmpty && img.toString() != 'null') {
          images.add(img.toString());
        }
      }
    } else if (json['images'] != null && json['images'] is List) {
      for (final img in json['images']) {
        if (img != null && img.toString().isNotEmpty && img.toString() != 'null') {
          images.add(img.toString());
        }
      }
    }
    if (images.isEmpty && json['image'] != null && json['image'].toString().isNotEmpty && json['image'].toString() != 'null') {
      images.add(json['image'].toString());
    }
    return images;
  }

  double get discountPercentage {
    if (mrp <= 0 || salesPrice <= 0) return 0;
    return ((mrp - salesPrice) / mrp * 100);
  }

  bool get needsPriceFetch => mrp == -1.0 && salesPrice == -1.0;
  bool get isInStock => stock > 0;
  bool get isOutOfStock => stock <= 0;

  Product copyWith({
    String? id, String? itemName, String? brand, String? unit, String? description,
    List<String>? itemImages, double? mrp, double? salesPrice, int? stock,
    String? itemGroup, String? parentItemId, String? variantName, List<Product>? variants,
  }) {
    return Product(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      brand: brand ?? this.brand,
      unit: unit ?? this.unit,
      description: description ?? this.description,
      itemImages: itemImages ?? this.itemImages,
      mrp: mrp ?? this.mrp,
      salesPrice: salesPrice ?? this.salesPrice,
      stock: stock ?? this.stock,
      itemGroup: itemGroup ?? this.itemGroup,
      parentItemId: parentItemId ?? this.parentItemId,
      variantName: variantName ?? this.variantName,
      variants: variants ?? this.variants,
    );
  }
}