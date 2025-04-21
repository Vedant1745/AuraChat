import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'sentiment_dashboard.dart';

class MainNavigationScreen extends StatefulWidget {
  final String userId;

  const MainNavigationScreen({super.key, required this.userId});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const ChatScreen(), // Update this if ChatScreen also needs userId
      SentimentDashboard(userId: widget.userId),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_outline),
            label: 'Dashboard',
          ),
        ],
      ),
    );
  }
}
