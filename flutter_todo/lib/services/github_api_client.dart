import 'dart:convert';
import 'package:http/http.dart' as http;

/// Base exception for all GitHub API client errors.
class GitHubApiException implements Exception {
  const GitHubApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => statusCode != null
      ? 'GitHubApiException ($statusCode): $message'
      : 'GitHubApiException: $message';
}

/// Thrown when authentication fails (HTTP 401) or permissions are denied (HTTP 403 without rate limit).
class GitHubAuthException extends GitHubApiException {
  const GitHubAuthException(super.message, {super.statusCode});
}

/// Thrown when a repository or issue resource is not found (HTTP 404).
class GitHubNotFoundException extends GitHubApiException {
  const GitHubNotFoundException(super.message, {super.statusCode});
}

/// Thrown when GitHub rate limit is exceeded (HTTP 403 with X-RateLimit-Remaining: 0).
class GitHubRateLimitException extends GitHubApiException {
  const GitHubRateLimitException(
    super.message, {
    this.resetTime,
    super.statusCode,
  });

  final DateTime? resetTime;
}

/// Thrown when request validation fails (HTTP 422).
class GitHubValidationException extends GitHubApiException {
  const GitHubValidationException(super.message, {super.statusCode});
}

/// Thrown when network transport fails (e.g. offline, DNS resolution failure).
class GitHubNetworkException extends GitHubApiException {
  const GitHubNetworkException(super.message, {this.cause});

  final Object? cause;
}

/// GitHub REST API client for managing issues.
///
/// Accepts an optional [http.Client] to enable instant, mockable testing.
class GitHubApiClient {
  GitHubApiClient({
    this.baseUrl = 'https://api.github.com',
    this.token,
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  final String baseUrl;
  final String? token;
  final http.Client _client;

  static const defaultPageSize = 100;

  Map<String, String> get _headers => {
    'Accept': 'application/vnd.github+json',
    'Content-Type': 'application/json',
    'X-GitHub-Api-Version': '2022-11-28',
    if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Uri _buildUri(String path, [Map<String, String>? queryParameters]) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      path: path.startsWith('/') ? path : '/$path',
      queryParameters: queryParameters,
    );
  }

  void _handleErrorResponse(http.Response response) {
    final status = response.statusCode;
    String message;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded.containsKey('message')) {
        message = decoded['message'] as String;
      } else {
        message = response.body;
      }
    } catch (_) {
      message = response.body.isNotEmpty ? response.body : 'HTTP Error $status';
    }

    if (status == 401) {
      throw GitHubAuthException(
        'Invalid or missing GitHub token: $message',
        statusCode: status,
      );
    }

    if (status == 403) {
      final rateLimitRemaining = response.headers['x-ratelimit-remaining'];
      if (rateLimitRemaining == '0') {
        final resetTimestampStr = response.headers['x-ratelimit-reset'];
        DateTime? resetTime;
        if (resetTimestampStr != null) {
          final epochSec = int.tryParse(resetTimestampStr);
          if (epochSec != null) {
            resetTime = DateTime.fromMillisecondsSinceEpoch(
              epochSec * 1000,
              isUtc: true,
            );
          }
        }
        throw GitHubRateLimitException(
          'GitHub API rate limit exceeded. $message',
          resetTime: resetTime,
          statusCode: status,
        );
      }
      throw GitHubAuthException(
        'Access forbidden: $message',
        statusCode: status,
      );
    }

    if (status == 404) {
      throw GitHubNotFoundException(
        'Resource not found: $message',
        statusCode: status,
      );
    }

    if (status == 422) {
      throw GitHubValidationException(
        'Validation failed: $message',
        statusCode: status,
      );
    }

    throw GitHubApiException('GitHub API error: $message', statusCode: status);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? queryParams,
    Object? body,
  }) async {
    final uri = _buildUri(path, queryParams);
    http.Response response;

    try {
      final encodedBody = body != null ? jsonEncode(body) : null;
      switch (method.toUpperCase()) {
        case 'GET':
          response = await _client.get(uri, headers: _headers);
          break;
        case 'POST':
          response = await _client.post(
            uri,
            headers: _headers,
            body: encodedBody,
          );
          break;
        case 'PATCH':
          response = await _client.patch(
            uri,
            headers: _headers,
            body: encodedBody,
          );
          break;
        case 'DELETE':
          response = await _client.delete(
            uri,
            headers: _headers,
            body: encodedBody,
          );
          break;
        default:
          throw ArgumentError('Unsupported HTTP method: $method');
      }
    } on http.ClientException catch (e) {
      throw GitHubNetworkException(
        'Network error during request to $uri: ${e.message}',
        cause: e,
      );
    } catch (e) {
      if (e is GitHubApiException) rethrow;
      throw GitHubNetworkException(
        'Failed to communicate with GitHub API: $e',
        cause: e,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _handleErrorResponse(response);
    }

    if (response.body.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(response.body);
    } catch (e) {
      throw GitHubApiException('Failed to decode GitHub API JSON response: $e');
    }
  }

  /// Tests access to [repo] (e.g. `owner/repo`).
  Future<Map<String, dynamic>> testConnection(String repo) async {
    final result = await _request('GET', '/repos/$repo');
    return result as Map<String, dynamic>;
  }

  /// Lists all issues for [repo] with pagination, filtering out pull requests.
  Future<List<Map<String, dynamic>>> listIssues(
    String repo, {
    String state = 'all',
    int perPage = defaultPageSize,
  }) async {
    var page = 1;
    final allIssues = <Map<String, dynamic>>[];

    while (true) {
      final result = await _request(
        'GET',
        '/repos/$repo/issues',
        queryParams: {
          'state': state,
          'per_page': perPage.toString(),
          'page': page.toString(),
        },
      );

      if (result is! List) break;
      final chunk = result.cast<Map<String, dynamic>>();
      if (chunk.isEmpty) break;

      allIssues.addAll(chunk);

      if (chunk.length < perPage) break;
      page++;
    }

    return allIssues
        .where(
          (issue) =>
              !issue.containsKey('pull_request') ||
              issue['pull_request'] == null,
        )
        .toList();
  }

  /// Creates a new issue in [repo].
  Future<Map<String, dynamic>> createIssue(
    String repo, {
    required String title,
    required String body,
  }) async {
    final result = await _request(
      'POST',
      '/repos/$repo/issues',
      body: {'title': title, 'body': body},
    );
    return result as Map<String, dynamic>;
  }

  /// Updates an issue in [repo] identified by [issueNumber].
  Future<Map<String, dynamic>> patchIssue(
    String repo,
    int issueNumber,
    Map<String, dynamic> payload,
  ) async {
    final result = await _request(
      'PATCH',
      '/repos/$repo/issues/$issueNumber',
      body: payload,
    );
    return result as Map<String, dynamic>;
  }
}
