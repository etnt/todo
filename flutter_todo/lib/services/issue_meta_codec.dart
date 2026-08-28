import 'dart:convert';

import '../models/todo.dart';

/// Metadata embedded inside a GitHub issue's body.
class IssueMetadata {
  const IssueMetadata({
    this.priority,
    this.deleted = false,
  });

  /// The custom priority ordering index, or null if unassigned.
  final int? priority;

  /// Whether the todo item was soft-deleted.
  final bool deleted;

  Map<String, dynamic> toJson() => {
        if (priority != null) 'priority': priority,
        if (deleted) 'deleted': deleted,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IssueMetadata &&
          runtimeType == other.runtimeType &&
          priority == other.priority &&
          deleted == other.deleted;

  @override
  int get hashCode => priority.hashCode ^ deleted.hashCode;

  @override
  String toString() => 'IssueMetadata(priority: $priority, deleted: $deleted)';
}

/// Codec to encode and decode hidden TODO metadata into/from GitHub issue body strings.
///
/// Ensures 100% bidirectional interoperability with the Python `TodoManager` implementation:
/// Hidden comment format: `<!-- todo-meta: {"priority":0,"deleted":false} -->`
class IssueMetaCodec {
  static const marker = '<!-- todo-meta:';
  static const endMarker = '-->';

  /// Encodes [body] and [metadata] into a single issue body string.
  static String encode(String body, IssueMetadata metadata) {
    final metaMap = <String, dynamic>{
      'priority': metadata.priority ?? 0,
      'deleted': metadata.deleted,
    };
    final jsonStr = jsonEncode(metaMap);
    final comment = '$marker $jsonStr $endMarker';

    final trimmedBody = body.trimRight();
    if (trimmedBody.isNotEmpty) {
      return '$trimmedBody\n\n$comment';
    }
    return comment;
  }

  /// Parses an issue body into clean body text and [IssueMetadata].
  ///
  /// Searches for the last occurrence of `<!-- todo-meta:` to support nested comments safely.
  static ({String body, IssueMetadata metadata}) decode(String rawBody) {
    final markerIdx = rawBody.lastIndexOf(marker);
    if (markerIdx == -1) {
      return (body: rawBody, metadata: const IssueMetadata());
    }

    final metadataPart = rawBody.substring(markerIdx + marker.length);
    final endMarkerIdx = metadataPart.indexOf(endMarker);
    if (endMarkerIdx == -1) {
      return (body: rawBody, metadata: const IssueMetadata());
    }

    final rawMetadata = metadataPart.substring(0, endMarkerIdx).trim();
    int? priority;
    var deleted = false;

    if (rawMetadata.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawMetadata);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('priority')) {
            final p = decoded['priority'];
            if (p is num) {
              priority = p.toInt();
            } else if (p is String) {
              priority = int.tryParse(p);
            }
          }
          if (decoded['deleted'] == true) {
            deleted = true;
          }
        }
      } catch (_) {
        // Malformed JSON: return raw body without metadata
        return (body: rawBody, metadata: const IssueMetadata());
      }
    }

    final cleanBody = rawBody.substring(0, markerIdx).trimRight();
    return (
      body: cleanBody,
      metadata: IssueMetadata(priority: priority, deleted: deleted),
    );
  }

  /// Normalizes ISO-8601 timestamps from GitHub API (e.g. converting trailing 'Z' to '+00:00').
  static String? normalizeTimestamp(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    try {
      final parsed = DateTime.parse(value);
      return parsed.toIso8601String();
    } catch (_) {
      return value;
    }
  }

  /// Converts a GitHub issue map into a [Todo] instance.
  ///
  /// Returns `null` if the issue is marked as deleted or is a Pull Request.
  static Todo? fromGitHubIssue(Map<String, dynamic> issue, {int defaultPriority = 0}) {
    // Filter out pull requests
    if (issue.containsKey('pull_request') && issue['pull_request'] != null) {
      return null;
    }

    final rawBody = issue['body'] as String? ?? '';
    final decoded = decode(rawBody);

    if (decoded.metadata.deleted) {
      return null;
    }

    final state = issue['state'] as String? ?? 'open';
    final status = state == 'closed' ? 'done' : 'active';
    final createdDate = normalizeTimestamp(issue['created_at'] as String?);
    final finishedDate = normalizeTimestamp(issue['closed_at'] as String?);
    final priority = decoded.metadata.priority ?? defaultPriority;

    return Todo(
      id: issue['number']?.toString(),
      header: issue['title'] as String? ?? '',
      body: decoded.body,
      createdDate: createdDate,
      finishedDate: finishedDate,
      status: status,
      priority: priority,
    );
  }
}
