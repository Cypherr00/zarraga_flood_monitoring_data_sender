// history_screen.dart
import 'dart:async'; // Needed for the Timer
import 'package:flutter/material.dart';
import 'db_config.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Map<String, dynamic>>> _floodHistory;
  String _filter = "1d";
  Timer? _refreshTimer; // The auto-refresh timer

  // Brand Colors
  final Color primaryBlue = const Color(0xFF0D47A1);
  final Color lightBlueBg = const Color(0xFFE3F2FD);

  @override
  void initState() {
    super.initState();
    _loadData();

    // Auto-refresh the history every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _loadData();
    });
  }

  @override
  void dispose() {
    // Always cancel timers when leaving the screen to save battery
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _floodHistory = DbConfig().getFloodLevelHistoryRaw(_filter);
    });
  }

  void _onFilterChanged(String? newFilter) {
    if (newFilter == null) return;
    setState(() {
      _filter = newFilter;
      _loadData();
    });
  }

  Color _getThreatColor(String level) {
    String l = level.toLowerCase();
    if (l.contains("very high")) return Colors.red.shade900;
    if (l.contains("high")) return Colors.orange.shade800;
    if (l.contains("moderate")) return Colors.amber.shade700;
    return primaryBlue; // Default / Low Threat
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(10.0), // Adds breathing room around the logo
          child: Image.asset('assets/logo.png', fit: BoxFit.contain),
        ),
        title: const Text("Flood Level History"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Styled Filter Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Timeline Range",
                  style: TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: primaryBlue.withOpacity(0.3), width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: DropdownButton<String>(
                    value: _filter,
                    underline: const SizedBox(),
                    icon: Icon(Icons.keyboard_arrow_down, color: primaryBlue),
                    style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w600, fontSize: 14),
                    items: const [
                      DropdownMenuItem(value: "1d", child: Text("Last 24 Hours")),
                      DropdownMenuItem(value: "1m", child: Text("Last Month")),
                      DropdownMenuItem(value: "all", child: Text("All History")),
                    ],
                    onChanged: _onFilterChanged,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 24, thickness: 1),

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _floodHistory,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  // Only show loading spinner on first load, not during auto-refresh
                  return const Center(child: CircularProgressIndicator());
                }

                final history = snapshot.data ?? [];
                if (history.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off, size: 64, color: Colors.blue.shade100),
                        const SizedBox(height: 16),
                        const Text("No history records found", style: TextStyle(color: Colors.black54)),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _loadData(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final record = history[index];

                      // Data Handling
                      final meters = (record['meters'] as num?)?.toStringAsFixed(1) ?? "0.0";
                      final user = record['user']?['user_name'] ?? "Unknown";

                      // Robust alert parsing logic
                      final dynamic alertRaw = record['alert'] ?? record['Alerts'] ?? record['alerts'];
                      Map<String, dynamic>? alertMap;

                      if (alertRaw is Map) {
                        alertMap = Map<String, dynamic>.from(alertRaw);
                      } else if (alertRaw is List && alertRaw.isNotEmpty) {
                        final first = alertRaw.first;
                        if (first is Map) alertMap = Map<String, dynamic>.from(first);
                      }

                      final threat = alertMap?['threat_level']?.toString() ?? "Normal";
                      final advisory = alertMap?['message_advisory']?.toString() ?? "";

                      final threatColor = _getThreatColor(threat);

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.blue.shade50),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ExpansionTile(
                          shape: const RoundedRectangleBorder(side: BorderSide.none),
                          leading: CircleAvatar(
                            // Locked to primaryBlue to avoid the "period" look
                            backgroundColor: primaryBlue.withOpacity(0.1),
                            child: Icon(Icons.water_drop, color: primaryBlue),
                          ),
                          title: Text("$meters m",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryBlue)),
                          subtitle: Text("By: $user", style: const TextStyle(fontSize: 12)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Text stays colored based on threat level
                              Text(threat,
                                  style: TextStyle(color: threatColor, fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                record['created_at'].toString().split('T')[0], // Extract YYYY-MM-DD
                                style: const TextStyle(fontSize: 11, color: Colors.black45),
                              ),
                            ],
                          ),
                          children: [
                            if (advisory.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: lightBlueBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text("Advisory: $advisory",
                                      style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.black87)),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}