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
    try {
      final users = await DbConfig().getAllUsers();
      setState(() {
        _users = users;
        _filteredUsers = users;
        _isLoading = false;
      });
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
    String initials = userName.isNotEmpty
        ? userName.trim().split(' ').map((e) => e[0].toUpperCase()).take(2).join()
        : '?';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectUser(userName),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.blue.shade700,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select User"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search users...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),

          // List of users
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.person_off, size: 60, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    "No users found",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _filteredUsers.length,
              itemBuilder: (context, index) {
                final userName = _filteredUsers[index];
                return _buildUserCard(userName);
              },
            ),
          ),
        ],
      ),
    );
  }
}
