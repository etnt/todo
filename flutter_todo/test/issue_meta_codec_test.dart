import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_todo/services/issue_meta_codec.dart';

void main() {
  group('IssueMetaCodec encoding and decoding', () {
    test(
      'encodes empty body into comment-only string matching Python format',
      () {
        const meta = IssueMetadata(priority: 2, deleted: false);
        final encoded = IssueMetaCodec.encode('', meta);

        expect(encoded, '<!-- todo-meta: {"priority":2,"deleted":false} -->');
      },
    );

    test(
      'encodes multiline body with trailing metadata comment matching Python format',
      () {
        const meta = IssueMetadata(priority: 0, deleted: false);
        final encoded = IssueMetaCodec.encode('Hello world\nSecond line', meta);

        expect(
          encoded,
          'Hello world\nSecond line\n\n<!-- todo-meta: {"priority":0,"deleted":false} -->',
        );
      },
    );

    test('decodes clean body and metadata correctly', () {
      const rawBody =
          'Buy groceries\n- Apples\n- Oranges\n\n<!-- todo-meta: {"priority":3,"deleted":false} -->';
      final decoded = IssueMetaCodec.decode(rawBody);

      expect(decoded.body, 'Buy groceries\n- Apples\n- Oranges');
      expect(decoded.metadata.priority, 3);
      expect(decoded.metadata.deleted, isFalse);
    });

    test('decodes body when comment-only (empty body)', () {
      const rawBody = '<!-- todo-meta: {"priority":5,"deleted":true} -->';
      final decoded = IssueMetaCodec.decode(rawBody);

      expect(decoded.body, isEmpty);
      expect(decoded.metadata.priority, 5);
      expect(decoded.metadata.deleted, isTrue);
    });

    test('decodes body without metadata comment safely', () {
      const rawBody =
          'This is an issue created outside the app without any metadata.';
      final decoded = IssueMetaCodec.decode(rawBody);

      expect(decoded.body, rawBody);
      expect(decoded.metadata.priority, isNull);
      expect(decoded.metadata.deleted, isFalse);
    });

    test(
      'finds the last comment occurrence if text contains literal comment markers',
      () {
        const rawBody =
            'Example code:\n<!-- todo-meta: {"priority":999} -->\nActual note body\n\n<!-- todo-meta: {"priority":1,"deleted":false} -->';
        final decoded = IssueMetaCodec.decode(rawBody);

        expect(
          decoded.body,
          'Example code:\n<!-- todo-meta: {"priority":999} -->\nActual note body',
        );
        expect(decoded.metadata.priority, 1);
        expect(decoded.metadata.deleted, isFalse);
      },
    );

    test('handles malformed JSON gracefully', () {
      const rawBody = 'Some text\n\n<!-- todo-meta: {invalid json} -->';
      final decoded = IssueMetaCodec.decode(rawBody);

      expect(decoded.body, rawBody);
      expect(decoded.metadata.priority, isNull);
      expect(decoded.metadata.deleted, isFalse);
    });

    test('round-trip encoding and decoding preserves body and metadata', () {
      const originalBody = 'Line 1\nLine 2\n\nLine 4';
      const originalMeta = IssueMetadata(priority: 7, deleted: false);

      final encoded = IssueMetaCodec.encode(originalBody, originalMeta);
      final decoded = IssueMetaCodec.decode(encoded);

      expect(decoded.body, originalBody);
      expect(decoded.metadata.priority, 7);
      expect(decoded.metadata.deleted, isFalse);
    });
  });

  group('IssueMetaCodec.fromGitHubIssue', () {
    test('maps open issue into active Todo', () {
      final issueJson = {
        'number': 101,
        'title': 'Write Flutter tests',
        'body':
            'Cover all model logic\n\n<!-- todo-meta: {"priority":2,"deleted":false} -->',
        'state': 'open',
        'created_at': '2026-08-28T10:00:00Z',
        'closed_at': null,
      };

      final todo = IssueMetaCodec.fromGitHubIssue(issueJson);

      expect(todo, isNotNull);
      expect(todo!.id, '101');
      expect(todo.header, 'Write Flutter tests');
      expect(todo.body, 'Cover all model logic');
      expect(todo.status, 'active');
      expect(todo.isActive, isTrue);
      expect(todo.priority, 2);
      expect(todo.createdDate, '2026-08-28T10:00:00.000Z');
      expect(todo.finishedDate, isNull);
    });

    test('maps closed issue into done Todo', () {
      final issueJson = {
        'number': 102,
        'title': 'Finished task',
        'body': '<!-- todo-meta: {"priority":0,"deleted":false} -->',
        'state': 'closed',
        'created_at': '2026-08-27T08:00:00Z',
        'closed_at': '2026-08-28T09:30:00Z',
      };

      final todo = IssueMetaCodec.fromGitHubIssue(issueJson);

      expect(todo, isNotNull);
      expect(todo!.id, '102');
      expect(todo.header, 'Finished task');
      expect(todo.body, isEmpty);
      expect(todo.status, 'done');
      expect(todo.isDone, isTrue);
      expect(todo.priority, 0);
      expect(todo.finishedDate, '2026-08-28T09:30:00.000Z');
    });

    test('returns null for pull requests', () {
      final prJson = {
        'number': 103,
        'title': 'PR: Update dependencies',
        'body': 'Bump versions',
        'state': 'open',
        'pull_request': {
          'url': 'https://api.github.com/repos/owner/repo/pulls/103',
        },
      };

      final todo = IssueMetaCodec.fromGitHubIssue(prJson);
      expect(todo, isNull);
    });

    test('returns null for deleted issues', () {
      final deletedIssueJson = {
        'number': 104,
        'title': 'Deleted task',
        'body': '<!-- todo-meta: {"priority":1,"deleted":true} -->',
        'state': 'closed',
        'created_at': '2026-08-28T07:00:00Z',
        'closed_at': '2026-08-28T07:05:00Z',
      };

      final todo = IssueMetaCodec.fromGitHubIssue(deletedIssueJson);
      expect(todo, isNull);
    });

    test('falls back to defaultPriority when metadata has no priority', () {
      final externalIssueJson = {
        'number': 105,
        'title': 'External Issue',
        'body': 'Just an issue with no metadata block',
        'state': 'open',
        'created_at': '2026-08-28T11:00:00Z',
      };

      final todo = IssueMetaCodec.fromGitHubIssue(
        externalIssueJson,
        defaultPriority: 42,
      );

      expect(todo, isNotNull);
      expect(todo!.priority, 42);
    });
  });
}
