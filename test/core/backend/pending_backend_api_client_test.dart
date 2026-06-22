import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/auth_session.dart';
import 'package:stoppy_app/core/backend/backend_api_client_config.dart';
import 'package:stoppy_app/core/backend/pending_backend_api_client.dart';

void main() {
  group('PendingBackendApiClient', () {
    test(
      'throws explicit not implemented error instead of networking',
          () async {
        final client = PendingBackendApiClient(
          config: const BackendConfig(
            baseUrl: 'https://api.test',
          ),
          authSessionStore: InMemoryAuthSessionStore(),
        );

        await expectLater(
          client.get('/player/profile'),
          throwsA(
            isA<ApiException>().having(
                  (exception) => exception.error.code,
              'code',
              ApiErrorCode.notImplemented,
            ),
          ),
        );
      },
    );

    test('all HTTP methods fail with not implemented error', () async {
      final client = PendingBackendApiClient(
        config: const BackendConfig(
          baseUrl: 'https://api.test',
        ),
        authSessionStore: InMemoryAuthSessionStore(),
      );

      final operations = <Future<Object?> Function()>[
            () => client.get('/test'),
            () => client.post('/test'),
            () => client.put('/test'),
            () => client.patch('/test'),
            () => client.delete('/test'),
      ];

      for (final operation in operations) {
        await expectLater(
          operation(),
          throwsA(
            isA<ApiException>().having(
                  (exception) => exception.error.code,
              'code',
              ApiErrorCode.notImplemented,
            ),
          ),
        );
      }
    });

  });
}