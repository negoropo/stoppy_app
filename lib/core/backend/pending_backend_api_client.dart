import 'api_error.dart';
import 'api_response.dart';
import 'backend_api_client.dart';
import 'backend_api_client_config.dart';
import 'auth_session.dart';

class PendingBackendApiClient implements BackendApiClient {
  const PendingBackendApiClient({
    required this.config,
    required this.authSessionStore,
  });

  final BackendApiClientConfig config;
  final AuthSessionStore authSessionStore;

  @override
  Future<ApiResponse<Map<String, Object?>>> get(
      String path, {
        Map<String, String> queryParameters = const {},
      }) {
    return _notImplemented('GET', path);
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> post(
      String path, {
        Map<String, Object?> body = const {},
      }) {
    return _notImplemented('POST', path);
  }

  Future<ApiResponse<Map<String, Object?>>> _notImplemented(
      String method,
      String path,
      ) async {
    // Future implementation will use the current authenticated session
    // to attach authorization headers before performing HTTP requests.
    await authSessionStore.read();

    throw ApiException(
      ApiError(
        code: ApiErrorCode.notImplemented,
        message:
        'BackendApiClient is not connected yet for $method $path. '
            'This placeholder preserves the repository boundary until real '
            'networking is added.',
        details: {
          'baseUrl': config.baseUrl,
        },
      ),
    );
  }
}