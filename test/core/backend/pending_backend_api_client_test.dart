import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/auth_session.dart';
import 'package:stoppy_app/core/backend/backend_api_client_config.dart';
import 'package:stoppy_app/core/backend/pending_backend_api_client.dart';

void main() {
  group('PendingBackendApiClient', () {
    test('throws explicit not implemented error instead of networking', () {
      final client = PendingBackendApiClient(
        config: const BackendApiClientConfig(baseUrl: 'https://api.test'),
        authSessionStore: InMemoryAuthSessionStore(),
      );

      expect(
        () => client.get('/player/profile'),
        throwsA(
          isA<ApiException>().having(
            (exception) => exception.error.code,
            'code',
            ApiErrorCode.notImplemented,
          ),
        ),
      );
    });
  });
}
