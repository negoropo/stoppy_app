import '../backend/auth_session.dart';
import '../backend/backend_api_client.dart';
import '../backend/backend_api_client_config.dart';
import '../backend/pending_backend_api_client.dart';
import '../config/app_environment.dart';
import '../../features/ads/data/mock_ad_repository.dart';
import '../../features/auth/data/backend/backend_auth_repository.dart';
import '../../features/auth/data/mock_auth_repository.dart';
import '../../features/knockout/data/backend/backend_knockout_repository.dart';
import '../../features/knockout/data/mock_knockout_repository.dart';
import '../../features/league/data/backend/backend_league_repository.dart';
import '../../features/league/data/mock_league_repository.dart';
import '../../features/purchases/data/mock_purchase_repository.dart';
import 'app_repositories.dart';

class RepositoryFactory {
  const RepositoryFactory({
    required this.environment,
    this.backendApiClient,
    this.authSessionStore,
  });

  final AppEnvironment environment;
  final BackendApiClient? backendApiClient;
  final AuthSessionStore? authSessionStore;

  AppRepositories createRepositories() {
    return switch (environment.repositoryRuntime) {
      RepositoryRuntime.mock => _createMockRepositories(),
      RepositoryRuntime.backend => _createBackendRepositories(),
    };
  }

  AppRepositories _createMockRepositories() {
    return AppRepositories(
      authRepository: MockAuthRepository(),
      purchaseRepository: const MockPurchaseRepository(),
      adRepository: MockAdRepository(),
      leagueRepository: MockLeagueRepository(),
      knockoutRepository: MockKnockoutRepository(),
    );
  }

  AppRepositories _createBackendRepositories() {
    final sessionStore = authSessionStore ?? InMemoryAuthSessionStore();

    final client =
        backendApiClient ??
            PendingBackendApiClient(
              config: BackendApiClientConfig(baseUrl: environment.apiBaseUrl),
              authSessionStore: sessionStore,
            );

    // Purchases and ads still use mock repositories because their backend/IAP
    // boundaries are not part of this session. Competitive repositories can be
    // switched to backend skeletons through the same composition root.
    return AppRepositories(
      authRepository: BackendAuthRepository(apiClient: client),
      purchaseRepository: const MockPurchaseRepository(),
      adRepository: MockAdRepository(),
      leagueRepository: BackendLeagueRepository(apiClient: client),
      knockoutRepository: BackendKnockoutRepository(apiClient: client),
    );
  }
}
