// splash_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'pin_screen.dart';
import 'user_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Matching the theme established in the other screens
  final Color primaryBlue = const Color(0xFF0D47A1);

  @override
  void initState() {
    super.initState();

    // Setup a smooth fade-in animation for the logo
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    // Give the animation time to play before redirecting
    Future.delayed(const Duration(milliseconds: 1500), () {
      _checkStoredUser();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUser = prefs.getString('user_name');

    if (storedUser == null) {
      if (mounted) _goToUserSelection();
      return;
    }

    try {
      // Check if user still exists and is active in Supabase
      final response = await Supabase.instance.client
          .from('user')
          .select('id, user_name, is_active')
          .eq('user_name', storedUser)
          .maybeSingle();

      if (!mounted) return;

      if (response != null && response['is_active'] == true) {
        _goToPinScreen(storedUser);
      } else {
        // User doesn't exist or is inactive
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
      backgroundColor: primaryBlue,
      body: Stack(
        children: [
          // Center Logo, App Name, and Loading Indicator
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo Container using custom asset
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 90,
                      height: 90,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // App Title
                  const Text(
                    'FloodTwin',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'Water Level Monitoring',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  // --- MOVED LOADING INDICATOR HERE ---
                  const SizedBox(height: 40), // Spacing between text and ripple
                  SpinKitRipple(
                    color: Colors.white.withOpacity(0.8),
                    size: 50.0,
                    borderWidth: 3.0,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}