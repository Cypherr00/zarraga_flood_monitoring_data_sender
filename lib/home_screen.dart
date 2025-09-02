//home_screen.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'sensor_input_screen.dart';
import 'history_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class HomeScreen extends StatefulWidget {
  final String userName;
  final int userId;
  const HomeScreen({
    super.key,
    required this.userName,
    required this.userId
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    final supabase = Supabase.instance.client;

    // Upload initial token
    FirebaseMessaging.instance.getToken().then((token) async {
      if (token != null) {
        await supabase.from('user').upsert({
          'id': widget.userId,
          'fcm_token': token,
        });
      }
    });

    // Listen for refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await supabase.from('user').upsert({
        'id': widget.userId,
        'fcm_token': newToken,
      });
    });
  }


  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      SensorInputScreen(
          userName: widget.userName,
          userId: widget.userId
      ),
      const HistoryScreen(),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.sensors),
            label: "Sensor Input",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: "History",
          ),
        ],
      ),
    );
  }
}
