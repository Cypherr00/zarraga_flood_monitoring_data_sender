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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await DbConfig().getAllUsers();
    setState(() {
      _users = users;
      _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select User")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
          ? const Center(child: Text("No users found"))
          : ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          return ListTile(
            title: Text(user),
            onTap: () => _selectUser(user),
          );
        },
      ),
    );
  }
}
