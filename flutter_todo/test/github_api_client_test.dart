import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_todo/services/github_api_client.dart';
import 'package:http/http.dart' as http;

import 'fakes/fake_http_client.dart';

void main() {
  group('GitHubApiClient headers and authentication', () {
    test('sends standard GitHub headers and bearer token', () async {
      late http.BaseRequest capturedRequest;
      final fakeClient = FakeClient((request) {
        capturedRequest = request;
        return http.Response(jsonEncode({'full_name': 'owner/repo'}), 200);
      });

      final client = GitHubApiClient(
        token: 'ghp_secret123',
        httpClient: fakeClient,
      );

      await client.testConnection('owner/repo');

      expect(capturedRequest.headers['Accept'], 'application/vnd.github+json');
      expect(capturedRequest.headers['Content-Type'], 'application/json');
      expect(capturedRequest.headers['X-GitHub-Api-Version'], '2022-11-28');
      expect(capturedRequest.headers['Authorization'], 'Bearer ghp_secret123');
    });

    test('omits Authorization header when token is null or empty', () async {
      late http.BaseRequest capturedRequest;
      final fakeClient = FakeClient((request) {
        capturedRequest = request;
        return http.Response(jsonEncode({'full_name': 'owner/repo'}), 200);
      });

      final client = GitHubApiClient(httpClient: fakeClient);
      await client.testConnection('owner/repo');

      expect(capturedRequest.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('GitHubApiClient API methods', () {
    test('testConnection returns repository data map', () async {
      final fakeClient = FakeClient((request) {
        if (request.url.path == '/repos/owner/repo') {
          return http.Response(
            jsonEncode({'id': 12345, 'name': 'repo', 'private': false}),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final client = GitHubApiClient(httpClient: fakeClient);
      final repo = await client.testConnection('owner/repo');

      expect(repo['id'], 12345);
      expect(repo['name'], 'repo');
    });

    test('listIssues paginates and filters out pull requests', () async {
      final fakeClient = FakeClient((request) {
        final page = request.url.queryParameters['page'];
        if (page == '1') {
          return http.Response(
            jsonEncode([
              {'number': 1, 'title': 'Issue 1'},
              {'number': 2, 'title': 'PR 1', 'pull_request': {'url': '...'}},
            ]),
            200,
          );
        } else if (page == '2') {
          return http.Response(
            jsonEncode([
              {'number': 3, 'title': 'Issue 2'},
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      });

      final client = GitHubApiClient(httpClient: fakeClient);
      final issues = await client.listIssues('owner/repo', perPage: 2);

      expect(issues, hasLength(2));
      expect(issues[0]['number'], 1);
      expect(issues[1]['number'], 3);
      expect(fakeClient.requests, hasLength(2));
    });

    test('createIssue sends POST with title and body JSON', () async {
      final fakeClient = FakeClient((request) {
        expect(request.method, 'POST');
        expect(request.url.path, '/repos/owner/repo/issues');
        return http.Response(
          jsonEncode({'number': 42, 'title': 'New Todo', 'state': 'open'}),
          201,
        );
      });

      final client = GitHubApiClient(httpClient: fakeClient);
      final issue = await client.createIssue(
        'owner/repo',
        title: 'New Todo',
        body: 'Description <!-- todo-meta: {"priority":0,"deleted":false} -->',
      );

      expect(issue['number'], 42);
      expect(fakeClient.jsonBodyOf(0)['title'], 'New Todo');
      expect(fakeClient.jsonBodyOf(0)['body'], contains('<!-- todo-meta:'));
    });

    test('patchIssue sends PATCH with payload JSON', () async {
      final fakeClient = FakeClient((request) {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/repos/owner/repo/issues/42');
        return http.Response(
          jsonEncode({'number': 42, 'state': 'closed'}),
          200,
        );
      });

      final client = GitHubApiClient(httpClient: fakeClient);
      final updated = await client.patchIssue(
        'owner/repo',
        42,
        {'state': 'closed'},
      );

      expect(updated['state'], 'closed');
      expect(fakeClient.jsonBodyOf(0), {'state': 'closed'});
    });
  });

  group('GitHubApiClient Error Handling Hierarchy', () {
    test('maps 401 to GitHubAuthException', () async {
      final fakeClient = FakeClient((_) => http.Response(
            jsonEncode({'message': 'Bad credentials'}),
            401,
          ));

      final client = GitHubApiClient(httpClient: fakeClient);

      expect(
        () => client.testConnection('owner/repo'),
        throwsA(isA<GitHubAuthException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('maps 403 rate limit to GitHubRateLimitException with reset time', () async {
      final fakeClient = FakeClient((_) => http.Response(
            jsonEncode({'message': 'API rate limit exceeded'}),
            403,
            headers: {
              'x-ratelimit-remaining': '0',
              'x-ratelimit-reset': '1700000000',
            },
          ));

      final client = GitHubApiClient(httpClient: fakeClient);

      expect(
        () => client.testConnection('owner/repo'),
        throwsA(isA<GitHubRateLimitException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having(
              (e) => e.resetTime,
              'resetTime',
              DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true),
            )),
      );
    });

    test('maps 403 without rate limit to GitHubAuthException', () async {
      final fakeClient = FakeClient((_) => http.Response(
            jsonEncode({'message': 'Forbidden'}),
            403,
          ));

      final client = GitHubApiClient(httpClient: fakeClient);

      expect(
        () => client.testConnection('owner/repo'),
        throwsA(isA<GitHubAuthException>().having((e) => e.statusCode, 'statusCode', 403)),
      );
    });

    test('maps 404 to GitHubNotFoundException', () async {
      final fakeClient = FakeClient((_) => http.Response(
            jsonEncode({'message': 'Not Found'}),
            404,
          ));

      final client = GitHubApiClient(httpClient: fakeClient);

      expect(
        () => client.testConnection('owner/repo'),
        throwsA(isA<GitHubNotFoundException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });

    test('maps 422 to GitHubValidationException', () async {
      final fakeClient = FakeClient((_) => http.Response(
            jsonEncode({'message': 'Validation Failed'}),
            422,
          ));

      final client = GitHubApiClient(httpClient: fakeClient);

      expect(
        () => client.createIssue('owner/repo', title: '', body: ''),
        throwsA(isA<GitHubValidationException>().having((e) => e.statusCode, 'statusCode', 422)),
      );
    });

    test('maps http.ClientException to GitHubNetworkException', () async {
      final fakeClient = FakeClient((_) => throw http.ClientException('Failed to connect'));

      final client = GitHubApiClient(httpClient: fakeClient);

      expect(
        () => client.testConnection('owner/repo'),
        throwsA(isA<GitHubNetworkException>()),
      );
    });
  });

}
