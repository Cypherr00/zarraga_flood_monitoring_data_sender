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
  double _currentValue = 2.0;
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
      if (_isOverflow) {
        if (_currentValue < 4.0) {
          _currentValue = 4.0;
          _controller.text = _currentValue.toStringAsFixed(1);
        }
      } else {
        if (_currentValue > 4.0) {
          _currentValue = 4.0;
          _controller.text = _currentValue.toStringAsFixed(1);
        }
      }
    });
  }

  Future<void> _handleSendData() async {
    if (!mounted) return;

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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data sent successfully!")),
      );

      setState(() {
        _currentValue = 0.0;
        _controller.text = "0.0";
        _isOverflow = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
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
      builder: (ctx) {
        return AlertDialog(
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
        );
      },
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Water Level Input'),
        centerTitle: true,
        elevation: 2,
        actions: [
          IconButton(
            tooltip: "Log Out",
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: 360, // lock width
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Input card
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Set Current Water Level",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                          child: Text("${_currentValue.toStringAsFixed(1)} m"),
                        ),
                        const SizedBox(height: 8),
                        IconButton(
                          onPressed: _toggleOverflow,
                          iconSize: 36,
                          icon: Icon(
                            Icons.warning,
                            color: _isOverflow ? Colors.red : Colors.grey,
                          ),
                          tooltip: 'Overflow / Measurement Exceeded',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 180,
                              child: RotatedBox(
                                quarterTurns: -1,
                                child: Slider(
                                  value: _currentValue.clamp(
                                    _isOverflow ? 4.0 : 0.0,
                                    _isOverflow ? 6.0 : 4.0,
                                  ),
                                  min: _isOverflow ? 4.0 : 0.0,
                                  max: _isOverflow ? 6.0 : 4.0,
                                  divisions: null,
                                  label: _currentValue.toStringAsFixed(1),
                                  onChanged: (double newValue) {
                                    setState(() {
                                      _currentValue = _isOverflow && newValue < 4.0 ? 4.0 : newValue;
                                      _controller.text = _currentValue.toStringAsFixed(1);
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            SizedBox(
                              width: 100,
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
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.send),
                          label: Text(isLoading ? 'Sending...' : 'Send Data'),
                          onPressed: isLoading ? null : _handleSendData,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Latest water level card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: latest == null
                          ? const Text(
                        'No water level data yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      )
                          : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Latest Water Level',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${latest!['meters']} meters',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Submitted by: ${latest!['user']['user_name']}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'At: ${latest!['created_at']}',
                            style: const TextStyle(color: Colors.black45, fontSize: 12),
                          ),
                        ],
                      ),
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
