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