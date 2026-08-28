import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_todo/app_routes.dart';
import 'package:flutter_todo/screens/settings_screen.dart';
import 'package:flutter_todo/screens/todo_list_screen.dart';
import 'package:flutter_todo/services/github_api_client.dart';
import 'package:flutter_todo/services/settings_store.dart';
import 'package:flutter_todo/state/settings_model.dart';
import 'package:flutter_todo/state/todo_list_model.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'fakes/fake_http_client.dart';

/// Test implementation of [SettingsStore] keeping values purely in-memory.
class FakeSettingsStore implements SettingsStore {
  String? _repo;
  String? _token;

  @override
  Future<String?> getRepo() async => _repo;

  @override
  Future<void> saveRepo(String repo) async {
    _repo = repo.trim();
  }

  @override
  Future<String?> getToken() async => _token;

  @override
  Future<void> saveToken(String token) async {
    _token = token.trim();
  }

  @override
  Future<bool> isConfigured() async {
    return _repo != null && _repo!.isNotEmpty && _token != null && _token!.isNotEmpty;
  }

  @override
  Future<void> clear() async {
    _repo = null;
    _token = null;
  }
}

Widget createSettingsTestApp({
  required SettingsModel settingsModel,
  required TodoListModel todoListModel,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settingsModel),
      ChangeNotifierProvider.value(value: todoListModel),
    ],
    child: MaterialApp(
      initialRoute: AppRoutes.settings,
      routes: {
        AppRoutes.settings: (_) => const SettingsScreen(),
        AppRoutes.list: (_) => const TodoListScreen(),
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSettingsStore settingsStore;

  setUp(() {
    settingsStore = FakeSettingsStore();
  });

  group('SettingsStore logic', () {
    test('isConfigured is false initially and true when both repo and token are saved', () async {
      expect(await settingsStore.isConfigured(), isFalse);

      await settingsStore.saveRepo('owner/repo');
      expect(await settingsStore.isConfigured(), isFalse);

      await settingsStore.saveToken('ghp_token123');
      expect(await settingsStore.isConfigured(), isTrue);

      expect(await settingsStore.getRepo(), 'owner/repo');
      expect(await settingsStore.getToken(), 'ghp_token123');

      await settingsStore.clear();
      expect(await settingsStore.isConfigured(), isFalse);
      expect(await settingsStore.getRepo(), isNull);
      expect(await settingsStore.getToken(), isNull);
    });
  });

  group('SettingsScreen Widget Tests', () {
    testWidgets('shows validation errors for invalid inputs', (tester) async {
      final settingsModel = SettingsModel(settingsStore: settingsStore);
      final todoListModel = TodoListModel();

      await tester.pumpWidget(createSettingsTestApp(
        settingsModel: settingsModel,
        todoListModel: todoListModel,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save & Open TODOs'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter repository (e.g. owner/repo)'), findsOneWidget);
      expect(find.text('Please enter your GitHub Personal Access Token'), findsOneWidget);
    });

    testWidgets('test connection button displays success feedback', (tester) async {
      final fakeClient = FakeClient((request) {
        if (request.url.path == '/repos/owner/repo') {
          return http.Response(jsonEncode({'full_name': 'owner/repo'}), 200);
        }
        return http.Response('not found', 404);
      });

      final settingsModel = SettingsModel(
        settingsStore: settingsStore,
        clientFactory: (token) => GitHubApiClient(token: token, httpClient: fakeClient),
      );
      final todoListModel = TodoListModel();

      await tester.pumpWidget(createSettingsTestApp(
        settingsModel: settingsModel,
        todoListModel: todoListModel,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'owner/repo');
      await tester.enterText(find.byType(TextFormField).at(1), 'ghp_test_token');

      await tester.tap(find.text('Test Connection'));
      await tester.pumpAndSettle();

      expect(find.text('Successfully connected to owner/repo'), findsOneWidget);
    });

    testWidgets('save settings persists credentials and navigates to list', (tester) async {
      final settingsModel = SettingsModel(settingsStore: settingsStore);
      final todoListModel = TodoListModel();

      await tester.pumpWidget(createSettingsTestApp(
        settingsModel: settingsModel,
        todoListModel: todoListModel,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'owner/repo');
      await tester.enterText(find.byType(TextFormField).at(1), 'ghp_test_token');

      await tester.tap(find.text('Save & Open TODOs'));
      await tester.pumpAndSettle();

      expect(await settingsStore.getRepo(), 'owner/repo');
      expect(await settingsStore.getToken(), 'ghp_test_token');
      expect(find.byType(TodoListScreen), findsOneWidget);
    });
  });
}
