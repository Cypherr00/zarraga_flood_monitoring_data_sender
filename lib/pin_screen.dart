import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db_config.dart';
import 'user_selection_screen.dart';
import 'home_screen.dart';

class PinScreen extends StatefulWidget {
  final String userName;
  const PinScreen({super.key, required this.userName});
  static const routeName = '/pin_screen';

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;

  final Color primaryBlue = const Color(0xFF0D47A1);
  final Color lightBlueBg = const Color(0xFFE3F2FD);
  final String appVersion = "v1.0.7";

  @override
  void initState() {
    super.initState();
    _pinController.addListener(_onPinChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_pinFocusNode);
    });
  }

  Future<void> _onPinChanged() async {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }

    if (_pinController.text.length == 4) {
      _verifyPin();
    }
  }

  Future<void> _verifyPin() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _pinFocusNode.unfocus();

    try {
      // 1. Verify PIN
      final isValid = await DbConfig().verifyPin(
        widget.userName,
        _pinController.text.trim(),
      );

      if (isValid) {
        // 2. Check if the user is active
        final isActive = await DbConfig().isUserActive(widget.userName);

        if (!isActive) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Account is inactive. Redirecting..."),
              backgroundColor: Colors.redAccent,
            ),
          );
          
          // Clear session and redirect
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('user_name');
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const UserSelectionScreen()),
          );
          return;
        }

        // 3. Login success logic
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', widget.userName);

        final userId = await DbConfig().getIdUsingUserName(widget.userName);

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              userName: widget.userName,
              userId: userId,
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = "Invalid PIN. Please try again.";
        });
        _pinController.clear();
        FocusScope.of(context).requestFocus(_pinFocusNode);
      }
    } catch (e) {
      setState(() {
        _errorMessage = "An error occurred. Try again.";
      });
      _pinController.clear();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_name');

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const UserSelectionScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _pinController.removeListener(_onPinChanged);
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: lightBlueBg,
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: Colors.blue.shade100, width: 1),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.lock_outline, size: 48, color: primaryBlue),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Welcome back,",
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                      Text(
                        widget.userName,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        "Enter your 4-digit PIN",
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: screenSize.width * 0.55,
                        child: TextField(
                          controller: _pinController,
                          focusNode: _pinFocusNode,
                          obscureText: true,
                          obscuringCharacter: "●",
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 4,
                          style: TextStyle(fontSize: 32, letterSpacing: 20, color: primaryBlue),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            counterText: "",
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16.0),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16.0),
                              borderSide: BorderSide(color: primaryBlue, width: 2.0),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 48,
                        child: Center(
                          child: _isLoading
                              ? const CircularProgressIndicator()
                              : _errorMessage != null
                              ? Text(
                            _errorMessage!,
                            style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      const Divider(height: 32),
                      TextButton.icon(
                        onPressed: _changeUser,
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: const Text("Not you? Switch User"),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: Text(
              appVersion,
              style: TextStyle(
                color: primaryBlue.withOpacity(0.5),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}