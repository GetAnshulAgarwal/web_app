class SubCategory {
  final String id;
  final String name;
  final String description;
  final String image;

  SubCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
  });

  factory SubCategory.fromJson(Map<String, dynamic> json) {
    return SubCategory(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
    );
  }

  @override
  String toString() {
    return 'SubCategory{id: "$id", name: "$name", description: "$description", image: "$image"}';
  }
}
