import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../models/user_model.dart';
import '../models/message_model.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import 'sentiment_dashboard.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  int _selectedIndex = 0;
  List<UserModel> users = [];
  List<String> onlineUsers = [];
  UserModel? selectedUser;
  String? conversationId;
  List<MessageModel> messages = [];
  final messageController = TextEditingController();
  final socketService = SocketService();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    initChat();
  }

  void initChat() async {
    socketService.connect(ApiService.token!);

    final fetchedUsers = await ApiService.fetchUsers();
    setState(() {
      users = fetchedUsers;
      isLoading = false;
    });

    socketService.onMessage((data) {
      final msg = MessageModel.fromJson(data);
      if (msg.conversationId == conversationId) {
        setState(() => messages.add(msg));
      }
    });

    socketService.socket.on('messageDeleted', (data) {
      final deletedId = data['messageId'];
      setState(() {
        messages.removeWhere((msg) => msg.id == deletedId);
      });
    });

    socketService.onUserOnline = (userId) {
      setState(() {
        if (!onlineUsers.contains(userId)) {
          onlineUsers.add(userId);
        }
      });
    };

    socketService.onUserOffline = (userId) {
      setState(() {
        onlineUsers.remove(userId);
      });
    };
  }

  void startConversation(UserModel user) async {
    final convoId = await ApiService.createOrGetConversation(user.id);
    final convoMessages = await ApiService.fetchMessages(convoId);
    socketService.joinRoom(convoId);

    setState(() {
      selectedUser = user;
      conversationId = convoId;
      messages = convoMessages;
    });
  }

  void sendMessage() {
    if (messageController.text.trim().isEmpty || conversationId == null) return;

    socketService.sendMessage(conversationId!, messageController.text.trim());
    messageController.clear();
  }

  void deleteMessage(String messageId) async {
    try {
      await ApiService.deleteMessage(messageId);
      setState(() {
        messages.removeWhere((msg) => msg.id == messageId);
      });
    } catch (e) {
      print('Failed to delete message: $e');
    }
  }

  void showDeleteDialog(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              deleteMessage(messageId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void logout() {
    ApiService.token = null;
    socketService.disconnect();
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  String getCurrentUserId() {
    if (ApiService.token == null) return '';
    Map<String, dynamic> decodedToken = JwtDecoder.decode(ApiService.token!);
    return decodedToken['id'] ?? '';
  }

  Color getSentimentColor(String sentiment, bool isMe) {
    if (isMe) return Colors.blue;
    switch (sentiment.toLowerCase()) {
      case 'positive':
        return Colors.green.shade200;
      case 'negative':
        return Colors.red.shade200;
      case 'neutral':
      default:
        return Colors.grey.shade300;
    }
  }

  Icon? getSentimentIcon(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'positive':
        return const Icon(Icons.sentiment_satisfied_alt,
            size: 16, color: Colors.green);
      case 'negative':
        return const Icon(Icons.sentiment_dissatisfied,
            size: 16, color: Colors.red);
      case 'neutral':
      default:
        return const Icon(Icons.sentiment_neutral,
            size: 16, color: Colors.grey);
    }
  }

  Widget buildChatArea() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final isMe = msg.senderId != selectedUser!.id;
              final color = getSentimentColor(msg.sentiment ?? 'neutral', isMe);
              final sentimentIcon =
                  getSentimentIcon(msg.sentiment ?? 'neutral');

              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: GestureDetector(
                  onLongPress: isMe ? () => showDeleteDialog(msg.id) : null,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            sentimentIcon!,
                            const SizedBox(width: 4),
                            Text(
                              msg.sentiment ?? 'Neutral',
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: messageController,
                onSubmitted: (_) => sendMessage(),
                textInputAction: TextInputAction.send,
                decoration: const InputDecoration(
                  hintText: "Type a message...",
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
            IconButton(onPressed: sendMessage, icon: const Icon(Icons.send)),
          ],
        ),
      ],
    );
  }

  Widget buildUserList() {
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (_, index) {
        final user = users[index];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(user.name),
          subtitle: Row(
            children: [
              Text(user.email),
              SizedBox(width: 8),
              Icon(
                onlineUsers.contains(user.id)
                    ? Icons.circle
                    : Icons.circle_outlined,
                color:
                    onlineUsers.contains(user.id) ? Colors.green : Colors.red,
              ),
              Text(onlineUsers.contains(user.id) ? ' Online' : ' Offline'),
            ],
          ),
          onTap: () => startConversation(user),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget currentBody;

    if (_selectedIndex == 0) {
      currentBody = isLoading
          ? const Center(child: CircularProgressIndicator())
          : selectedUser == null
              ? buildUserList()
              : buildChatArea();
    } else {
      currentBody = SentimentDashboard(userId: getCurrentUserId());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0
            ? (selectedUser != null
                ? selectedUser!.name
                : "Select a user to chat")
            : "Sentiment Dashboard"),
        leading: _selectedIndex == 0 && selectedUser != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    selectedUser = null;
                    conversationId = null;
                    messages = [];
                  });
                },
              )
            : null,
        actions: [
          if (_selectedIndex == 0 && selectedUser != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  selectedUser = null;
                  conversationId = null;
                  messages = [];
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: logout,
          ),
        ],
      ),
      body: currentBody,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Sentiment',
          ),
        ],
      ),
    );
  }
}
