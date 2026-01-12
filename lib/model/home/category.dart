class Category {
  final String id;
  final String name;
  final String description;
  final String image;
  final String? masterImage;

  Category({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    this.masterImage,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      masterImage: json['masterImage']?.toString(),
    );
  }

  @override
  String toString() {
    return 'Category{id: "$id", name: "$name"}';
  }
}
