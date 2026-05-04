import '../models/auth_state.dart';
import '../models/player_profile.dart';

abstract class AuthRepository {
  Future<AuthState> currentAuthState();

  Future<PlayerProfile> register({
    required String username,
    required String password,
  });

  Future<PlayerProfile> login({
    required String username,
    required String password,
  });

  Future<PlayerProfile> updatePlayerProfile(PlayerProfile playerProfile);

  Future<void> logout();
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}
