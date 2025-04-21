class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final String? sentiment; // ✅ Add this
  final DateTime timestamp;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    this.sentiment,
    required this.timestamp,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['_id'],
      conversationId: json['conversationId'],
      senderId: json['senderId'],
      text: json['text'],
      sentiment: json['sentiment'], // ✅ parse sentiment
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
