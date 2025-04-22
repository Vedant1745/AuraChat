import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/message_model.dart';

class ApiService {
  static const baseUrl =
      "http://192.168.43.127:5000"; // replace with your IP for mobile testing
  static String? token;

  static Future<bool> signup(String username, String email, String password,
      String? profileImagePath) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/signup'));
    request.fields['username'] = username;
    request.fields['email'] = email;
    request.fields['password'] = password;

    if (profileImagePath != null) {
      request.files.add(
          await http.MultipartFile.fromPath('profileImage', profileImagePath));
    }

    var response = await request.send();
    if (response.statusCode == 200) {
      var body = json.decode(await response.stream.bytesToString());
      token = body['token'];
      return true;
    }
    return false;
  }

  static Future<bool> login(String email, String password) async {
    var res = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"email": email, "password": password}),
    );
    if (res.statusCode == 200) {
      var body = json.decode(res.body);
      token = body['token'];
      return true;
    }
    return false;
  }

  static Future<List<UserModel>> fetchUsers() async {
    var res = await http
        .get(Uri.parse('$baseUrl/users'), headers: {"auth-token": token!});
    List data = json.decode(res.body);
    return data.map((e) => UserModel.fromJson(e)).toList();
  }

  static Future<List<MessageModel>> fetchMessages(String conversationId) async {
    var res = await http.get(Uri.parse('$baseUrl/messages/$conversationId'),
        headers: {"auth-token": token!});
    List data = json.decode(res.body);
    return data.map((e) => MessageModel.fromJson(e)).toList();
  }

  static Future<String> createOrGetConversation(String participantId) async {
    var res = await http.post(
      Uri.parse('$baseUrl/conversations'),
      headers: {
        "Content-Type": "application/json",
        "auth-token": token!,
      },
      body: json.encode({"participantId": participantId}),
    );
    var body = json.decode(res.body);
    return body['_id'];
  }

  static Future<void> deleteMessage(String messageId) async {
    await http.delete(
      Uri.parse('$baseUrl/messages/$messageId'),
      headers: {"auth-token": token!},
    );
  }
}
