import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_response.dart';
import 'package:stoppy_app/core/backend/backend_api_client.dart';
import 'package:stoppy_app/core/backend/http_backend_api_client.dart';
import 'package:stoppy_app/core/backend/http_transport.dart';
import 'package:stoppy_app/core/config/app_environment.dart';
import 'package:stoppy_app/core/repositories/repository_factory.dart';
import 'package:stoppy_app/features/ads/data/mock_ad_repository.dart';
import 'package:stoppy_app/features/auth/data/backend/backend_auth_repository.dart';
import 'package:stoppy_app/features/auth/data/mock_auth_repository.dart';
import 'package:stoppy_app/features/knockout/data/backend/backend_knockout_repository.dart';
import 'package:stoppy_app/features/knockout/data/mock_knockout_repository.dart';
import 'package:stoppy_app/features/league/data/backend/backend_league_repository.dart';
import 'package:stoppy_app/features/league/data/mock_league_repository.dart';
import 'package:stoppy_app/features/purchases/data/mock_purchase_repository.dart';

void main() {
  group('RepositoryFactory', () {
    test('uses mock repositories by default runtime', () {
      final repositories = const RepositoryFactory(
        environment: AppEnvironment.mock(),
      ).createRepositories();

      expect(repositories.authRepository, isA<MockAuthRepository>());
      expect(repositories.purchaseRepository, isA<MockPurchaseRepository>());
      expect(repositories.adRepository, isA<MockAdRepository>());
      expect(repositories.leagueRepository, isA<MockLeagueRepository>());
      expect(repositories.knockoutRepository, isA<MockKnockoutRepository>());
    });

    test('uses backend repositories when backend runtime is selected', () {
      final transport = _FakeTransport();

      final repositories = RepositoryFactory(
        environment: const AppEnvironment.backend(
          apiBaseUrl: 'https://api.test',
        ),
        httpTransport: transport,
      ).createRepositories();

      expect(repositories.authRepository, isA<BackendAuthRepository>());
      expect(repositories.purchaseRepository, isA<MockPurchaseRepository>());
      expect(repositories.adRepository, isA<MockAdRepository>());
      expect(repositories.leagueRepository, isA<BackendLeagueRepository>());
      expect(repositories.knockoutRepository, isA<BackendKnockoutRepository>());

      final authRepository =
      repositories.authRepository as BackendAuthRepository;

      expect(authRepository.apiClient, isA<HttpBackendApiClient>());
    });

    test('uses the injected backend API client for all backend repositories', () {
      final apiClient = _FakeBackendApiClient();

      final repositories = RepositoryFactory(
        environment: const AppEnvironment.backend(
          apiBaseUrl: 'https://api.test',
        ),
        backendApiClient: apiClient,
      ).createRepositories();

      final authRepository =
      repositories.authRepository as BackendAuthRepository;
      final leagueRepository =
      repositories.leagueRepository as BackendLeagueRepository;
      final knockoutRepository =
      repositories.knockoutRepository as BackendKnockoutRepository;

      expect(authRepository.apiClient, same(apiClient));
      expect(leagueRepository.apiClient, same(apiClient));
      expect(knockoutRepository.apiClient, same(apiClient));
    });

    test('mock runtime does not use injected backend dependencies', () {
      final apiClient = _FakeBackendApiClient();
      final transport = _FakeTransport();

      final repositories = RepositoryFactory(
        environment: const AppEnvironment.mock(),
        backendApiClient: apiClient,
        httpTransport: transport,
      ).createRepositories();

      expect(repositories.authRepository, isA<MockAuthRepository>());
      expect(repositories.leagueRepository, isA<MockLeagueRepository>());
      expect(repositories.knockoutRepository, isA<MockKnockoutRepository>());
      expect(transport.requests, isEmpty);
      expect(transport.isClosed, isFalse);
    });
  });
}

final class _FakeTransport implements HttpTransport {
  final List<HttpTransportRequest> requests = [];

  bool isClosed = false;

  @override
  Future<HttpTransportResponse> execute(
      HttpTransportRequest request,
      ) async {
    requests.add(request);

    return HttpTransportResponse(
      statusCode: 200,
      body: '{"success":true,"data":{}}',
    );
  }

  @override
  void close() {
    isClosed = true;
  }
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