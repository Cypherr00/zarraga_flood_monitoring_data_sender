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

                    // created_at may be String or DateTime
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

                    // meters formatting
                    final metersRaw = record['meters'];
                    final String metersStr = metersRaw == null
                        ? "N/A"
                        : (metersRaw is num
                        ? metersRaw.toStringAsFixed(1)
                        : metersRaw.toString());

                    final userId = record['user_id']?.toString() ?? "Unknown";

                    // ALERT extraction: handle multiple shapes:
                    //  - 'alert' : Map or null
                    //  - 'Alerts' : List (possibly empty)
                    //  - other variants
                    final dynamic alertRaw =
                        record['alert'] ?? record['Alerts'] ?? record['alerts'];

                    Map<String, dynamic>? alertMap;
                    if (alertRaw is Map) {
                      alertMap = Map<String, dynamic>.from(alertRaw);
                    } else if (alertRaw is List && alertRaw.isNotEmpty) {
                      // take first alert row (Supabase nested select may return list)
                      final first = alertRaw.first;
                      if (first is Map) alertMap = Map<String, dynamic>.from(first);
                    } else {
                      alertMap = null;
                    }

                    final threatLevel = alertMap?['threat_level']?.toString() ?? "None";
                    final advisory = alertMap?['message_advisory']?.toString() ?? "";

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // header
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.water_drop, color: Colors.blue, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "$metersStr meters",
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text("User: $userId"),
                                      Text(formattedDate),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // always show threat level (main ask)
                            Text("Threat: $threatLevel",
                                style: const TextStyle(fontSize: 14)),

                            // advisory only shown if present
                            if (advisory.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text("Advisory: $advisory", style: const TextStyle(fontSize: 14)),
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
