// history_screen.dart
import 'package:flutter/material.dart';
import 'db_config.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Map<String, dynamic>>> _floodHistory;
  String _filter = "1d"; // default filter

  @override
  void initState() {
    super.initState();
    _floodHistory = DbConfig().getFloodLevelHistoryRaw(_filter);
  }

  void _onFilterChanged(String? newFilter) {
    if (newFilter == null) return;
    setState(() {
      _filter = newFilter;
      _floodHistory = DbConfig().getFloodLevelHistoryRaw(_filter);
    });
  }

  Color _getThreatColor(String level) {
    switch (level.toLowerCase()) {
      case "medium threat":
        return Colors.amber;
      case "high threat":
        return Colors.orange;
      case "very high threat":
        return Colors.red.shade900;
      default:
        return Colors.grey;
    }
  }

  IconData _getThreatIcon(String level) {
    switch (level.toLowerCase()) {
      case "medium threat":
        return Icons.error;
      case "high threat":
        return Icons.error;
      case "very high threat":
        return Icons.warning;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Flood Level History")),
      body: Column(
        children: [
          // filter dropdown
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                DropdownButton<String>(
                  value: _filter,
                  items: const [
                    DropdownMenuItem(value: "1d", child: Text("Last 1 Day")),
                    DropdownMenuItem(value: "1m", child: Text("Last 1 Month")),
                    DropdownMenuItem(value: "all", child: Text("All Time")),
                  ],
                  onChanged: _onFilterChanged,
                ),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _floodHistory,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No history available"));
                }

                final history = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final record = Map<String, dynamic>.from(history[index]);

                    final createdRaw = record['created_at'];
                    DateTime? createdAt;
                    if (createdRaw is DateTime) {
                      createdAt = createdRaw;
                    } else if (createdRaw is String && createdRaw.isNotEmpty) {
                      createdAt = DateTime.tryParse(createdRaw);
                    }
                    final formattedDate = createdAt != null
                        ? DateFormat("MMM d, yyyy • hh:mm a").format(createdAt)
                        : "Unknown date";

                    final metersRaw = record['meters'];
                    final String metersStr = metersRaw == null
                        ? "N/A"
                        : (metersRaw is num
                        ? metersRaw.toStringAsFixed(1)
                        : metersRaw.toString());

                    final userName = record['user']['user_name']?.toString() ?? "Unknown";


                    final dynamic alertRaw =
                        record['alert'] ?? record['Alerts'] ?? record['alerts'];

                    Map<String, dynamic>? alertMap;
                    if (alertRaw is Map) {
                      alertMap = Map<String, dynamic>.from(alertRaw);
                    } else if (alertRaw is List && alertRaw.isNotEmpty) {
                      final first = alertRaw.first;
                      if (first is Map) alertMap = Map<String, dynamic>.from(first);
                    }

                    final threatLevel = alertMap?['threat_level']?.toString() ?? "None";
                    final advisory = alertMap?['message_advisory']?.toString() ?? "";

                    final threatColor = _getThreatColor(threatLevel);
                    final threatIcon = _getThreatIcon(threatLevel);

                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // header row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.water_drop,
                                        color: Colors.blue, size: 28),
                                    const SizedBox(width: 10),
                                    Text(
                                      "$metersStr m",
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(threatIcon, color: threatColor),
                                    const SizedBox(width: 6),
                                    Text(
                                      threatLevel,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: threatColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // metadata
                            Text("User: $userName",
                                style: TextStyle(color: Colors.grey[700])),
                            Text(formattedDate,
                                style: TextStyle(color: Colors.grey[600])),

                            if (advisory.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.info,
                                        color: Colors.blue, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        advisory,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
