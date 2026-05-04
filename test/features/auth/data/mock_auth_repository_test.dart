import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/auth/data/mock_auth_repository.dart';
import 'package:stoppy_app/features/auth/domain/repositories/auth_repository.dart';

void main() {
  group('MockAuthRepository', () {
    test('starts unauthenticated', () async {
      final repository = MockAuthRepository();

      final authState = await repository.currentAuthState();

      expect(authState.isAuthenticated, isFalse);
    });

    test('registers a player and marks the player authenticated', () async {
      final repository = MockAuthRepository();

      final playerProfile = await repository.register(
        username: 'Nelson',
        password: 'pass123',
      );
      final authState = await repository.currentAuthState();

      expect(playerProfile.username, 'Nelson');
      expect(authState.isAuthenticated, isTrue);
      expect(authState.playerProfile?.username, 'Nelson');
    });

    test('rejects duplicate usernames case-insensitively', () async {
      final repository = MockAuthRepository();
      await repository.register(username: 'Stoppy', password: 'pass123');

      expect(
        () => repository.register(username: 'stoppy', password: 'pass456'),
        throwsA(isA<AuthException>()),
      );
    });

    test('logs in an existing player', () async {
      final repository = MockAuthRepository();
      await repository.register(username: 'PlayerOne', password: 'pass123');
      await repository.logout();

      final playerProfile = await repository.login(
        username: 'PlayerOne',
        password: 'pass123',
      );

      expect(playerProfile.username, 'PlayerOne');
    });
  });
}
