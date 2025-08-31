import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'db_config.dart';

class SensorInputScreen extends StatefulWidget {
  final String userName;
  final int userId;
  const SensorInputScreen({
    super.key,
    required this.userName,
    required this.userId
  });

  static const routeName = '/sensor_input'; // For named routing

  @override
  State<SensorInputScreen> createState() => _SensorInputScreenState();
}

class _SensorInputScreenState extends State<SensorInputScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  late TextEditingController _controller;

  bool isLoading = false;
  double _currentValue = 2.0; // slider + text field synced value

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _currentValue.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data sent successfully!")),
      );

      setState(() {
        _currentValue = 0.0;
        _controller.text = "0.0";
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
      final clamped = parsed.clamp(0, 4); // clamp between 0 and 4
      setState(() {
        _currentValue = clamped.toDouble();
        _controller.text = clamped.toStringAsFixed(1);
      });
    } else {
      _controller.text = _currentValue.toStringAsFixed(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true, // prevents overflow
      appBar: AppBar(
        title: const Text('Water Level Input'),
        centerTitle: true,
        elevation: 2,
      ),
      body: SingleChildScrollView( // allows scrolling when keyboard appears
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Set Current Water Level",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Value display
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                    child: Text("${_currentValue.toStringAsFixed(1)} m"),
                  ),

                  const SizedBox(height: 25),

                  // Slider and input side by side
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 220,
                        child: RotatedBox(
                          quarterTurns: -1,
                          child: Slider(
                            value: _currentValue,
                            min: 0,
                            max: 4,
                            divisions: 40, // allows 0.1 steps
                            label: _currentValue.toStringAsFixed(1),
                            onChanged: (double newValue) {
                              setState(() {
                                _currentValue = newValue;
                                _controller.text =
                                    newValue.toStringAsFixed(1);
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 30),
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
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            labelText: "Meters",
                          ),
                          onSubmitted: _updateFromText,
                          onChanged: (value) {
                            if (value.isEmpty) return;
                            final parsed = double.tryParse(value);
                            if (parsed != null && parsed >= 0 && parsed <= 4) {
                              setState(() {
                                _currentValue = parsed;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Send button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.send),
                    label: Text(isLoading ? 'Sending...' : 'Send Data'),
                    onPressed: isLoading ? null : _handleSendData,
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
