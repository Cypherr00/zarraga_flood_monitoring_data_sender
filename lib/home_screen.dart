import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sensor_input_screen.dart';
import 'history_screen.dart';

final FlutterLocalNotificationsPlugin _localNotifPlugin =
FlutterLocalNotificationsPlugin();

class HomeScreen extends StatefulWidget {
  final String userName;
  final int userId;
  const HomeScreen({
    super.key,
    required this.userName,
    required this.userId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _setupMessageListeners();
  }

  Future<void> _initNotifications() async {
    // Ask runtime permission (Android 13+)
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Subscribe to topic
      await FirebaseMessaging.instance.subscribeToTopic('alerts');
      print('Subscribed to topic: alerts');

      // Save token (optional)
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await Supabase.instance.client.from('user').upsert({
          'id': widget.userId,
          'fcm_token': token,
        });
        print('Saved FCM token: $token');
      }
    }
  }

  void _setupMessageListeners() {
    FirebaseMessaging.onMessage.listen((message) {
      print('Foreground message: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print('Tapped notification: ${message.data}');
    });
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final androidDetails = AndroidNotificationDetails(
      'alerts_channel',
      'Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );

    final notifDetails = NotificationDetails(android: androidDetails);

    await _localNotifPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      notifDetails,
      payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      SensorInputScreen(userName: widget.userName, userId: widget.userId),
      const HistoryScreen(),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.sensors), label: "Sensor Input"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
        ],
      ),
    );
  }
}
