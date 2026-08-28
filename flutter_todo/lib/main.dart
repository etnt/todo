import 'package:flutter/material.dart';

import 'app_routes.dart';
import 'screens/settings_screen.dart';
import 'screens/todo_list_screen.dart';
import 'services/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final configured = await SettingsStore().isConfigured();
  runApp(TodoApp(configured: configured));
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key, required this.configured});

  /// Whether a GitHub repository is already configured on this device.
  /// Unconfigured installs start on the Settings screen.
  final bool configured;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TODO',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      initialRoute: configured ? AppRoutes.list : AppRoutes.settings,
      routes: {
        AppRoutes.settings: (_) => const SettingsScreen(),
        AppRoutes.list: (_) => const TodoListScreen(),
      },
    );
  }
}
