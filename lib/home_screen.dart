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
    final SupabaseClient supabase = Supabase.instance.client;
    supabase.auth.onAuthStateChange.listen((event) async{
      if (event.event == AuthChangeEvent.signedIn) {
        await FirebaseMessaging.instance.requestPermission();

        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          final userId = supabase.auth.currentUser!.id;
          await supabase.from('user').upsert({
            'id': userId,
            'fcm_token': fcmToken
              });
        }
      }
    });
  }

  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      SensorInputScreen(
          userName: widget.userName,
          userId: widget.userId
      ),
      const HistoryScreen(),
    ];

    return Scaffold(
      body: _pages[_selectedIndex],
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
