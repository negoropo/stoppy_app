import 'package:stoppy_app/core/backend/backend_api_client.dart';
import 'package:stoppy_app/core/backend/backend_repository_not_configured.dart';

import '../../domain/models/auth_state.dart';
import '../../domain/models/player_profile.dart';
import '../../domain/repositories/auth_repository.dart';

class BackendAuthRepository implements AuthRepository {
  const BackendAuthRepository({this.apiClient});

  final BackendApiClient? apiClient;

  static const registerPath = '/auth/register';
  static const loginPath = '/auth/login';
  static const profilePath = '/player/profile';

  BackendApiClient get _client {
    final client = apiClient;
    if (client == null) {
      return backendNotConnected('BackendAuthRepository', 'apiClient');
    }
    return client;
  }

  @override
  Future<AuthState> currentAuthState() {
    final _ = _client;
    return backendNotConnected('BackendAuthRepository', 'currentAuthState');
  }

  @override
  Future<PlayerProfile> register({
    required String username,
    required String password,
  }) {
    final _ = _client;
    return backendNotConnected('BackendAuthRepository', 'register');
  }

  @override
  Future<PlayerProfile> login({
    required String username,
    required String password,
  }) {
    final _ = _client;
    return backendNotConnected('BackendAuthRepository', 'login');
  }

  @override
  Future<PlayerProfile> updatePlayerProfile(PlayerProfile playerProfile) {
    final _ = _client;
    return backendNotConnected('BackendAuthRepository', 'updatePlayerProfile');
  }

  @override
  Future<void> logout() {
    final _ = _client;
    return backendNotConnected('BackendAuthRepository', 'logout');
  }
}