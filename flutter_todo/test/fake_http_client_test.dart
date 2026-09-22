import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fakes/fake_http_client.dart';

void main() {
  test('FakeClient records requests and returns canned responses', () async {
    final client = FakeClient((request) {
      if (request.method == 'GET' &&
          request.url.path.endsWith('/repos/owner/repo/issues')) {
        return http.Response(
          jsonEncode([
            {'number': 1, 'title': 'First'},
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('not found', 404);
    });

    final response = await client.get(
      Uri.parse('https://api.github.com/repos/owner/repo/issues'),
      headers: {'Authorization': 'Bearer test-token'},
    );

    expect(response.statusCode, 200);
    expect(jsonDecode(response.body), isA<List>());
    expect(client.requests, hasLength(1));
    expect(client.requests.first.method, 'GET');
    expect(client.requests.first.url.path, '/repos/owner/repo/issues');
    expect(client.requests.first.headers['Authorization'], 'Bearer test-token');
  });

  test('FakeClient jsonBodyOf decodes recorded request bodies', () async {
    final client = FakeClient((request) => http.Response('', 201));

    await client.post(
      Uri.parse('https://api.github.com/repos/owner/repo/issues'),
      body: jsonEncode({'title': 'Hello'}),
      headers: {'content-type': 'application/json'},
    );

    expect(client.requests, hasLength(1));
    expect(client.jsonBodyOf(0), {'title': 'Hello'});
  });
}
