class FAQItem {
  final String question;
  final String answer;
  final String category;
  final int id;

  FAQItem({
    required this.question,
    required this.answer,
    required this.category,
    required this.id,
  });

  factory FAQItem.fromJson(Map<String, dynamic> json) {
    return FAQItem(
      id: json['id'],
      question: json['question'],
      answer: json['answer'],
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'answer': answer,
      'category': category,
    };
  }
}
