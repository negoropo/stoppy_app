import 'package:stoppy_app/core/backend/api_contract.dart';
import 'package:stoppy_app/core/backend/backend_api_client.dart';
import 'package:stoppy_app/core/backend/backend_repository_not_configured.dart';

import '../../domain/models/auth_state.dart';
import '../../domain/models/player_profile.dart';
import '../../domain/repositories/auth_repository.dart';

final class BackendAuthRepository implements AuthRepository {
  const BackendAuthRepository({
    required this.apiClient,
  });

  final BackendApiClient apiClient;

  static const registerPath = ApiContract.authRegister;
  static const loginPath = ApiContract.authLogin;
  static const profilePath = ApiContract.playerProfile;

  @override
  Future<AuthState> currentAuthState() {
    return backendNotConnected(
      'BackendAuthRepository',
      'currentAuthState',
    );
  }

  @override
  Future<PlayerProfile> register({
    required String username,
    required String password,
  }) {
    return backendNotConnected(
      'BackendAuthRepository',
      'register',
    );
  }

  @override
  Future<PlayerProfile> login({
    required String username,
    required String password,
  }) {
    return backendNotConnected(
      'BackendAuthRepository',
      'login',
    );
  }

  @override
  Future<PlayerProfile> updatePlayerProfile(
      PlayerProfile playerProfile,
      ) {
    return backendNotConnected(
      'BackendAuthRepository',
      'updatePlayerProfile',
    );
  }

  @override
  Future<void> logout() {
    return backendNotConnected(
      'BackendAuthRepository',
      'logout',
    );
  }
}