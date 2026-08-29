import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_todo/models/todo.dart';
import 'package:flutter_todo/repositories/todo_repository.dart';
import 'package:flutter_todo/screens/settings_screen.dart';
import 'package:flutter_todo/screens/todo_list_screen.dart';
import 'package:flutter_todo/services/github_api_client.dart';
import 'package:flutter_todo/state/settings_model.dart';
import 'package:flutter_todo/state/todo_list_model.dart';
import 'package:flutter_todo/widgets/empty_state.dart';
import 'package:flutter_todo/widgets/error_banner.dart';
import 'package:flutter_todo/widgets/todo_list_tile.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'fakes/fake_http_client.dart';
import 'settings_screen_test.dart';

Widget createTodoListTestApp({
  required SettingsModel settingsModel,
  required TodoListModel todoListModel,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settingsModel),
      ChangeNotifierProvider.value(value: todoListModel),
    ],
    child: MaterialApp(
      home: const TodoListScreen(),
      routes: {
        '/settings': (_) => const SettingsScreen(),
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSettingsStore settingsStore;
  late SettingsModel settingsModel;
  late TodoListModel todoListModel;

  setUp(() async {
    settingsStore = FakeSettingsStore();
    await settingsStore.addRepo('owner/test-repo');
    await settingsStore.saveToken('ghp_test');

    settingsModel = SettingsModel(settingsStore: settingsStore)..loadSettings();
    todoListModel = TodoListModel();
  });

  group('TodoListScreen Display & Filtering', () {
    testWidgets('displays active todos and switches filter tabs', (tester) async {
      final fakeClient = FakeClient((request) {
        if (request.url.path == '/repos/owner/test-repo/issues') {
          return http.Response(
            jsonEncode([
              {
                'number': 1,
                'title': 'Active Task',
                'body': 'Body 1\n\n<!-- todo-meta: {"priority":0,"deleted":false} -->',
                'state': 'open',
              },
              {
                'number': 2,
                'title': 'Done Task',
                'body': 'Body 2\n\n<!-- todo-meta: {"priority":1,"deleted":false} -->',
                'state': 'closed',
              },
            ]),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final apiClient = GitHubApiClient(httpClient: fakeClient);
      final repo = TodoRepository(apiClient: apiClient, repo: 'owner/test-repo');
      todoListModel.setRepository(repo);

      await tester.pumpWidget(createTodoListTestApp(
        settingsModel: settingsModel,
        todoListModel: todoListModel,
      ));
      await tester.pumpAndSettle();

      // Initially on 'Active' tab
      expect(find.text('Active Task'), findsOneWidget);
      expect(find.text('Done Task'), findsNothing);

      // Switch to 'Done' tab
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Active Task'), findsNothing);
      expect(find.text('Done Task'), findsOneWidget);

      // Switch to 'All' tab
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(find.text('Active Task'), findsOneWidget);
      expect(find.text('Done Task'), findsOneWidget);
    });

    testWidgets('shows empty state when no todos are present', (tester) async {
      await tester.pumpWidget(createTodoListTestApp(
        settingsModel: settingsModel,
        todoListModel: todoListModel,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No active tasks'), findsOneWidget);
    });

    testWidgets('shows error banner when errorMessage is set', (tester) async {
      await tester.pumpWidget(createTodoListTestApp(
        settingsModel: settingsModel,
        todoListModel: todoListModel,
      ));
      await tester.pumpAndSettle();

      final fakeClient = FakeClient((_) => throw Exception('Network Failure'));
      final apiClient = GitHubApiClient(httpClient: fakeClient);
      final repo = TodoRepository(apiClient: apiClient, repo: 'owner/test-repo');
      todoListModel.setRepository(repo);
      await todoListModel.loadTodos();

      await tester.pumpAndSettle();

      expect(find.byType(ErrorBanner), findsOneWidget);
      expect(find.textContaining('Network Failure'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('provides popup menu when multiple repositories are configured', (tester) async {
      await settingsStore.addRepo('owner/second-repo', makeActive: false);

      final fakeClient = FakeClient((request) {
        if (request.url.path == '/repos/owner/second-repo/issues') {
          return http.Response(
            jsonEncode([
              {
                'number': 10,
                'title': 'Task in Repo 2',
                'body': 'Body\n\n<!-- todo-meta: {"priority":0,"deleted":false} -->',
                'state': 'open',
              },
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      });

      settingsModel = SettingsModel(
        settingsStore: settingsStore,
        clientFactory: (token) => GitHubApiClient(token: token, httpClient: fakeClient),
      );
      await settingsModel.loadSettings();

      await tester.pumpWidget(createTodoListTestApp(
        settingsModel: settingsModel,
        todoListModel: todoListModel,
      ));
      await tester.pumpAndSettle();

      // Tap on the repo dropdown title
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('owner/test-repo'), findsWidgets);
      expect(find.text('owner/second-repo'), findsOneWidget);

      // Select second repo
      await tester.tap(find.text('owner/second-repo'));
      await tester.pumpAndSettle();

      expect(settingsModel.activeRepo, 'owner/second-repo');
      expect(find.text('Task in Repo 2'), findsOneWidget);
    });
  });

  group('TodoListTile Widget Tests', () {
    testWidgets('renders todo item and toggles status on checkbox tap', (tester) async {
      var toggled = false;
      var deleted = false;
      final todo = Todo(id: '10', header: 'Buy groceries', body: 'Milk', priority: 0);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TodoListTile(
            todo: todo,
            index: 0,
            onToggle: () => toggled = true,
            onDelete: () => deleted = true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Buy groceries'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);

      await tester.tap(find.byType(Checkbox));
      expect(toggled, isTrue);
      expect(deleted, isFalse);
    });
  });
}
