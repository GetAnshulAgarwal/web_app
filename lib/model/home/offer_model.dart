class OfferModel {
  final int id;
  final String title;
  final String subtitle;
  final String image;
  final int backgroundColor;
  final String validUntil;

  OfferModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.image,
    required this.backgroundColor,
    required this.validUntil,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    return OfferModel(
      id: json['id'],
      title: json['title'],
      subtitle: json['subtitle'],
      image: json['image'],
      backgroundColor: json['backgroundColor'],
      validUntil: json['validUntil'],
    );
  }
}
