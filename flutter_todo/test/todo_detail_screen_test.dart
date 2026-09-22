import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_todo/models/todo.dart';
import 'package:flutter_todo/repositories/todo_repository.dart';
import 'package:flutter_todo/screens/todo_detail_screen.dart';
import 'package:flutter_todo/services/github_api_client.dart';
import 'package:flutter_todo/state/todo_list_model.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'fakes/fake_http_client.dart';

Widget createDetailScreenTestApp({
  required TodoListModel todoListModel,
  required Todo todo,
}) {
  return ChangeNotifierProvider.value(
    value: todoListModel,
    child: MaterialApp(home: TodoDetailScreen(todo: todo)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TodoDetailScreen Rendering and Actions', () {
    testWidgets('renders full todo title, body, priority, and timestamps', (
      tester,
    ) async {
      final todo = Todo(
        id: '123',
        header: 'Ship release build',
        body: 'Check release keystore and permissions.',
        createdDate: '2026-08-28T10:00:00.000Z',
        finishedDate: null,
        status: 'active',
        priority: 4,
      );

      final todoListModel = TodoListModel();

      await tester.pumpWidget(
        createDetailScreenTestApp(todoListModel: todoListModel, todo: todo),
      );
      await tester.pumpAndSettle();

      expect(find.text('Issue #123'), findsOneWidget);
      expect(find.text('Ship release build'), findsOneWidget);
      expect(
        find.text('Check release keystore and permissions.'),
        findsOneWidget,
      );
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Mark as Completed'), findsOneWidget);
    });

    testWidgets('toggles status when action button is tapped', (tester) async {
      final fakeClient = FakeClient((request) {
        if (request.method == 'PATCH') {
          return http.Response('{"number": 123, "state": "closed"}', 200);
        }
        return http.Response('error', 400);
      });

      final apiClient = GitHubApiClient(httpClient: fakeClient);
      final repo = TodoRepository(
        apiClient: apiClient,
        repo: 'owner/test-repo',
      );
      final todoListModel = TodoListModel(repository: repo);

      final todo = Todo(
        id: '123',
        header: 'Task',
        body: 'Body',
        status: 'active',
      );

      await tester.pumpWidget(
        createDetailScreenTestApp(todoListModel: todoListModel, todo: todo),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mark as Completed'));
      await tester.pumpAndSettle();

      expect(todo.isDone, isTrue);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Reopen (Mark Active)'), findsOneWidget);
    });

    testWidgets(
      'shows delete confirmation dialog and deletes item on confirm',
      (tester) async {
        final fakeClient = FakeClient((request) {
          if (request.method == 'PATCH') {
            return http.Response('{"number": 123}', 200);
          }
          return http.Response('error', 400);
        });

        final apiClient = GitHubApiClient(httpClient: fakeClient);
        final repo = TodoRepository(
          apiClient: apiClient,
          repo: 'owner/test-repo',
        );
        final todoListModel = TodoListModel(repository: repo);

        final todo = Todo(id: '123', header: 'To be deleted', body: 'Body');

        await tester.pumpWidget(
          createDetailScreenTestApp(todoListModel: todoListModel, todo: todo),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();

        expect(find.text('Delete TODO?'), findsOneWidget);

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(fakeClient.requests, hasLength(1));
      },
    );
  });
}
