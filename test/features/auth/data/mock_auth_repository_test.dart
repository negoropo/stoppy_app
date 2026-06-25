import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/auth/data/mock_auth_repository.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/auth/domain/repositories/auth_repository.dart';

void main() {
  group('PlayerProfile', () {
    test('defaults gamePoints to 5', () {
      final playerProfile = PlayerProfile(
        id: 'player-id',
        username: 'Tester',
        createdAt: DateTime(2026),
      );

      expect(playerProfile.gamePoints, 5);
      expect(playerProfile.lastDailyGpAwardedAt, isNull);
      expect(playerProfile.adsRemoved, isFalse);
      expect(playerProfile.currentLeagueDivision, isNull);
      expect(playerProfile.hasWeeklyLeagueEntry, isFalse);
      expect(playerProfile.reservedLeagueSlot, isFalse);
    });

    test('serializes league fields defensively', () {
      final playerProfile = PlayerProfile(
        id: 'player-id',
        username: 'Tester',
        createdAt: DateTime(2026),
        currentLeagueDivision: 2,
        hasWeeklyLeagueEntry: true,
        reservedLeagueSlot: true,
      );

      final restoredProfile = PlayerProfile.fromJson(playerProfile.toJson());

      expect(restoredProfile.currentLeagueDivision, 2);
      expect(restoredProfile.hasWeeklyLeagueEntry, isTrue);
      expect(restoredProfile.reservedLeagueSlot, isTrue);
    });
  });

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
      expect(playerProfile.gamePoints, 5);
      expect(playerProfile.adsRemoved, isFalse);
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

    test(
      'logout clears current authentication but keeps registered users',
      () async {
        final repository = MockAuthRepository();
        await repository.register(
          username: 'RepeatPlayer',
          password: 'pass123',
        );

        await repository.logout();
        final loggedOutState = await repository.currentAuthState();

        expect(loggedOutState.isAuthenticated, isFalse);

        final playerProfile = await repository.login(
          username: 'RepeatPlayer',
          password: 'pass123',
        );
        final loggedInState = await repository.currentAuthState();

        expect(playerProfile.username, 'RepeatPlayer');
        expect(loggedInState.isAuthenticated, isTrue);
        expect(loggedInState.playerProfile?.username, 'RepeatPlayer');
      },
    );

    test('persists updated GP in memory', () async {
      final repository = MockAuthRepository();
      final playerProfile = await repository.register(
        username: 'GpPlayer',
        password: 'pass123',
      );
      final awardedAt = DateTime(2026, 5, 4, 18);

      await repository.updatePlayerProfile(
        playerProfile.copyWith(
          gamePoints: playerProfile.gamePoints + 3,
          lastDailyGpAwardedAt: awardedAt,
        ),
      );
      final authState = await repository.currentAuthState();

      expect(authState.playerProfile?.gamePoints, 8);
      expect(authState.playerProfile?.lastDailyGpAwardedAt, awardedAt);
    });
  });
}
