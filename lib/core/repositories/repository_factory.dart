import '../../features/ads/data/mock_ad_repository.dart';
import '../../features/auth/data/backend/backend_auth_repository.dart';
import '../../features/auth/data/mock_auth_repository.dart';
import '../../features/knockout/data/backend/backend_knockout_repository.dart';
import '../../features/knockout/data/mock_knockout_repository.dart';
import '../../features/league/data/backend/backend_league_repository.dart';
import '../../features/league/data/mock_league_repository.dart';
import '../../features/purchases/data/mock_purchase_repository.dart';
import '../backend/auth_session.dart';
import '../backend/backend_api_client.dart';
import '../backend/backend_api_client_config.dart';
import '../backend/http_backend_api_client.dart';
import '../backend/http_transport.dart';
import '../backend/secure_auth_session_store.dart';
import '../config/app_environment.dart';
import 'app_repositories.dart';

final class RepositoryFactory {
const RepositoryFactory({
required this.environment,
this.backendApiClient,
this.authSessionStore,
this.httpTransport,
});

final AppEnvironment environment;
final BackendApiClient? backendApiClient;
final AuthSessionStore? authSessionStore;
final HttpTransport? httpTransport;

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
_validateBackendDependencies();

// Backend runtime persists only the server-issued session in platform
// secure storage. Mock runtime never constructs or touches this adapter.
final sessionStore =
authSessionStore ??
SecureAuthSessionStore(
secureStorage: FlutterSecureKeyValueStore(),
);

// A generated HTTP client and the authentication repository must share
// exactly the same session store. This allows login, registration, and
// refresh operations to persist the credential that the HTTP client later
// sends as a Bearer token.
//
// When a custom BackendApiClient is injected, the caller must also inject
// the matching AuthSessionStore used by that client.
final client =
backendApiClient ??
_createBackendApiClient(
sessionStore,
);

// Purchases and ads remain mock-driven until their real IAP and backend
// integration boundaries are implemented.
return AppRepositories(
authRepository: BackendAuthRepository(
apiClient: client,
authSessionStore: sessionStore,
),
purchaseRepository: const MockPurchaseRepository(),
adRepository: MockAdRepository(),
leagueRepository: BackendLeagueRepository(
apiClient: client,
),
knockoutRepository: BackendKnockoutRepository(
apiClient: client,
),
);
}

void _validateBackendDependencies() {
if (backendApiClient != null && authSessionStore == null) {
throw StateError(
'An injected BackendApiClient requires the matching '
'AuthSessionStore when using the backend repository runtime.',
);
}

if (backendApiClient != null && httpTransport != null) {
throw StateError(
'HttpTransport cannot be injected together with BackendApiClient '
'because the custom client already owns its transport.',
);
}
}

BackendApiClient _createBackendApiClient(
AuthSessionStore sessionStore,
) {
return HttpBackendApiClient(
config: BackendConfig(
baseUrl: environment.apiBaseUrl,
),
transport: httpTransport ?? PackageHttpTransport(),
authSessionStore: sessionStore,
);
}
}