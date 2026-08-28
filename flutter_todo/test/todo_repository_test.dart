import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_todo/models/todo.dart';
import 'package:flutter_todo/repositories/todo_repository.dart';
import 'package:flutter_todo/services/github_api_client.dart';
import 'package:http/http.dart' as http;

import 'fakes/fake_http_client.dart';

void main() {
  const testRepo = 'owner/test-repo';

  group('TodoRepository load and query methods', () {
    test('load retrieves issues, decodes metadata, filters deleted, sorts by priority', () async {
      final fakeClient = FakeClient((request) {
        if (request.url.path == '/repos/$testRepo/issues') {
          return http.Response(
            jsonEncode([
              {
                'number': 1,
                'title': 'Task Low Priority',
                'body': 'Body 1\n\n<!-- todo-meta: {"priority":10,"deleted":false} -->',
                'state': 'open',
                'created_at': '2026-08-28T10:00:00Z',
              },
              {
                'number': 2,
                'title': 'Task High Priority',
                'body': 'Body 2\n\n<!-- todo-meta: {"priority":1,"deleted":false} -->',
                'state': 'closed',
                'created_at': '2026-08-28T09:00:00Z',
                'closed_at': '2026-08-28T09:30:00Z',
              },
              {
                'number': 3,
                'title': 'Deleted Task',
                'body': '<!-- todo-meta: {"priority":0,"deleted":true} -->',
                'state': 'closed',
              },
            ]),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final apiClient = GitHubApiClient(httpClient: fakeClient);
      final repo = TodoRepository(apiClient: apiClient, repo: testRepo);

      final todos = await repo.load();

      expect(todos, hasLength(2));
      expect(todos[0].id, '2');
      expect(todos[0].header, 'Task High Priority');
      expect(todos[0].priority, 1);
      expect(todos[0].isDone, isTrue);

      expect(todos[1].id, '1');
      expect(todos[1].header, 'Task Low Priority');
      expect(todos[1].priority, 10);
      expect(todos[1].isActive, isTrue);

      expect(repo.getActiveTodos(), hasLength(1));
      expect(repo.getActiveTodos().first.id, '1');

      expect(repo.getDoneTodos(), hasLength(1));
      expect(repo.getDoneTodos().first.id, '2');

      expect(repo.getAllTodos(), hasLength(2));
    });
  });

  group('TodoRepository CRUD and state modifications', () {
    test('addTodo computes next priority, creates issue on GitHub and updates local list', () async {
      final fakeClient = FakeClient((request) {
        if (request.method == 'POST' && request.url.path == '/repos/$testRepo/issues') {
          final bodyMap = jsonDecode((request as http.Request).body);
          expect(bodyMap['title'], 'New Task');
          expect(bodyMap['body'], contains('<!-- todo-meta: {"priority":0,"deleted":false} -->'));

          return http.Response(
            jsonEncode({
              'number': 101,
              'title': 'New Task',
              'body': bodyMap['body'],
              'state': 'open',
              'created_at': '2026-08-28T12:00:00Z',
            }),
            201,
          );
        }
        return http.Response('error', 400);
      });

      final apiClient = GitHubApiClient(httpClient: fakeClient);
      final repo = TodoRepository(apiClient: apiClient, repo: testRepo);

      final added = await repo.addTodo('New Task', 'Do something important');

      expect(added.id, '101');
      expect(added.header, 'New Task');
      expect(added.priority, 0);
      expect(added.status, 'active');
      expect(repo.todos, contains(added));
    });

    test('updateTodo patches title and body metadata on GitHub', () async {
      late Map<String, dynamic> capturedPatchBody;
      final fakeClient = FakeClient((request) {
        if (request.method == 'PATCH' && request.url.path == '/repos/$testRepo/issues/101') {
          capturedPatchBody = jsonDecode((request as http.Request).body);
          return http.Response(jsonEncode({'number': 101}), 200);
        }
        return http.Response('error', 400);
      });

      final apiClient = GitHubApiClient(httpClient: fakeClient);
      final repo = TodoRepository(apiClient: apiClient, repo: testRepo);

      final todo = Todo(
        id: '101',
        header: 'Original Title',
        body: 'Original Body',
        priority: 3,
      );

      await repo.updateTodo(todo, 'Updated Title', 'Updated Body');

      expect(todo.header, 'Updated Title');
      expect(todo.body, 'Updated Body');
      expect(capturedPatchBody['title'], 'Updated Title');
      expect(
        capturedPatchBody['body'],
        'Updated Body\n\n<!-- todo-meta: {"priority":3,"deleted":false} -->',
      );
    });

    test('toggleStatus flips active to done and sends closed state to GitHub', () async {
      late Map<String, dynamic> capturedPatchBody;
      final fakeClient = FakeClient((request) {
        if (request.method == 'PATCH' && request.url.path == '/repos/$testRepo/issues/101') {
          capturedPatchBody = jsonDecode((request as http.Request).body);
          return http.Response(jsonEncode({'number': 101}), 200);
        }
        return http.Response('error', 400);
      });

      final apiClient = GitHubApiClient(httpClient: fakeClient);
      final repo = TodoRepository(apiClient: apiClient, repo: testRepo);

      final todo = Todo(id: '101', header: 'Task', body: 'Body', status: 'active');

      await repo.toggleStatus(todo);

      expect(todo.status, 'done');
      expect(todo.isDone, isTrue);
      expect(todo.finishedDate, isNotNull);
      expect(capturedPatchBody['state'], 'closed');

      await repo.toggleStatus(todo);

      expect(todo.status, 'active');
      expect(todo.finishedDate, isNull);
      expect(capturedPatchBody['state'], 'open');
    });

    test('moveUp and moveDown swap priorities and patch both GitHub issues', () async {
      final patchedIssues = <String, Map<String, dynamic>>{};
      final fakeClient = FakeClient((request) {
        if (request.method == 'PATCH') {
          final issuePath = request.url.path;
          patchedIssues[issuePath] = jsonDecode((request as http.Request).body);
          return http.Response(jsonEncode({'success': true}), 200);
        }
        return http.Response('error', 400);
      });

      final apiClient = GitHubApiClient(httpClient: fakeClient);
      final repo = TodoRepository(apiClient: apiClient, repo: testRepo);

      final t1 = Todo(id: '1', header: 'First', body: 'B1', priority: 0);
      final t2 = Todo(id: '2', header: 'Second', body: 'B2', priority: 1);

      final list = [t1, t2];

      await repo.moveUp(t2, list);

      expect(t2.priority, 0);
      expect(t1.priority, 1);
      expect(patchedIssues['/repos/$testRepo/issues/2']!['body'], contains('{"priority":0,"deleted":false}'));
      expect(patchedIssues['/repos/$testRepo/issues/1']!['body'], contains('{"priority":1,"deleted":false}'));

      await repo.moveDown(t2, [t2, t1]);

      expect(t2.priority, 1);
      expect(t1.priority, 0);
    });

    test('deleteTodo closes GitHub issue, sets deleted metadata, and removes from local list', () async {
      late Map<String, dynamic> capturedDeletePatch;
      final fakeClient = FakeClient((request) {
        if (request.method == 'PATCH' && request.url.path == '/repos/$testRepo/issues/101') {
          capturedDeletePatch = jsonDecode((request as http.Request).body);
          return http.Response(jsonEncode({'number': 101}), 200);
        }
        return http.Response('error', 400);
      });

      final apiClient = GitHubApiClient(httpClient: fakeClient);
      final repo = TodoRepository(apiClient: apiClient, repo: testRepo);

      final todo = Todo(id: '101', header: 'Task to Delete', body: 'Some details', priority: 5);

      await repo.deleteTodo(todo);

      expect(capturedDeletePatch['state'], 'closed');
      expect(
        capturedDeletePatch['body'],
        'Some details\n\n<!-- todo-meta: {"priority":5,"deleted":true} -->',
      );
      expect(repo.todos, isNot(contains(todo)));
    });
  });

}
