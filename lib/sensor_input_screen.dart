// sensor_input_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db_config.dart';
import 'pin_screen.dart';

class SensorInputScreen extends StatefulWidget {
  final String userName;
  final int userId;

  const SensorInputScreen({
    super.key,
    required this.userName,
    required this.userId,
  });

  static const routeName = '/sensor_input';

  @override
  State<SensorInputScreen> createState() => _SensorInputScreenState();
}

class _SensorInputScreenState extends State<SensorInputScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  late TextEditingController _controller;

  bool isLoading = false;
  double _currentValue = 1.0;
  bool _isOverflow = false;

  Map<String, dynamic>? latest;
  RealtimeChannel? subscription;

  // Theme Colors
  final Color primaryBlue = const Color(0xFF0D47A1);
  final Color lightBlueBg = const Color(0xFFE3F2FD);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _currentValue.toStringAsFixed(1));
    _loadInitial();
    _setupSubscription();
  }

  Future<void> _loadInitial() async {
    final data = await DbConfig().fetchLatestWaterLevel();
    setState(() {
      latest = data;
    });
  }

  void _setupSubscription() {
    subscription = DbConfig().subscribeLatestWaterLevel((updated) {
      setState(() {
        latest = updated;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    if (subscription != null) {
      supabase.removeChannel(subscription!);
    }
    super.dispose();
  }

  void _toggleOverflow() {
    setState(() {
      _isOverflow = !_isOverflow;
      if (_isOverflow && _currentValue < 4.0) _currentValue = 4.0;
      if (!_isOverflow && _currentValue > 4.0) _currentValue = 1.0;
      _controller.text = _currentValue.toStringAsFixed(1);
    });
  }

  Future<void> _handleSendData() async {
    final input = _controller.text.trim();
    final double? meters = double.tryParse(input);

    if (meters == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid input.")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await DbConfig().sendData(
        userId: widget.userId,
        meters: meters,
        isOverflow: _isOverflow,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data sent successfully!")),
      );

      setState(() {
        _currentValue = 1.0;
        _controller.text = _currentValue.toStringAsFixed(1);
        _isOverflow = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _updateFromText(String text) {
    final parsed = double.tryParse(text);
    if (parsed != null) {
      double minValue = _isOverflow ? 4.0 : 0.0;
      double maxValue = _isOverflow ? 6.0 : 4.0;
      final clamped = parsed.clamp(minValue, maxValue);
      setState(() {
        _currentValue = clamped.toDouble();
        _controller.text = clamped.toStringAsFixed(1);
      });
    } else {
      _controller.text = _currentValue.toStringAsFixed(1);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Log Out"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: TextStyle(color: primaryBlue)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Log Out", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_name');
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => PinScreen(userName: widget.userName)),
            (route) => false,
      );
    }
  }

  Widget _buildCard({required Widget child, required List<Color> colors}) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Water Level Input'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: "Log Out",
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start, // Align to top, removing the huge gap
            children: [
              // --- INPUT CARD ---
              _buildCard(
                colors: [lightBlueBg, Colors.white],
                child: Column(
                  children: [
                    Text(
                      "Set Current Water Level",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryBlue),
                    ),
                    const SizedBox(height: 15),

                    // VERTICAL SLIDER SECTION
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Vertical Slider inside a RotatedBox
                        SizedBox(
                          height: 200,
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Slider(
                              value: _currentValue.clamp(
                                  _isOverflow ? 4.0 : 0.0,
                                  _isOverflow ? 6.0 : 4.0),
                              min: _isOverflow ? 4.0 : 0.0,
                              max: _isOverflow ? 6.0 : 4.0,
                              activeColor: _isOverflow ? Colors.redAccent : primaryBlue,
                              onChanged: (v) {
                                setState(() {
                                  _currentValue = v;
                                  _controller.text = _currentValue.toStringAsFixed(1);
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 30),
                        // Display Value and Text Input
                        Column(
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: _isOverflow ? Colors.redAccent : primaryBlue,
                              ),
                              child: Text("${_currentValue.toStringAsFixed(1)} m"),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: _controller,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  labelText: "Meters",
                                ),
                                onSubmitted: _updateFromText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isOverflow ? Colors.red.shade50 : Colors.blue.shade50,
                              foregroundColor: _isOverflow ? Colors.red : primaryBlue,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: Icon(_isOverflow ? Icons.warning : Icons.check_circle),
                            label: Text(_isOverflow ? "OVERFLOW" : "NORMAL"),
                            onPressed: _toggleOverflow,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.send, color: Colors.white),
                      label: const Text("SEND DATA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: primaryBlue,
                      ),
                      onPressed: isLoading ? null : _handleSendData,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20), // Controlled margin between cards

              // --- LATEST READING CARD ---
              _buildCard(
                colors: [primaryBlue, const Color(0xFF1565C0)],
                child: latest == null
                    ? const Center(child: Text("No data yet", style: TextStyle(color: Colors.white70)))
                    : Column(
                  children: [
                    const Text(
                      "LATEST READING",
                      style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "${latest!['meters']} m",
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Divider(color: Colors.white24, height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("By: ${latest!['user']['user_name']}", style: const TextStyle(color: Colors.white, fontSize: 12)),
                        Text("${latest!['created_at']}", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}