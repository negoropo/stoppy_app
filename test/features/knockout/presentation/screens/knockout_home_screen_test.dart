import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/auth/domain/models/auth_state.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:stoppy_app/features/knockout/data/mock_knockout_repository.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_run.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament.dart';
import 'package:stoppy_app/features/knockout/presentation/screens/knockout_home_screen.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament_history_entry.dart';

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
    await tester.scrollUntilVisible(
      find.text('Matches will be generated after registration closes.'),
      300,
    );
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
    await tester.pumpAndSettle();

    expect(updatedProfile?.gamePoints, 5);
    expect(
      find.text('You are registered for this monthly Knockout.'),
      findsOneWidget,
    );
    expect(find.text('Registered'), findsOneWidget);
    expect(find.text('Registered at: 2026-05-22 09:30'), findsOneWidget);
  });

  testWidgets('updates local player profile when parent profile changes', (
      WidgetTester tester,
      ) async {
    final repository = MockKnockoutRepository(
      now: () => DateTime(2026, 5, 22),
    );

    final initialProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 25,
    );

    final updatedProfile = initialProfile.copyWith(gamePoints: 75);

    await tester.pumpWidget(
      MaterialApp(
        home: KnockoutHomeScreen(
          playerProfile: initialProfile,
          authRepository: _UpdatingAuthRepository(initialProfile),
          knockoutRepository: repository,
          onPlayerProfileUpdated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your GP: 25'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: KnockoutHomeScreen(
          playerProfile: updatedProfile,
          authRepository: _UpdatingAuthRepository(updatedProfile),
          knockoutRepository: repository,
          onPlayerProfileUpdated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your GP: 75'), findsOneWidget);
    expect(find.text('Your GP: 25'), findsNothing);
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

    expect(find.text('Tournament Status'), findsOneWidget);
    expect(find.text('Active duel'), findsOneWidget);
    expect(find.text('Opponent: Opponent'), findsOneWidget);
    expect(find.text('Your score: 700 (1 runs)'), findsOneWidget);
    expect(find.text('Opponent score: 0 (0 runs)'), findsOneWidget);
    expect(find.text('Round settles: 2026-06-01 23:59'), findsOneWidget);
    expect(find.text('Play tournament run'), findsOneWidget);
  });

  testWidgets('shows registered waiting state before tournament start', (
    WidgetTester tester,
  ) async {
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
    await repository.registerPlayer(
      tournament: tournament,
      playerProfile: playerProfile,
    );

    await _pumpKnockoutHome(tester, repository, playerProfile);

    expect(
      find.text('Registered - waiting for tournament start'),
      findsOneWidget,
    );
    expect(
      find.text('Your duel will appear when the tournament starts.'),
      findsOneWidget,
    );
  });

  testWidgets('shows bye waiting state', (WidgetTester tester) async {
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
    await repository.registerPlayer(
      tournament: tournament,
      playerProfile: playerProfile,
    );
    await repository.startTournament(tournamentId: tournament.id);

    await _pumpKnockoutHome(tester, repository, playerProfile);

    expect(find.text('Bye - waiting for next round'), findsOneWidget);
    expect(find.text('Round 1: bye advanced'), findsOneWidget);
  });

  testWidgets('shows eliminated state', (WidgetTester tester) async {
    var now = DateTime(2026, 5, 22, 9);
    final repository = MockKnockoutRepository(now: () => now);
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
      playerId: opponentProfile.id,
    );
    await repository.submitKnockoutRun(
      KnockoutRun(
        id: 'opponent-run',
        playerId: opponentProfile.id,
        matchId: duel!.match.id,
        roundNumber: duel.roundNumber,
        score: 1000,
        completedAt: DateTime(2026, 6, 1, 10),
      ),
    );
    now = DateTime(2026, 6, 1, 23, 59);
    await repository.settleCurrentRound(tournamentId: startedTournament.id);

    await _pumpKnockoutHome(tester, repository, playerProfile);

    expect(find.text('Eliminated'), findsOneWidget);
    expect(find.text('Your tournament run has ended.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Tournament History'), 300);
    expect(
      find.text('June Knockout: Eliminated • Round 1 • Best score 0'),
      findsOneWidget,
    );
  });

  testWidgets('shows champion state', (WidgetTester tester) async {
    var now = DateTime(2026, 5, 22, 9);
    final repository = MockKnockoutRepository(now: () => now);
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
        id: 'winner-run',
        playerId: playerProfile.id,
        matchId: duel!.match.id,
        roundNumber: duel.roundNumber,
        score: 1000,
        completedAt: DateTime(2026, 6, 1, 10),
      ),
    );
    now = DateTime(2026, 6, 1, 23, 59);
    await repository.settleCurrentRound(tournamentId: startedTournament.id);

    await _pumpKnockoutHome(tester, repository, playerProfile);

    expect(find.text('Tournament champion'), findsOneWidget);
    expect(find.text('You won this monthly Knockout.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Personal Knockout Records'),
      300,
    );
    expect(find.text('Tournaments played: 1'), findsOneWidget);
    expect(find.text('Tournaments won: 1'), findsOneWidget);
    expect(find.text('Highest round reached: 1'), findsOneWidget);
    expect(find.text('Best duel score: 1000'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Tournament History'), 300);
    expect(
      find.text('June Knockout: Champion • Round 1 • Best score 1000'),
      findsOneWidget,
    );
  });

  testWidgets('limits visible tournament history entries', (
      WidgetTester tester,
      ) async {
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 50,
    );

    final history = [
      for (var index = 0; index < 12; index += 1)
        KnockoutTournamentHistoryEntry(
          tournamentId: '2026-${index + 1}',
          tournamentName: 'Tournament $index',
          tournamentMonth: DateTime(2026, index + 1),
          playerId: playerProfile.id,
          outcome: KnockoutTournamentOutcome.eliminated,
          finalRoundNumber: 1,
          bestDuelScore: 500 + index,
          completedAt: DateTime(2026, index + 1, 1),
        ),
    ];

    final repository = MockKnockoutRepository(
      initialHistoryByPlayerId: {
        playerProfile.id: history,
      },
    );

    await _pumpKnockoutHome(tester, repository, playerProfile);

    await tester.scrollUntilVisible(
      find.text('Tournament History'),
      300,
    );

    for (var index = 2; index < 12; index += 1) {
      expect(
        find.text(
          'Tournament $index: Eliminated • Round 1 • Best score ${500 + index}',
        ),
        findsOneWidget,
      );
    }

    expect(
      find.text('Tournament 0: Eliminated • Round 1 • Best score 500'),
      findsNothing,
    );
    expect(
      find.text('Tournament 1: Eliminated • Round 1 • Best score 501'),
      findsNothing,
    );

    expect(
      find.text('+2 older tournament results hidden'),
      findsOneWidget,
    );
  });

  testWidgets(
    'keeps non-registered player as not registered after completion',
    (WidgetTester tester) async {
      final playerProfile = PlayerProfile(
        id: 'player-id',
        username: 'Tester',
        createdAt: DateTime(2026),
        gamePoints: 50,
      );
      final repository = MockKnockoutRepository(
        initialTournament: KnockoutTournament(
          id: '2026-06',
          name: 'June Knockout',
          entryCostGamePoints: 25,
          tournamentMonth: DateTime(2026, 6),
          registrationOpensAt: DateTime(2026, 5),
          registrationClosesAt: DateTime(2026, 5, 31, 23, 59),
          startsAt: DateTime(2026, 6),
          status: KnockoutTournamentStatus.completed,
        ),
        now: () => DateTime(2026, 6, 30),
      );

      await _pumpKnockoutHome(tester, repository, playerProfile);

      expect(find.text('Not registered'), findsOneWidget);
      expect(
        find.text('Register while the monthly window is open.'),
        findsOneWidget,
      );
    },
  );
}

Future<void> _pumpKnockoutHome(
  WidgetTester tester,
  MockKnockoutRepository repository,
  PlayerProfile playerProfile,
) async {
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
