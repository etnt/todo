import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_todo/models/todo.dart';
import 'package:flutter_todo/repositories/todo_repository.dart';
import 'package:flutter_todo/screens/todo_edit_screen.dart';
import 'package:flutter_todo/services/github_api_client.dart';
import 'package:flutter_todo/state/todo_list_model.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'fakes/fake_http_client.dart';

Widget createEditScreenTestApp({
  required TodoListModel todoListModel,
  Todo? todo,
}) {
  return ChangeNotifierProvider.value(
    value: todoListModel,
    child: MaterialApp(home: TodoEditScreen(todo: todo)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TodoEditScreen in Add Mode', () {
    testWidgets(
      'renders empty fields and title validation error on empty submit',
      (tester) async {
        final todoListModel = TodoListModel();

        await tester.pumpWidget(
          createEditScreenTestApp(todoListModel: todoListModel),
        );
        await tester.pumpAndSettle();

        expect(find.text('New TODO'), findsOneWidget);
        expect(find.text('Create TODO'), findsOneWidget);

        await tester.tap(find.text('Create TODO'));
        await tester.pumpAndSettle();

        expect(find.text('Please enter a title for the TODO'), findsOneWidget);
      },
    );

    testWidgets('creates a new TODO successfully and pops screen', (
      tester,
    ) async {
      final fakeClient = FakeClient((request) {
        if (request.method == 'POST') {
          final bodyMap = jsonDecode((request as http.Request).body);
          return http.Response(
            jsonEncode({
              'number': 99,
              'title': bodyMap['title'],
              'body': bodyMap['body'],
              'state': 'open',
              'created_at': '2026-08-28T10:00:00Z',
            }),
            201,
          );
        }
        return http.Response('error', 400);
      });

      final apiClient = GitHubApiClient(httpClient: fakeClient);
      final repo = TodoRepository(
        apiClient: apiClient,
        repo: 'owner/test-repo',
      );
      final todoListModel = TodoListModel(repository: repo);

      await tester.pumpWidget(
        createEditScreenTestApp(todoListModel: todoListModel),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Buy milk');
      await tester.enterText(find.byType(TextFormField).at(1), '2 liters');

      await tester.tap(find.text('Create TODO'));
      await tester.pumpAndSettle();

      expect(repo.todos, hasLength(1));
      expect(repo.todos.first.header, 'Buy milk');
      expect(repo.todos.first.body, '2 liters');
    });
  });

  group('TodoEditScreen in Edit Mode', () {
    testWidgets('populates existing fields and updates TODO on save', (
      tester,
    ) async {
      final fakeClient = FakeClient((request) {
        if (request.method == 'PATCH') {
          return http.Response('{"number": 42}', 200);
        }
        return http.Response('error', 400);
      });

      final apiClient = GitHubApiClient(httpClient: fakeClient);
      final repo = TodoRepository(
        apiClient: apiClient,
        repo: 'owner/test-repo',
      );
      final todoListModel = TodoListModel(repository: repo);

      final existingTodo = Todo(
        id: '42',
        header: 'Old Title',
        body: 'Old Body',
      );

      await tester.pumpWidget(
        createEditScreenTestApp(
          todoListModel: todoListModel,
          todo: existingTodo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit TODO'), findsOneWidget);
      expect(find.text('Old Title'), findsOneWidget);
      expect(find.text('Old Body'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Updated Title');
      await tester.enterText(find.byType(TextFormField).at(1), 'Updated Body');

      await tester.tap(find.text('Update TODO'));
      await tester.pumpAndSettle();

      expect(existingTodo.header, 'Updated Title');
      expect(existingTodo.body, 'Updated Body');
    });
  });
}
