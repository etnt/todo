import 'package:flutter/material.dart';

import '../app_routes.dart';

/// Placeholder todo list screen. Real list (tabs, rows, actions) is built in
/// Phase 6; the add screen arrives in Phase 7.
class TodoListScreen extends StatelessWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TODO List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
          ),
        ],
      ),
      body: const Center(child: Text('No todos yet')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {}, // Add-todo screen arrives in Phase 7.
        child: const Icon(Icons.add),
      ),
    );
  }
}
