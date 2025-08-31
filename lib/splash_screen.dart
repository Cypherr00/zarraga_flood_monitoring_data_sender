// splash_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pin_screen.dart';
import 'user_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUser = prefs.getString('user_name');

    // Small delay for splash experience
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    if (storedUser == null) {
      // No saved user → go to selection
      _goToUserSelection();
      return;
    }

    try {
      // Check Supabase if this stored user still exists
      final response = await Supabase.instance.client
          .from('user')
          .select('user_name')
          .eq('user_name', storedUser)
          .maybeSingle();

      int idResponse = (await Supabase.instance.client
          .from('user')
          .select('id')
          .eq('user_name', storedUser)
          .single()) as int;

      if (!mounted) return;

      if (response != null) {
        // User exists → go to PinScreen
        _goToPinScreen(storedUser);
      } else {
        // Invalid stored user → clear and go to selection
        await prefs.remove('user_name');
        _goToUserSelection();
      }
    } catch (e) {
      // In case Supabase fails → fallback to user selection
      await prefs.remove('user_name');
      if (mounted) _goToUserSelection();
    }
  }

  void _goToPinScreen(String userName) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PinScreen(userName: userName),
      ),
    );
  }

  void _goToUserSelection() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const UserSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Flood Monitoring System',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
