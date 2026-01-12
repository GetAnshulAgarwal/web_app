// deck.dart
import 'package:eshop/model/home/product_model.dart';

class Deck {
  final String id;
  final String name;
  final String description;
  final String image;
  final List<Product> items; // Add this property

  // Add these for search functionality
  String? categoryName;
  String? subcategoryName;
  String? categoryId;
  String? subcategoryId;

  Deck({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    required this.items, // Add this
    this.categoryName,
    this.subcategoryName,
    this.categoryId,
    this.subcategoryId,
  });

  factory Deck.fromJson(Map<String, dynamic> json) {
    return Deck(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      items:
          (json['items'] as List<dynamic>?)
              ?.map((item) => Product.fromJson(item))
              .toList() ??
          [],
      categoryName: json['categoryName'],
      subcategoryName: json['subcategoryName'],
      categoryId: json['categoryId'],
      subcategoryId: json['subcategoryId'],
    );
  }
}
