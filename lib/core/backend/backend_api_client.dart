import 'api_response.dart';

abstract interface class BackendApiClient {
  Future<ApiResponse<Map<String, Object?>>> get(
    String path, {
    Map<String, String> queryParameters = const {},
    Map<String, String> headers = const {},
  });

  Future<ApiResponse<Map<String, Object?>>> post(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  });

  Future<ApiResponse<Map<String, Object?>>> put(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  });

  Future<ApiResponse<Map<String, Object?>>> patch(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  });

  Future<ApiResponse<Map<String, Object?>>> delete(
    String path, {
    Map<String, String> queryParameters = const {},
    Map<String, String> headers = const {},
  });
}

/// A transport that can refuse a mutation when its bearer belongs to a
/// different account than the one that owns the persisted attempt.
abstract interface class PlayerBoundBackendApiClient
    implements BackendApiClient {
  Future<ApiResponse<Map<String, Object?>>> postForPlayer(
    String path, {
    required String playerId,
    required Map<String, Object?> body,
    required Map<String, String> headers,
  });
}
