import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/auth/domain/models/auth_state.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:stoppy_app/features/knockout/data/mock_knockout_repository.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_records.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_run.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament.dart';
import 'package:stoppy_app/features/knockout/presentation/screens/knockout_home_screen.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament_history_entry.dart';
import 'package:stoppy_app/features/league/domain/models/league_player_entry.dart';
import 'package:stoppy_app/features/league/domain/models/league_ranking_entry.dart';
import 'package:stoppy_app/features/league/domain/models/league_ranking_snapshot.dart';
import 'package:stoppy_app/features/league/domain/models/league_season_id.dart';
import 'package:stoppy_app/features/league/domain/models/league_season_settlement_result.dart';
import 'package:stoppy_app/features/league/domain/models/player_league_achievements.dart';
import 'package:stoppy_app/features/league/domain/models/player_league_records.dart';
import 'package:stoppy_app/features/league/domain/models/weekly_league_history_entry.dart';
import 'package:stoppy_app/features/league/domain/models/weekly_league_run.dart';
import 'package:stoppy_app/features/league/domain/repositories/league_repository.dart';

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
    final repository = MockKnockoutRepository(now: () => DateTime(2026, 5, 22));

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
    expect(find.text('June Knockout: Eliminated • Round 1'), findsOneWidget);
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
    expect(find.text('Titles won: 1'), findsOneWidget);
    expect(find.text('Best tournament result: Champion'), findsOneWidget);
    expect(find.text('Tournaments participated: 1'), findsWidgets);
    expect(find.text('Total duels played: 1'), findsWidgets);
    expect(find.text('Total duels won: 1'), findsOneWidget);
    expect(find.text('Duel win percentage: 100.0%'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Knockout Hall of Fame'), 300);
    expect(find.text('Tester • 1 title'), findsOneWidget);
    expect(find.text('Won: June 2026'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Tournament History'), 300);
    expect(find.text('June Knockout: Champion • Round 1'), findsOneWidget);
  });

  testWidgets('shows combined competitive achievements from repositories', (
    WidgetTester tester,
  ) async {
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 50,
    );
    final repository = MockKnockoutRepository(
      initialRecordsByPlayerId: {
        playerProfile.id: const KnockoutPlayerRecords(
          playerId: 'player-id',
          tournamentsPlayed: 4,
          tournamentsWon: 1,
          highestRoundReached: 5,
          totalDuelsPlayed: 12,
          totalDuelsWon: 9,
        ),
      },
    );
    final leagueRepository = _AchievementLeagueRepository(
      PlayerLeagueAchievements(
        playerId: playerProfile.id,
        bestDivisionReached: 2,
        promotions: 3,
        relegations: 1,
      ),
    );

    await _pumpKnockoutHome(
      tester,
      repository,
      playerProfile,
      leagueRepository: leagueRepository,
    );

    await tester.scrollUntilVisible(find.text('Competitive Achievements'), 300);

    expect(find.text('League'), findsOneWidget);
    expect(find.text('Best division reached: Division 2'), findsOneWidget);
    expect(find.text('Promotions: 3'), findsOneWidget);
    expect(find.text('Relegations: 1'), findsOneWidget);
    expect(find.text('Knockout'), findsWidgets);
    expect(find.text('Best round reached: Round 5'), findsOneWidget);
    expect(find.text('Tournaments participated: 4'), findsWidgets);
    expect(find.text('Duel win percentage: 75.0%'), findsWidgets);
    expect(find.text('Total duels played: 12'), findsWidgets);
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
          completedAt: DateTime(2026, index + 1, 1),
        ),
    ];

    final repository = MockKnockoutRepository(
      initialHistoryByPlayerId: {playerProfile.id: history},
    );

    await _pumpKnockoutHome(tester, repository, playerProfile);

    await tester.scrollUntilVisible(find.text('Tournament History'), 300);

    for (var index = 2; index < 12; index += 1) {
      expect(
        find.text('Tournament $index: Eliminated • Round 1'),
        findsOneWidget,
      );
    }

    expect(find.text('Tournament 0: Eliminated • Round 1'), findsNothing);
    expect(find.text('Tournament 1: Eliminated • Round 1'), findsNothing);

    expect(find.text('+2 older tournament results hidden'), findsOneWidget);
  });

  testWidgets('shows empty champion-only Hall of Fame', (
    WidgetTester tester,
  ) async {
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 50,
    );

    final repository = MockKnockoutRepository(
      initialHistoryByPlayerId: {
        playerProfile.id: [
          KnockoutTournamentHistoryEntry(
            tournamentId: '2026-06',
            tournamentName: 'June Knockout',
            tournamentMonth: DateTime(2026, 6),
            playerId: playerProfile.id,
            playerUsername: playerProfile.username,
            outcome: KnockoutTournamentOutcome.eliminated,
            finalRoundNumber: 1,
            completedAt: DateTime(2026, 6, 1),
          ),
        ],
      },
    );

    await _pumpKnockoutHome(tester, repository, playerProfile);

    await tester.scrollUntilVisible(find.text('Knockout Hall of Fame'), 300);

    expect(find.text('No Knockout champions yet.'), findsOneWidget);
    expect(find.text('Tester: 1 title'), findsNothing);
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
  PlayerProfile playerProfile, {
  LeagueRepository? leagueRepository,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: KnockoutHomeScreen(
        playerProfile: playerProfile,
        authRepository: _UpdatingAuthRepository(playerProfile),
        knockoutRepository: repository,
        onPlayerProfileUpdated: (_) {},
        leagueRepository: leagueRepository,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _AchievementLeagueRepository implements LeagueRepository {
  const _AchievementLeagueRepository(this.achievements);

  final PlayerLeagueAchievements achievements;

  @override
  Future<LeaguePlayerEntry?> currentEntry(String playerId) async {
    return null;
  }

  @override
  Future<LeaguePlayerEntry> enterWeeklyLeague(PlayerProfile profile) {
    throw UnimplementedError();
  }

  @override
  Future<List<LeagueRankingEntry>> fetchDivisionRanking(
    int divisionNumber,
  ) async {
    return const [];
  }

  @override
  Future<PlayerLeagueAchievements> fetchPlayerAchievements(
    String playerId,
  ) async {
    return achievements;
  }

  @override
  Future<PlayerLeagueRecords> fetchPlayerRecords(String playerId) async {
    return PlayerLeagueRecords.empty(playerId);
  }

  @override
  Future<List<WeeklyLeagueHistoryEntry>> fetchPlayerHistory(
    String playerId,
  ) async {
    return const [];
  }

  @override
  Future<List<WeeklyLeagueRun>> fetchPlayerWeeklyRuns({
    required String playerId,
    required LeagueSeasonId seasonId,
  }) async {
    return const [];
  }

  @override
  Future<LeagueRankingSnapshot> fetchPlayerSnapshot({
    required String playerId,
    required int divisionNumber,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<LeagueSeasonSettlementResult> settleCurrentSeason({
    required DateTime now,
  }) async {
    return LeagueSeasonSettlementResult(
      seasonId: LeagueSeasonId.fromDate(now),
      settledAt: now,
      executed: false,
    );
  }

  @override
  Future<LeagueRunSubmissionResult> submitLeagueRun(WeeklyLeagueRun run) async {
    return LeagueRunSubmissionResult(
      accepted: false,
      playerRecords: PlayerLeagueRecords.empty(run.playerId),
    );
  }
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
