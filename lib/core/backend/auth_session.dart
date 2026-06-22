class AuthSession {
  const AuthSession({
    required this.accessToken,
    this.refreshToken,
    required this.expiresAt,
  }) : assert(accessToken != '');

  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;

  bool isExpired(DateTime now) {
    return !expiresAt.isAfter(now);
  }

  bool isExpiringSoon(
      DateTime now, {
        Duration threshold = const Duration(minutes: 1),
      }) {
    assert(threshold >= Duration.zero);

    return !expiresAt.subtract(threshold).isAfter(now);
  }

  AuthSession copyWith({
    String? accessToken,
    Object? refreshToken = _unset,
    DateTime? expiresAt,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: identical(refreshToken, _unset)
          ? this.refreshToken
          : refreshToken as String?,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

abstract interface class AuthSessionStore {
  Future<AuthSession?> read();

  Future<void> save(AuthSession session);

  Future<void> clear();
}

final class InMemoryAuthSessionStore implements AuthSessionStore {
  AuthSession? _session;

  @override
  Future<AuthSession?> read() async {
    return _session;
  }

  @override
  Future<void> save(AuthSession session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}

const Object _unset = Object();