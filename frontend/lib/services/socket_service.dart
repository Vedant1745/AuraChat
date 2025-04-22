import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  late IO.Socket socket;
  Function? onUserOnline;
  Function? onUserOffline;

  void connect(String token) {
    socket = IO.io("http://192.168.43.127:5000", <String, dynamic>{
      'transports': ['websocket'],
      'auth': {'token': token},
      'autoConnect': false,
    });

    // Connection Events
    socket.onConnect((_) => print("✅ Connected to Socket"));
    socket.onDisconnect((_) => print("⚠️ Disconnected from Socket"));
    socket.onConnectError((err) => print("❌ Connect Error: $err"));
    socket.onError((err) => print("❗ Socket Error: $err"));

    // Online/Offline events
    socket.on('userOnline', (userId) {
      onUserOnline?.call(userId);
    });

    socket.on('userOffline', (userId) {
      onUserOffline?.call(userId);
    });

    // Connect manually
    socket.connect();
  }

  void joinRoom(String conversationId) {
    socket.emit("join", conversationId);
    print("🔗 Joined room: $conversationId");
  }

  void sendMessage(String conversationId, String text) {
    socket.emit("message", {
      "conversationId": conversationId,
      "text": text,
    });
    print("📤 Message sent to $conversationId: $text");
  }

  void deleteMessage(String messageId) {
    socket.emit("delete_message", {"messageId": messageId});
    print("🗑️ Message deleted: $messageId");
  }

  void onMessage(void Function(dynamic) handler) {
    socket.on("message", handler);
  }

  void onDeleteMessage(void Function(dynamic) handler) {
    socket.on("delete_message", handler);
  }

  void disconnect() {
    socket.disconnect();
    print("🔌 Socket disconnected manually.");
  }
}
