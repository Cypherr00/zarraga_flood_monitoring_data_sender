// main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'splash_screen.dart';
import 'pin_screen.dart';
import 'user_selection_screen.dart';
import 'firebase_options.dart';

// Global local notifications instance
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// Background FCM handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register background FCM handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Init Supabase
  await Supabase.initialize(
    url: 'https://koqyhknkbtaddcdvltwl.supabase.co',
    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtvcXloa25rYnRhZGRjZHZsdHdsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQxNzU1MDcsImV4cCI6MjA1OTc1MTUwN30.bJuzz1W-p1oAz9FAa8CTvJgKUSmIIC3D6plcUlM5XIo',
  );

  // Init local notifications
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flood Monitoring System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == PinScreen.routeName) {
          final userName = settings.arguments as String;
          return MaterialPageRoute(
            builder: (_) => PinScreen(userName: userName),
          );
        } else if (settings.name == UserSelectionScreen.routeName) {
          return MaterialPageRoute(
            builder: (_) => const UserSelectionScreen(),
          );
        }
        return null;
      },
    );
  }
}
