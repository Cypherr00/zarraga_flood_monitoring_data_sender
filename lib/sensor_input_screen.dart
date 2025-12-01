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
  double _currentValue = 1.0; // Default 1m
  bool _isOverflow = false;

  Map<String, dynamic>? latest; // Latest water level
  RealtimeChannel? subscription;

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
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Log Out"),
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
    final theme = Theme.of(context);
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
          reverse: true,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: screenHeight - MediaQuery.of(context).padding.top),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Input Card
                _buildCard(
                  colors: [Colors.blue.shade100, Colors.blue.shade50],
                  child: Column(
                    children: [
                      const Text(
                        "Set Current Water Level",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                            )
                          ],
                        ),
                        child: Text("${_currentValue.toStringAsFixed(1)} m"),
                      ),
                      const SizedBox(height: 8),
                      IconButton(
                        onPressed: _toggleOverflow,
                        iconSize: 36,
                        icon: Icon(
                          Icons.warning,
                          color: _isOverflow ? Colors.red : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: screenHeight * 0.25, // 25% of screen height
                            child: RotatedBox(
                              quarterTurns: -1,
                              child: Slider(
                                value: _currentValue.clamp(
                                    _isOverflow ? 4.0 : 0.0,
                                    _isOverflow ? 6.0 : 4.0),
                                min: _isOverflow ? 4.0 : 0.0,
                                max: _isOverflow ? 6.0 : 4.0,
                                divisions: null,
                                label: _currentValue.toStringAsFixed(1),
                                onChanged: (v) {
                                  setState(() {
                                    _currentValue = _isOverflow && v < 4.0 ? 4.0 : v;
                                    _controller.text = _currentValue.toStringAsFixed(1);
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: _controller,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 20),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                labelText: "Meters",
                              ),
                              onSubmitted: _updateFromText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.send, color: Colors.white),
                        label: const Text("Send Data", style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, screenHeight * 0.06), // 6% of screen height
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          backgroundColor: theme.primaryColor,
                        ),
                        onPressed: isLoading ? null : _handleSendData,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Latest Water Level Card
                _buildCard(
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                  child: SizedBox(
                    height: screenHeight * 0.18, // 18% of screen height
                    child: latest == null
                        ? const Center(
                      child: Text(
                        "No water level data yet",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Center(
                          child: Text(
                            "Latest Water Level",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            "${latest!['meters']} m",
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            "Submitted by: ${latest!['user']['user_name']}",
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2),
                          child: Text(
                            "At: ${latest!['created_at']}",
                            style: const TextStyle(color: Colors.black45, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
