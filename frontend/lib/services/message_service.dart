import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message_model.dart';

class MessageService {
  final String baseUrl =
      'http://0.0.0.0:5000'; // 👈 Use your actual local IP

  Future<List<MessageModel>> getMessagesByUser(
      String userId, String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/messages/user/$userId'), // 👈 Updated path
      headers: {
        'Content-Type': 'application/json',
        'auth-token': token, // 👈 Make sure to pass the correct token
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonData = json.decode(response.body);
      return jsonData.map((e) => MessageModel.fromJson(e)).toList();
    } else {
      print("❌ Status Code: ${response.statusCode}");
      print("❌ Response Body: ${response.body}");
      throw Exception('Failed to load messages');
    }
  }
}
