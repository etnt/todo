import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Hand-rolled fake HTTP client (no mockito): records every request and
/// returns canned responses produced by [handler].
class FakeClient extends http.BaseClient {
  FakeClient(this.handler);

  final http.Response Function(http.BaseRequest request) handler;

  /// All requests that passed through this client, in order.
  final List<http.BaseRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final response = handler(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }

  /// Convenience accessor: decoded JSON body of the i-th recorded request.
  dynamic jsonBodyOf(int index) =>
      jsonDecode((requests[index] as http.Request).body);
}
