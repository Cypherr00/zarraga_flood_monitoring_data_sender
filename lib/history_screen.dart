// history_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_config.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Map<String, dynamic>>> _floodHistory;
  String _filter = "1d";
  Timer? _refreshTimer;

  final Color primaryBlue = const Color(0xFF0D47A1);
  final Color lightBlueBg = const Color(0xFFE3F2FD);

  @override
  void initState() {
    super.initState();
    _loadData();

    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _loadData();
    });
  }

  @override
  void dispose() {
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

  Color _getThreatColor(double meters) {
    if (meters >= 5.0) return const Color(0xFF4A0000); // Emergency Overflow (Maroon)
    if (meters >= 4.1) return const Color(0xFFC62828); // Alert Level 3 (Red)
    if (meters >= 4.0) return const Color(0xFFEF6C00); // Alert Level 2 (Orange)
    if (meters >= 3.0) return const Color(0xFFF9A825); // Alert Level 1 (Amber)
    return const Color(0xFF2E7D32);                   // Normal Condition (Green)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Image.asset('assets/logo.png', fit: BoxFit.contain),
        ),
        title: const Text("Flood Level History"),
        centerTitle: true,
      ),
      body: Column(
        children: [
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
                  return const Center(child: CircularProgressIndicator());
                }

                final history = snapshot.data ?? [];

                // --- REFRESHABLE EMPTY STATE FIX ---
                if (history.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async => _loadData(),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(), // Forces scrolling even if empty
                      slivers: [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_toggle_off, size: 64, color: Colors.blue.shade100),
                              const SizedBox(height: 16),
                              const Text("No history records found", style: TextStyle(color: Colors.black54)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // --- EXISTING LIST VIEW ---
                return RefreshIndicator(
                  onRefresh: () async => _loadData(),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(), // Good practice to include here too
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final record = history[index];

                      final double metersNum = (double.tryParse(record['meters'].toString()) ?? 0.0);
                      final String metersDisplay = metersNum.toStringAsFixed(2);

                      final user = record['user']?['user_name'] ?? "Unknown";

                      final DateTime rawDate = DateTime.parse(record['created_at'].toString()).toLocal();
                      final String formattedDate = DateFormat('MMM dd, yyyy').format(rawDate);
                      final String formattedTime = DateFormat('hh:mm a').format(rawDate);

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

                      final threatColor = _getThreatColor(metersNum);

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.blue.shade50),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: const RoundedRectangleBorder(side: BorderSide.none),
                          leading: CircleAvatar(
                            backgroundColor: primaryBlue.withOpacity(0.1),
                            child: Icon(Icons.water_drop, color: threatColor),
                          ),
                          title: Text("$metersDisplay m",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryBlue)),
                          subtitle: Text("By: $user", style: const TextStyle(fontSize: 12)),
                          trailing: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 190),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  threat,
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: threatColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formattedDate,
                                  style: const TextStyle(fontSize: 10, color: Colors.black45),
                                ),
                                Text(
                                  formattedTime,
                                  style: const TextStyle(fontSize: 10, color: Colors.black45, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
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