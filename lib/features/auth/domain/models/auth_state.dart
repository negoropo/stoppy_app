import 'player_profile.dart';

enum AuthStatus { unauthenticated, loading, authenticated, error }

class AuthState {
  const AuthState({
    required this.status,
    this.playerProfile,
    this.errorMessage,
  });

  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);

  const AuthState.loading() : this(status: AuthStatus.loading);

  const AuthState.authenticated(PlayerProfile playerProfile)
    : this(status: AuthStatus.authenticated, playerProfile: playerProfile);

  const AuthState.error(String message)
    : this(status: AuthStatus.error, errorMessage: message);

  final AuthStatus status;
  final PlayerProfile? playerProfile;
  final String? errorMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated;
}
