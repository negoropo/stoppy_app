import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_contract.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/auth_session.dart';
import 'package:stoppy_app/core/backend/backend_api_client_config.dart';
import 'package:stoppy_app/core/backend/http_backend_api_client.dart';
import 'package:stoppy_app/core/backend/http_transport.dart';

void main() {
  group('HttpBackendApiClient', () {
    test(
      'builds GET URI with query parameters for base URL without slash',
          () async {
        final transport = _FakeTransport.success();
        final client = _client(transport: transport);
        final queryParameters = <String, String>{
          'division': '2',
          'playerId': 'player 1',
        };

        await client.get(
          '/api/v1/league/snapshot',
          queryParameters: queryParameters,
        );

        expect(
          transport.requests.single.uri.toString(),
          'https://api.stoppy.test/api/v1/league/snapshot?division=2&playerId=player+1',
        );
        expect(queryParameters, {
          'division': '2',
          'playerId': 'player 1',
        });
      },
    );

    test('resolves path with a trailing slash base URL', () async {
      final transport = _FakeTransport.success();
      final client = _client(
        transport: transport,
        baseUrl: 'https://api.stoppy.test/',
      );

      await client.get(ApiContract.playerProfile);

      expect(
        transport.requests.single.uri.toString(),
        'https://api.stoppy.test/api/v1/player/profile',
      );
    });

    test('encodes POST JSON bodies without mutating caller maps', () async {
      final transport = _FakeTransport.success();
      final client = _client(transport: transport);
      final body = <String, Object?>{
        'username': 'Tester',
        'nested': {'v': 1},
      };

      await client.post(
        ApiContract.authLogin,
        body: body,
      );

      expect(
        jsonDecode(transport.requests.single.body!),
        body,
      );
      expect(body, {
        'username': 'Tester',
        'nested': {'v': 1},
      });
      expect(
        transport.requests.single.headers[ApiContract.contentTypeHeader],
        ApiContract.jsonContentType,
      );
    });

    test('forwards PUT PATCH and DELETE through the transport', () async {
      final transport = _FakeTransport.success();
      final client = _client(transport: transport);

      await client.put(
        '/api/v1/resource',
        body: {'value': 1},
      );
      await client.patch(
        '/api/v1/resource',
        body: {'value': 2},
      );
      await client.delete(
        '/api/v1/resource',
        queryParameters: {'force': '1'},
      );

      expect(
        transport.requests.map((request) => request.method),
        [
          HttpMethod.put,
          HttpMethod.patch,
          HttpMethod.delete,
        ],
      );
      expect(
        transport.requests.last.uri.queryParameters['force'],
        '1',
      );
      expect(
        transport.requests.last.body,
        isNull,
      );
    });

    test(
      'merges custom headers while preserving required JSON headers',
          () async {
        final transport = _FakeTransport.success();
        final store = InMemoryAuthSessionStore();
        await store.save(_validSession());

        final client = _client(
          transport: transport,
          sessionStore: store,
        );

        final headers = <String, String>{
          'X-Request-Id': 'request-1',
          'Accept': 'text/plain',
          'authorization': 'Caller token',
        };

        await client.post(
          '/api/v1/private',
          body: const {},
          headers: headers,
        );

        final sentHeaders = transport.requests.single.headers;

        expect(
          sentHeaders['X-Request-Id'],
          'request-1',
        );
        expect(
          sentHeaders[ApiContract.acceptHeader],
          ApiContract.jsonContentType,
        );
        expect(
          sentHeaders[ApiContract.authorizationHeader],
          'Bearer access-token',
        );

        expect(
          headers['Accept'],
          'text/plain',
        );
        expect(
          headers['authorization'],
          'Caller token',
        );
      },
    );

    test('does not add authorization without a session', () async {
      final transport = _FakeTransport.success();
      final client = _client(transport: transport);

      await client.get('/api/v1/private');

      expect(
        transport.requests.single.headers.containsKey(
          ApiContract.authorizationHeader,
        ),
        isFalse,
      );
    });

    test(
      'does not add authorization for expired or public auth requests',
          () async {
        final transport = _FakeTransport.success();
        final store = InMemoryAuthSessionStore();

        await store.save(
          AuthSession(
            accessToken: 'expired-token',
            expiresAt: DateTime.utc(2026, 6, 22, 9),
          ),
        );

        final client = _client(
          transport: transport,
          sessionStore: store,
          now: _fixedNow,
        );

        await client.get('/api/v1/private');

        await store.save(_validSession());

        await client.post(
          ApiContract.authLogin,
          body: const {},
        );

        expect(
          transport.requests.every(
                (request) =>
            !request.headers.containsKey(
              ApiContract.authorizationHeader,
            ),
          ),
          isTrue,
        );
      },
    );

    test('decodes successful 200 and non-200 2xx envelopes', () async {
      final transport = _FakeTransport.sequence([
        HttpTransportResponse(
          statusCode: 200,
          body: '{"success":true,"data":{"id":"get"}}',
        ),
        HttpTransportResponse(
          statusCode: 201,
          body: '{"success":true,"data":{"id":"post"}}',
        ),
      ]);

      final client = _client(transport: transport);

      final first = await client.get('/api/v1/one');
      final second = await client.post('/api/v1/two');

      expect(
        first.requireData()['id'],
        'get',
      );
      expect(
        second.requireData()['id'],
        'post',
      );
    });

    test('represents empty 204 responses as an empty success map', () async {
      final client = _client(
        transport: _FakeTransport(
              (_) async => HttpTransportResponse(
            statusCode: 204,
            body: '',
          ),
        ),
      );

      final response = await client.delete('/api/v1/resource');

      expect(
        response.isSuccess,
        isTrue,
      );
      expect(
        response.requireData(),
        isEmpty,
      );
    });

    test('represents empty 205 responses as an empty success map', () async {
      final client = _client(
        transport: _FakeTransport(
              (_) async => HttpTransportResponse(
            statusCode: 205,
            body: '',
          ),
        ),
      );

      final response = await client.post('/api/v1/reset');

      expect(
        response.isSuccess,
        isTrue,
      );
      expect(
        response.requireData(),
        isEmpty,
      );
    });

    test('rejects an empty 200 response as malformed payload', () async {
      final client = _client(
        transport: _FakeTransport(
              (_) async => HttpTransportResponse(
            statusCode: 200,
            body: '',
          ),
        ),
      );

      final response = await client.get('/api/v1/resource');

      expect(
        response.isSuccess,
        isFalse,
      );
      expect(
        response.error?.code,
        ApiErrorCode.malformedPayload,
      );
      expect(
        response.error?.details['httpStatus'],
        200,
      );
    });

    test(
      'preserves backend failure envelopes and validation details',
          () async {
        final client = _client(
          transport: _FakeTransport(
                (_) async => HttpTransportResponse(
              statusCode: 422,
              body: jsonEncode({
                'success': false,
                'error': {
                  'code': 'validationFailed',
                  'message': 'Invalid run.',
                  'details': {
                    'field': 'score',
                  },
                },
              }),
            ),
          ),
        );

        final response = await client.post('/api/v1/runs/league');

        expect(
          response.error?.code,
          ApiErrorCode.validationFailed,
        );
        expect(
          response.error?.details['field'],
          'score',
        );
        expect(
          response.error?.details['httpStatus'],
          422,
        );
      },
    );

    test('maps malformed success JSON and non-JSON errors safely', () async {
      final transport = _FakeTransport.sequence([
        HttpTransportResponse(
          statusCode: 200,
          body: '{not-json',
        ),
        HttpTransportResponse(
          statusCode: 500,
          body: 'Internal server error',
        ),
      ]);

      final client = _client(transport: transport);

      final malformed = await client.get('/api/v1/one');
      final serverError = await client.get('/api/v1/two');

      expect(
        malformed.error?.code,
        ApiErrorCode.malformedPayload,
      );
      expect(
        serverError.error?.code,
        ApiErrorCode.serverError,
      );
    });

    test('maps invalid success data types to malformed payload', () async {
      final client = _client(
        transport: _FakeTransport(
              (_) async => HttpTransportResponse(
            statusCode: 200,
            body: '{"success":true,"data":["invalid"]}',
          ),
        ),
      );

      final response = await client.get('/api/v1/resource');

      expect(
        response.error?.code,
        ApiErrorCode.malformedPayload,
      );
    });

    test('maps HTTP status codes to typed API errors', () async {
      const statuses = <int, ApiErrorCode>{
        401: ApiErrorCode.unauthenticated,
        403: ApiErrorCode.forbidden,
        404: ApiErrorCode.notFound,
        409: ApiErrorCode.conflict,
        422: ApiErrorCode.validationFailed,
        429: ApiErrorCode.rateLimited,
        503: ApiErrorCode.serverError,
        418: ApiErrorCode.unexpectedResponse,
      };

      final transport = _FakeTransport.sequence(
        statuses.keys
            .map(
              (status) => HttpTransportResponse(
            statusCode: status,
            body: '',
          ),
        )
            .toList(),
      );

      final client = _client(transport: transport);

      for (final expected in statuses.values) {
        final response = await client.get('/api/v1/status');

        expect(
          response.error?.code,
          expected,
        );
      }
    });

    test(
      'maps timeout and transport exceptions without exposing transport types',
          () async {
        final timeoutClient = _client(
          transport: _FakeTransport(
                (_) => Completer<HttpTransportResponse>().future,
          ),
          timeout: const Duration(milliseconds: 1),
        );

        final networkClient = _client(
          transport: _FakeTransport(
                (_) => throw StateError('offline'),
          ),
        );

        final timedOut = await timeoutClient.get('/api/v1/slow');
        final unavailable = await networkClient.get('/api/v1/offline');

        expect(
          timedOut.error?.code,
          ApiErrorCode.requestTimeout,
        );
        expect(
          unavailable.error?.code,
          ApiErrorCode.networkUnavailable,
        );
      },
    );

    test('rejects malformed and non-HTTP backend base URLs', () {
      expect(
            () => _client(
          transport: _FakeTransport.success(),
          baseUrl: 'not a URL',
        ),
        throwsA(isA<BackendConfigurationException>()),
      );

      expect(
            () => _client(
          transport: _FakeTransport.success(),
          baseUrl: 'ftp://api.stoppy.test',
        ),
        throwsA(isA<BackendConfigurationException>()),
      );
    });

    test(
      'rejects backend base URLs with query fragment or credentials',
          () {
        const invalidUrls = <String>[
          'https://api.stoppy.test?environment=test',
          'https://api.stoppy.test#backend',
          'https://user:password@api.stoppy.test',
        ];

        for (final baseUrl in invalidUrls) {
          expect(
                () => _client(
              transport: _FakeTransport.success(),
              baseUrl: baseUrl,
            ),
            throwsA(isA<BackendConfigurationException>()),
          );
        }
      },
    );
  });
}

HttpBackendApiClient _client({
  required HttpTransport transport,
  String baseUrl = 'https://api.stoppy.test',
  Duration timeout = const Duration(seconds: 1),
  AuthSessionStore? sessionStore,
  DateTime Function()? now,
}) {
  return HttpBackendApiClient(
    config: BackendConfig(
      baseUrl: baseUrl,
      timeout: timeout,
    ),
    transport: transport,
    authSessionStore: sessionStore ?? InMemoryAuthSessionStore(),
    now: now ?? _fixedNow,
  );
}

DateTime _fixedNow() {
  return DateTime.utc(2026, 6, 22, 10);
}

AuthSession _validSession() {
  return AuthSession(
    accessToken: 'access-token',
    expiresAt: DateTime.utc(2026, 6, 23),
  );
}

final class _FakeTransport implements HttpTransport {
  _FakeTransport(this._handler);

  factory _FakeTransport.success() {
    return _FakeTransport(
          (_) async => HttpTransportResponse(
        statusCode: 200,
        body: '{"success":true,"data":{}}',
      ),
    );
  }

  factory _FakeTransport.sequence(
      List<HttpTransportResponse> responses,
      ) {
    var index = 0;

    return _FakeTransport((_) async {
      if (index >= responses.length) {
        throw StateError('No fake HTTP response remaining.');
      }

      return responses[index++];
    });
  }

  final Future<HttpTransportResponse> Function(
      HttpTransportRequest request,
      )
  _handler;

  final List<HttpTransportRequest> requests = [];

  bool isClosed = false;

  @override
  Future<HttpTransportResponse> execute(
      HttpTransportRequest request,
      ) {
    if (isClosed) {
      throw StateError('Fake transport has already been closed.');
    }

    requests.add(request);
    return _handler(request);
  }

  @override
  void close() {
    isClosed = true;
  }
}