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
  final List<String> _repos = [];
  String? _activeRepo;
  String? _token;

  @override
  Future<List<String>> getRepos() async => List.unmodifiable(_repos);

  @override
  Future<String?> getActiveRepo() async => _activeRepo;

  @override
  Future<String?> getRepo() async => _activeRepo;

  @override
  Future<void> setActiveRepo(String repo) async {
    final clean = repo.trim();
    if (!_repos.contains(clean)) {
      _repos.add(clean);
    }
    _activeRepo = clean;
  }

  @override
  Future<void> addRepo(String repo, {bool makeActive = true}) async {
    final clean = repo.trim();
    if (clean.isEmpty) return;
    if (!_repos.contains(clean)) {
      _repos.add(clean);
    }
    if (makeActive || _activeRepo == null) {
      _activeRepo = clean;
    }
  }

  @override
  Future<void> removeRepo(String repo) async {
    final clean = repo.trim();
    _repos.remove(clean);
    if (_activeRepo == clean) {
      _activeRepo = _repos.isNotEmpty ? _repos.first : null;
    }
  }

  @override
  Future<void> saveRepo(String repo) => addRepo(repo, makeActive: true);

  @override
  Future<String?> getToken() async => _token;

  @override
  Future<void> saveToken(String token) async {
    _token = token.trim();
  }

  @override
  Future<bool> isConfigured() async {
    return _activeRepo != null &&
        _activeRepo!.isNotEmpty &&
        _token != null &&
        _token!.isNotEmpty;
  }

  @override
  Future<void> clear() async {
    _repos.clear();
    _activeRepo = null;
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

  group('SettingsStore multi-repo logic', () {
    test(
      'isConfigured is false initially and true when repo and token are saved',
      () async {
        expect(await settingsStore.isConfigured(), isFalse);

        await settingsStore.addRepo('owner/repo1');
        expect(await settingsStore.isConfigured(), isFalse);

        await settingsStore.saveToken('ghp_token123');
        expect(await settingsStore.isConfigured(), isTrue);

        expect(await settingsStore.getRepo(), 'owner/repo1');
        expect(await settingsStore.getRepos(), ['owner/repo1']);
        expect(await settingsStore.getToken(), 'ghp_token123');

        // Add second repo
        await settingsStore.addRepo('owner/repo2', makeActive: false);
        expect(await settingsStore.getRepos(), ['owner/repo1', 'owner/repo2']);
        expect(await settingsStore.getActiveRepo(), 'owner/repo1');

        // Switch active repo
        await settingsStore.setActiveRepo('owner/repo2');
        expect(await settingsStore.getActiveRepo(), 'owner/repo2');

        // Remove repo
        await settingsStore.removeRepo('owner/repo2');
        expect(await settingsStore.getRepos(), ['owner/repo1']);
        expect(await settingsStore.getActiveRepo(), 'owner/repo1');

        await settingsStore.clear();
        expect(await settingsStore.isConfigured(), isFalse);
        expect(await settingsStore.getRepo(), isNull);
        expect(await settingsStore.getRepos(), isEmpty);
        expect(await settingsStore.getToken(), isNull);
      },
    );
  });

  group('SettingsScreen Widget Tests', () {
    testWidgets('shows validation errors for invalid inputs', (tester) async {
      final settingsModel = SettingsModel(settingsStore: settingsStore);
      final todoListModel = TodoListModel();

      await tester.pumpWidget(
        createSettingsTestApp(
          settingsModel: settingsModel,
          todoListModel: todoListModel,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save & Open TODOs'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please enter repository (e.g. owner/repo)'),
        findsOneWidget,
      );
      expect(
        find.text('Please enter your GitHub Personal Access Token'),
        findsOneWidget,
      );
    });

    testWidgets('test connection button displays success feedback', (
      tester,
    ) async {
      final fakeClient = FakeClient((request) {
        if (request.url.path == '/repos/owner/repo') {
          return http.Response(jsonEncode({'full_name': 'owner/repo'}), 200);
        }
        return http.Response('not found', 404);
      });

      final settingsModel = SettingsModel(
        settingsStore: settingsStore,
        clientFactory: (token) =>
            GitHubApiClient(token: token, httpClient: fakeClient),
      );
      final todoListModel = TodoListModel();

      await tester.pumpWidget(
        createSettingsTestApp(
          settingsModel: settingsModel,
          todoListModel: todoListModel,
        ),
      );
      await tester.pumpAndSettle();

      // Enter token first (at index 0)
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'ghp_test_token',
      );
      // Enter repository (at index 1)
      await tester.enterText(find.byType(TextFormField).at(1), 'owner/repo');

      await tester.tap(find.text('Test Connection'));
      await tester.pumpAndSettle();

      expect(find.text('Successfully connected to owner/repo'), findsOneWidget);
    });

    testWidgets('save settings persists credentials and navigates to list', (
      tester,
    ) async {
      final settingsModel = SettingsModel(settingsStore: settingsStore);
      final todoListModel = TodoListModel();

      await tester.pumpWidget(
        createSettingsTestApp(
          settingsModel: settingsModel,
          todoListModel: todoListModel,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'ghp_test_token',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'owner/repo');

      await tester.tap(find.text('Save & Open TODOs'));
      await tester.pumpAndSettle();

      expect(await settingsStore.getActiveRepo(), 'owner/repo');
      expect(await settingsStore.getToken(), 'ghp_test_token');
      expect(find.byType(TodoListScreen), findsOneWidget);
    });

    testWidgets(
      'allows adding multiple repositories and switching active selection',
      (tester) async {
        await settingsStore.addRepo('owner/repo-one');
        await settingsStore.saveToken('ghp_test_token');

        final settingsModel = SettingsModel(settingsStore: settingsStore)
          ..loadSettings();
        final todoListModel = TodoListModel();

        await tester.pumpWidget(
          createSettingsTestApp(
            settingsModel: settingsModel,
            todoListModel: todoListModel,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('owner/repo-one'), findsOneWidget);
        expect(find.text('Active Repository'), findsOneWidget);

        // Add a second repository
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'owner/repo-two',
        );
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();

        expect(find.text('owner/repo-two'), findsOneWidget);
        expect(await settingsStore.getActiveRepo(), 'owner/repo-two');

        // Tap on first repository to switch back
        await tester.tap(find.text('owner/repo-one'));
        await tester.pumpAndSettle();

        expect(await settingsStore.getActiveRepo(), 'owner/repo-one');
      },
    );
  });
}
