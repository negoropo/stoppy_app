import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/api_response.dart';
import 'package:stoppy_app/core/backend/backend_api_client.dart';
import 'package:stoppy_app/features/auth/data/backend/backend_auth_repository.dart';

void main() {
  group('BackendAuthRepository', () {
    test('remains explicitly disconnected', () {
      final repository = BackendAuthRepository(
        apiClient: _FakeBackendApiClient(),
      );

      expect(
        repository.currentAuthState,
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

final class _FakeBackendApiClient implements BackendApiClient {
  @override
  Future<ApiResponse<Map<String, Object?>>> get(
      String path, {
        Map<String, String> queryParameters = const {},
        Map<String, String> headers = const {},
      }) async {
    return const ApiResponse.success(<String, Object?>{});
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> post(
      String path, {
        Map<String, Object?> body = const {},
        Map<String, String> headers = const {},
      }) async {
    return const ApiResponse.success(<String, Object?>{});
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> put(
      String path, {
        Map<String, Object?> body = const {},
        Map<String, String> headers = const {},
      }) async {
    return const ApiResponse.success(<String, Object?>{});
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> patch(
      String path, {
        Map<String, Object?> body = const {},
        Map<String, String> headers = const {},
      }) async {
    return const ApiResponse.success(<String, Object?>{});
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> delete(
      String path, {
        Map<String, String> queryParameters = const {},
        Map<String, String> headers = const {},
      }) async {
    return const ApiResponse.success(<String, Object?>{});
  }
}