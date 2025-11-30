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
    _checkStoredUser();
  }

  Future<void> _checkStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUser = prefs.getString('user_name');

    if (storedUser == null) {
      if (mounted) _goToUserSelection();
      return;
    }

    try {
      // Check if user still exists in Supabase
      final response = await Supabase.instance.client
          .from('user')
          .select('id, user_name')
          .eq('user_name', storedUser)
          .maybeSingle();

      if (!mounted) return;

      if (response != null) {
        _goToPinScreen(storedUser);
      } else {
        await prefs.remove('user_name');
        _goToUserSelection();
      }
    } catch (e) {
      await prefs.remove('user_name');
      if (mounted) _goToUserSelection();
    }
  }

  void _goToPinScreen(String userName) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PinScreen(userName: userName),
      ),
    );
  }

  void _goToUserSelection() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const UserSelectionScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'FloodTwin',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
