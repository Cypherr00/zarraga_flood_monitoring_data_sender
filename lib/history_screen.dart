// history_screen.dart
import 'package:flutter/material.dart';
import 'db_config.dart';
import 'models/flood_level.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<FloodLevel>> _floodHistory;
  String _filter = "1d"; // default filter = last day

  @override
  void initState() {
    super.initState();
    _floodHistory = DbConfig().getFloodLevelHistory(_filter);
  }

  void _onFilterChanged(String? newFilter) {
    if (newFilter == null) return;
    setState(() {
      _filter = newFilter;
      _floodHistory = DbConfig().getFloodLevelHistory(_filter);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Flood Level History")),
      body: Column(
        children: [
          // filter bar
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
            child: FutureBuilder<List<FloodLevel>>(
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
                    final record = history[index];
                    final formattedDate =
                    DateFormat("MMM d, yyyy • hh:mm a").format(record.createdAt);

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.water_drop, color: Colors.blue, size: 30),
                        title: Text(
                          "${record.meters} meters",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text("User: ${record.userId}\n$formattedDate"),
                        isThreeLine: true,
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
