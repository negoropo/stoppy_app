import 'package:http/http.dart' as http;

enum HttpMethod { get, post, put, patch, delete }

final class HttpTransportRequest {
  HttpTransportRequest({
    required this.method,
    required this.uri,
    Map<String, String> headers = const {},
    this.body,
  }) : headers = Map.unmodifiable(Map.of(headers));

  final HttpMethod method;
  final Uri uri;
  final Map<String, String> headers;
  final String? body;
}

final class HttpTransportResponse {
  HttpTransportResponse({
    required this.statusCode,
    required this.body,
    Map<String, String> headers = const {},
  }) : headers = Map.unmodifiable(Map.of(headers));

  final int statusCode;
  final String body;
  final Map<String, String> headers;
}

abstract interface class HttpTransport {
  Future<HttpTransportResponse> execute(HttpTransportRequest request);

  void close();
}

final class PackageHttpTransport implements HttpTransport {
  PackageHttpTransport({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  bool _isClosed = false;

  @override
  Future<HttpTransportResponse> execute(HttpTransportRequest request) async {
    if (_isClosed) {
      throw StateError('HttpTransport has already been closed.');
    }

    final packageRequest = http.Request(
      request.method.name.toUpperCase(),
      request.uri,
    )..headers.addAll(request.headers);

    final body = request.body;
    if (body != null) {
      packageRequest.body = body;
    }

    final streamedResponse = await _client.send(packageRequest);
    final response = await http.Response.fromStream(streamedResponse);

    return HttpTransportResponse(
      statusCode: response.statusCode,
      body: response.body,
      headers: response.headers,
    );
  }

  @override
  void close() {
    if (_isClosed) {
      return;
    }

    _isClosed = true;

    if (_ownsClient) {
      _client.close();
    }
  }
}
