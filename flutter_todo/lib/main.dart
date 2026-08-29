import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_routes.dart';
import 'repositories/todo_repository.dart';
import 'screens/settings_screen.dart';
import 'screens/todo_edit_screen.dart';
import 'screens/todo_list_screen.dart';
import 'services/github_api_client.dart';
import 'services/settings_store.dart';
import 'state/settings_model.dart';
import 'state/todo_list_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsStore = SettingsStore();
  final isConfigured = await settingsStore.isConfigured();

  final repo = await settingsStore.getRepo();
  final token = await settingsStore.getToken();

  TodoRepository? todoRepository;
  if (isConfigured && repo != null && token != null) {
    final apiClient = GitHubApiClient(token: token);
    todoRepository = TodoRepository(apiClient: apiClient, repo: repo);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              SettingsModel(settingsStore: settingsStore)..loadSettings(),
        ),
        ChangeNotifierProvider(
          create: (_) => TodoListModel(repository: todoRepository),
        ),
      ],
      child: TodoApp(configured: isConfigured),
    ),
  );
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key, required this.configured});

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
        AppRoutes.edit: (_) => const TodoEditScreen(),
      },
    );
  }
}
