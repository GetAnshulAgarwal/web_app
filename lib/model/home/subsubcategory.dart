class SubSubCategory {
  final String id;
  final String name;
  final String image;
  final String description;

  SubSubCategory({
    required this.id,
    required this.name,
    required this.image,
    required this.description,
  });

  factory SubSubCategory.fromJson(Map<String, dynamic> json) {
    return SubSubCategory(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }

  @override
  String toString() {
    return 'SubSubCategory{id: $id, name: $name, image: $image, description: $description}';
  }
}