import 'api_response.dart';
import 'auth_session.dart';
import 'backend_api_client.dart';
import 'backend_api_client_config.dart';
import 'backend_repository_not_configured.dart';

final class PendingBackendApiClient implements BackendApiClient {
  const PendingBackendApiClient({
    required this.config,
    required this.authSessionStore,
  });

  final BackendConfig config;
  final AuthSessionStore authSessionStore;

  @override
  Future<ApiResponse<Map<String, Object?>>> get(
    String path, {
    Map<String, String> queryParameters = const {},
    Map<String, String> headers = const {},
  }) {
    return backendNotConnected('PendingBackendApiClient', 'get');
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> post(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    return backendNotConnected('PendingBackendApiClient', 'post');
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> put(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    return backendNotConnected('PendingBackendApiClient', 'put');
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> patch(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    return backendNotConnected('PendingBackendApiClient', 'patch');
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> delete(
    String path, {
    Map<String, String> queryParameters = const {},
    Map<String, String> headers = const {},
  }) {
    return backendNotConnected('PendingBackendApiClient', 'delete');
  }
}
