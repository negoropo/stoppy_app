import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/auth/domain/models/auth_state.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:stoppy_app/features/knockout/data/mock_knockout_repository.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_run.dart';
import 'package:stoppy_app/features/knockout/presentation/screens/knockout_home_screen.dart';

void main() {
  testWidgets('shows tournament state and registration status', (
    WidgetTester tester,
  ) async {
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 25,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnockoutHomeScreen(
          playerProfile: playerProfile,
          authRepository: _UpdatingAuthRepository(playerProfile),
          knockoutRepository: MockKnockoutRepository(
            now: () => DateTime(2026, 5, 22),
          ),
          onPlayerProfileUpdated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('June Knockout'), findsOneWidget);
    expect(find.text('Status: Registration open'), findsOneWidget);
    expect(find.text('Entry cost: 25 GP'), findsOneWidget);
    expect(find.text('Registration closes: 2026-05-31 23:59'), findsOneWidget);
    expect(find.text('Tournament starts: 2026-06-01 00:00'), findsOneWidget);
    expect(find.text('You are not registered.'), findsOneWidget);
    expect(find.text('Register for Knockout'), findsOneWidget);
    expect(
      find.text('Matches will be generated after registration closes.'),
      findsOneWidget,
    );
  });

  testWidgets('successful registration deducts GP and updates status', (
    WidgetTester tester,
  ) async {
    PlayerProfile? updatedProfile;
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 30,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnockoutHomeScreen(
          playerProfile: playerProfile,
          authRepository: _UpdatingAuthRepository(playerProfile),
          knockoutRepository: MockKnockoutRepository(
            now: () => DateTime(2026, 5, 22, 9, 30),
          ),
          onPlayerProfileUpdated: (profile) {
            updatedProfile = profile;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Register for Knockout'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(updatedProfile?.gamePoints, 5);
    expect(
      find.text('You are registered for this monthly Knockout.'),
      findsOneWidget,
    );
    expect(find.text('Registered'), findsOneWidget);
    expect(find.text('Registered at: 2026-05-22 09:30'), findsOneWidget);
  });

  testWidgets('insufficient GP shows registration error', (
    WidgetTester tester,
  ) async {
    PlayerProfile? updatedProfile;
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 24,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnockoutHomeScreen(
          playerProfile: playerProfile,
          authRepository: _UpdatingAuthRepository(playerProfile),
          knockoutRepository: MockKnockoutRepository(
            now: () => DateTime(2026, 5, 22),
          ),
          onPlayerProfileUpdated: (profile) {
            updatedProfile = profile;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Register for Knockout'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('You need 25 GP to register.'), findsOneWidget);
    expect(updatedProfile, isNull);
    expect(find.text('You are not registered.'), findsOneWidget);
  });

  testWidgets('shows active duel score details', (WidgetTester tester) async {
    final repository = MockKnockoutRepository(
      now: () => DateTime(2026, 5, 22, 9),
    );
    final tournament = await repository.fetchCurrentTournament();
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 50,
    );
    final opponentProfile = PlayerProfile(
      id: 'opponent-id',
      username: 'Opponent',
      createdAt: DateTime(2026),
      gamePoints: 50,
    );

    await repository.registerPlayer(
      tournament: tournament,
      playerProfile: playerProfile,
    );
    await repository.registerPlayer(
      tournament: tournament,
      playerProfile: opponentProfile,
    );
    final startedTournament = await repository.startTournament(
      tournamentId: tournament.id,
    );
    final duel = await repository.fetchActiveDuel(
      tournamentId: startedTournament.id,
      playerId: playerProfile.id,
    );
    await repository.submitKnockoutRun(
      KnockoutRun(
        id: 'run-1',
        playerId: playerProfile.id,
        matchId: duel!.match.id,
        roundNumber: duel.roundNumber,
        score: 700,
        completedAt: DateTime(2026, 6, 1, 9),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnockoutHomeScreen(
          playerProfile: playerProfile,
          authRepository: _UpdatingAuthRepository(playerProfile),
          knockoutRepository: repository,
          onPlayerProfileUpdated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Active Duel'), findsOneWidget);
    expect(find.text('Opponent: Opponent'), findsOneWidget);
    expect(find.text('Your score: 700 (1 runs)'), findsOneWidget);
    expect(find.text('Opponent score: 0 (0 runs)'), findsOneWidget);
    expect(find.text('Round settles: 2026-06-01 23:59'), findsOneWidget);
  });
}

class _UpdatingAuthRepository implements AuthRepository {
  _UpdatingAuthRepository(this.playerProfile);

  PlayerProfile playerProfile;

  @override
  Future<AuthState> currentAuthState() async {
    return AuthState.authenticated(playerProfile);
  }

  @override
  Future<PlayerProfile> login({
    required String username,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<PlayerProfile> register({
    required String username,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PlayerProfile> updatePlayerProfile(PlayerProfile playerProfile) async {
    this.playerProfile = playerProfile;
    return playerProfile;
  }
}
