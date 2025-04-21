// lib/services/sentiment_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message_model.dart'; // adjust based on your file structure

class SentimentService {
  final String backendUrl = "http://<your-ip>:<port>/api/messages";

  Future<List<MessageModel>> fetchSentimentData(String userId) async {
    final response = await http.get(Uri.parse('$backendUrl/sentiment/$userId'));

    if (response.statusCode == 200) {
      final List<dynamic> jsonData = json.decode(response.body);
      return jsonData.map((data) => MessageModel.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load sentiment data');
    }
  }
}
