import '../domain/models/auth_state.dart';
import '../domain/models/player_profile.dart';
import '../domain/repositories/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  final Map<String, _MockPlayerRecord> _playersByNormalizedUsername = {};
  PlayerProfile? _currentPlayer;
  int _nextPlayerId = 1;

  @override
  Future<AuthState> currentAuthState() async {
    final currentPlayer = _currentPlayer;
    if (currentPlayer == null) {
      return const AuthState.unauthenticated();
    }

    return AuthState.authenticated(currentPlayer);
  }

  @override
  Future<PlayerProfile> register({
    required String username,
    required String password,
  }) async {
    final cleanUsername = _cleanUsername(username);
    final cleanPassword = password;
    _validateCredentials(username: cleanUsername, password: cleanPassword);

    final normalizedUsername = _normalizeUsername(cleanUsername);
    if (_playersByNormalizedUsername.containsKey(normalizedUsername)) {
      throw const AuthException('Username is already taken.');
    }

    final playerProfile = PlayerProfile(
      id: 'mock-player-${_nextPlayerId++}',
      username: cleanUsername,
      createdAt: DateTime.now(),
    );
    _playersByNormalizedUsername[normalizedUsername] = _MockPlayerRecord(
      playerProfile: playerProfile,
      password: cleanPassword,
    );
    _currentPlayer = playerProfile;

    return playerProfile;
  }

  @override
  Future<PlayerProfile> login({
    required String username,
    required String password,
  }) async {
    final cleanUsername = _cleanUsername(username);
    final cleanPassword = password;
    _validateCredentials(username: cleanUsername, password: cleanPassword);

    final record =
        _playersByNormalizedUsername[_normalizeUsername(cleanUsername)];
    if (record == null || record.password != cleanPassword) {
      throw const AuthException('Invalid username or password.');
    }

    _currentPlayer = record.playerProfile;
    return record.playerProfile;
  }

  @override
  Future<void> logout() async {
    _currentPlayer = null;
  }

  @override
  Future<PlayerProfile> updatePlayerProfile(PlayerProfile playerProfile) async {
    final normalizedUsername = _normalizeUsername(playerProfile.username);
    final existingRecord = _playersByNormalizedUsername[normalizedUsername];
    if (existingRecord == null) {
      throw const AuthException('Player profile does not exist.');
    }

    // The mock repository updates the full profile record in memory. A backend
    // repository can later replace this with an authenticated server mutation
    // using the same contract.
    _playersByNormalizedUsername[normalizedUsername] = existingRecord.copyWith(
      playerProfile: playerProfile,
    );
    _currentPlayer = playerProfile;
    return playerProfile;
  }

  String _cleanUsername(String username) {
    return username.trim();
  }

  String _normalizeUsername(String username) {
    return username.trim().toLowerCase();
  }

  void _validateCredentials({
    required String username,
    required String password,
  }) {
    if (username.isEmpty) {
      throw const AuthException('Username is required.');
    }

    if (password.length < 4) {
      throw const AuthException('Password must be at least 4 characters.');
    }
  }
}

class _MockPlayerRecord {
  const _MockPlayerRecord({
    required this.playerProfile,
    required this.password,
  });

  final PlayerProfile playerProfile;
  final String password;

  _MockPlayerRecord copyWith({PlayerProfile? playerProfile, String? password}) {
    return _MockPlayerRecord(
      playerProfile: playerProfile ?? this.playerProfile,
      password: password ?? this.password,
    );
  }
}
