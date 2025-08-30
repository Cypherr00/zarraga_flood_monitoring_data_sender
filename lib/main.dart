// main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'history_screen.dart';
import 'splash_screen.dart';
import 'pin_screen.dart';
import 'sensor_input_screen.dart';
import 'user_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://koqyhknkbtaddcdvltwl.supabase.co',
    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtvcXloa25rYnRhZGRjZHZsdHdsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQxNzU1MDcsImV4cCI6MjA1OTc1MTUwN30.bJuzz1W-p1oAz9FAa8CTvJgKUSmIIC3D6plcUlM5XIo',
  );

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
      // Start on SplashScreen
      home: const SplashScreen(),

      // Routes for navigation
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
