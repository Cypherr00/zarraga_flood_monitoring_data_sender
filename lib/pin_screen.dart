// pin_screen.dart
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

  @override
  void initState() {
    super.initState();
    _pinController.addListener(_onPinChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_pinFocusNode);
    });
  }

  Future<void> _onPinChanged() async {
    setState(() {
      _errorMessage = null;
    });

    if (_pinController.text.length == 4) {
      _verifyPin();
    }
  }

  Future<void> _verifyPin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _pinFocusNode.unfocus();

    try {
      final isValid = await DbConfig().verifyPin(
        widget.userName,
        _pinController.text.trim(),
      );

      if (isValid) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', widget.userName);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login successful")),
        );
        final userId = await DbConfig().getIdUsingUserName(widget.userName);

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
    } finally {
      setState(() => _isLoading = false);
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF74ABE2), Color(0xFF5563DE)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Card(
            elevation: 12,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline,
                      size: 60, color: Colors.blueAccent),
                  const SizedBox(height: 16),
                  Text(
                    "Hello, ${widget.userName}",
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Enter your 4-digit PIN to continue",
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // PIN input
                  SizedBox(
                    width: screenSize.width * 0.5,
                    child: TextField(
                      controller: _pinController,
                      focusNode: _pinFocusNode,
                      obscureText: true,
                      obscuringCharacter: "●",
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 4,
                      style: const TextStyle(fontSize: 28, letterSpacing: 24),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        counterText: "",
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.0),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.0),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _errorMessage!,
                        style:
                        const TextStyle(color: Colors.red, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Change User button
                  ElevatedButton(
                    onPressed: _changeUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14.0, horizontal: 32.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      "Change User",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
