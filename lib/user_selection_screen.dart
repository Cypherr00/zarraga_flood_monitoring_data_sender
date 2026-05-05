// user_selection_screen.dart
import 'package:flutter/material.dart';
import 'pin_screen.dart';
import 'db_config.dart';

class UserSelectionScreen extends StatefulWidget {
  const UserSelectionScreen({super.key});
  static const routeName = '/user_selection';

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  List<String> _users = [];
  List<String> _filteredUsers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Brand Colors
  final Color primaryBlue = const Color(0xFF0D47A1);
  final Color lightBlueBg = const Color(0xFFE3F2FD);

  @override
  void initState() {
    super.initState();
    _loadUsers();

    _searchController.addListener(() {
      _filterUsers(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    // Show loading indicator if triggered manually via the refresh button
    setState(() {
      _isLoading = true;
    });

    try {
      final users = await DbConfig().getActiveUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
      // Re-apply any existing search filter after fetching new data
      _filterUsers(_searchController.text);
    } catch (e) {
      setState(() {
        _users = [];
        _filteredUsers = [];
        _isLoading = false;
      });
    }
  }

  void _filterUsers(String query) {
    final filtered = _users
        .where((u) => u.toLowerCase().contains(query.toLowerCase()))
        .toList();
    setState(() {
      _filteredUsers = filtered;
    });
  }

  void _selectUser(String userName) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PinScreen(userName: userName),
      ),
    );
  }

  Widget _buildUserCard(String userName) {
    // Safely generate initials, preventing crashes from multiple spaces
    String initials = "?";
    if (userName.trim().isNotEmpty) {
      initials = userName
          .trim()
          .split(RegExp(r'\s+')) // Splits by any amount of whitespace
          .where((e) => e.isNotEmpty)
          .map((e) => e[0].toUpperCase())
          .take(2)
          .join();
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue.shade100, width: 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _selectUser(userName),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: primaryBlue,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  userName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 24, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBlueBg,
      appBar: AppBar(
        backgroundColor: lightBlueBg,
        elevation: 0,
        title: Text(
          "Select User",
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: primaryBlue,
            tooltip: 'Refresh Users',
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: "Search users...",
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: primaryBlue),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.blue.shade100, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: primaryBlue, width: 2),
                ),
              ),
            ),
          ),

          // List of users
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primaryBlue))
                : RefreshIndicator(
              color: primaryBlue,
              onRefresh: _loadUsers,
              child: _filteredUsers.isEmpty
                  ? ListView(
                // AlwaysScrollableScrollPhysics ensures pull-to-refresh works even if empty
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  Icon(Icons.person_off_outlined, size: 64, color: Colors.blue.shade200),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      "No users found",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              )
                  : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: _filteredUsers.length,
                itemBuilder: (context, index) {
                  final userName = _filteredUsers[index];
                  return _buildUserCard(userName);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}