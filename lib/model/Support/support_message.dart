class SupportMessage {
  final String id;
  final String ticketId;
  final String sender;
  final String body;
  final bool isFromSupport;
  final List<String> readBy;
  final DateTime createdAt;

  SupportMessage({
    required this.id,
    required this.ticketId,
    required this.sender,
    required this.body,
    required this.isFromSupport,
    required this.readBy,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['_id'],
      ticketId: json['conversation'],
      sender: json['sender'],
      body: json['body'],
      isFromSupport: json['isFromSupport'] ?? false,
      readBy: List<String>.from(json['readBy'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'conversation': ticketId,
      'sender': sender,
      'body': body,
      'isFromSupport': isFromSupport,
      'readBy': readBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
