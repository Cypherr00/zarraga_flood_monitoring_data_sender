import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sensor_input_screen.dart';
import 'history_screen.dart';

final FlutterLocalNotificationsPlugin _localNotifPlugin = FlutterLocalNotificationsPlugin();

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
    _initializeNotificationSystem();
  }

  /// Orchestrates all notification setup
  Future<void> _initializeNotificationSystem() async {
    await _setupLocalNotifications();
    await _requestPermissionsAndSyncToken();
    _setupMessageListeners();
    _handleInitialMessage();
  }

  /// Required for Android 8.0+ to actually display the notification
  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _localNotifPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle tapping local notification
        if (details.payload != null) {
          debugPrint("Notification payload: ${details.payload}");
          _navigateToHistory();
        }
      },
    );

    // Create the high importance channel for Android
    const androidChannel = AndroidNotificationChannel(
      'alerts_channel',
      'Alerts',
      description: 'Critical water level alerts',
      importance: Importance.max,
    );

    await _localNotifPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> _requestPermissionsAndSyncToken() async {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // It is safer to subscribe to a user-specific topic or handle this via token on backend
      await messaging.subscribeToTopic('alerts');

      final token = await messaging.getToken();
      if (token != null) {
        try {
          // IMPORTANT: Ensure RLS is enabled in Supabase for this table
          await Supabase.instance.client.from('user').upsert({
            'id': widget.userId,
            'fcm_token': token,
          });
        } catch (e) {
          debugPrint("Error syncing FCM token: $e");
        }
      }
    }
  }

  void _setupMessageListeners() {
    // Foreground listener
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
    });

    // Background (but not terminated) listener
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _navigateToHistory();
    });
  }

  /// Handles the case where the app is opened from a terminated state via notification
  Future<void> _handleInitialMessage() async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _navigateToHistory();
    }
  }

  void _navigateToHistory() {
    setState(() {
      _selectedIndex = 1; // Switch to History Tab
    });
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'alerts_channel',
          'Alerts',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Using an IndexedStack prevents the SensorInputScreen from
    // re-initializing every time you switch tabs.
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          SensorInputScreen(userName: widget.userName, userId: widget.userId),
          const HistoryScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue.shade900,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.sensors), label: "Input"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
        ],
      ),
    );
  }
}