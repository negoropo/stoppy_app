import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/auth/data/mock_auth_repository.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/auth/domain/models/auth_state.dart';
import 'package:stoppy_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:stoppy_app/features/league/domain/models/league_player_entry.dart';
import 'package:stoppy_app/features/league/domain/models/league_ranking_entry.dart';
import 'package:stoppy_app/features/league/domain/models/league_ranking_snapshot.dart';
import 'package:stoppy_app/features/league/domain/models/league_season_id.dart';
import 'package:stoppy_app/features/league/domain/models/league_season_settlement_result.dart';
import 'package:stoppy_app/features/league/domain/models/player_league_records.dart';
import 'package:stoppy_app/features/league/domain/models/weekly_league_history_entry.dart';
import 'package:stoppy_app/features/league/domain/models/weekly_league_run.dart';
import 'package:stoppy_app/features/league/domain/models/weekly_league_score.dart';
import 'package:stoppy_app/features/league/domain/repositories/league_repository.dart';
import 'package:stoppy_app/features/league/presentation/screens/league_home_screen.dart';

void main() {
  testWidgets('shows weekly scoring and nearby ranking details', (
    WidgetTester tester,
  ) async {
    final playerProfile = PlayerProfile(
      id: 'current',
      username: 'Current Player',
      createdAt: DateTime(2026, 5, 1),
      currentLeagueDivision: 2,
      hasWeeklyLeagueEntry: true,
    );
    final currentEntry = _entry('current', 'Current Player');
    final currentRankingEntry = LeagueRankingEntry(
      rank: 5,
      playerEntry: currentEntry,
      weeklyScore: _score(
        'current',
        runCount: 6,
        bestRunsCount: 2,
        activeDays: 3,
        activityMultiplier: 1.2,
        baseScore: 950,
        finalScore: 1140,
      ),
    );
    final inactiveEntry = LeagueRankingEntry(
      rank: 7,
      playerEntry: _entry('inactive', 'Inactive Player', entryPaid: false),
      weeklyScore: _score(
        'inactive',
        isActive: false,
        runCount: 0,
        bestRunsCount: 0,
        activeDays: 0,
        activityMultiplier: 0,
        baseScore: 0,
        finalScore: 0,
      ),
    );
    final repository = _LeagueScreenRepository(
      storedEntry: currentEntry,
      ranking: [
        _rankingEntry('leader', 'Leader', rank: 1, finalScore: 1500),
        currentRankingEntry,
        inactiveEntry,
      ],
      snapshot: LeagueRankingSnapshot(
        currentPlayerRank: 5,
        currentPlayerEntry: currentRankingEntry,
        playersAbove: [
          _rankingEntry('above', 'Above Player', rank: 4, finalScore: 1200),
        ],
        playersBelow: [inactiveEntry],
        scoreNeededForPromotionZone: 1301,
        scoreNeededToStayInDivision: 901,
        promotionZoneEndRank: 4,
        relegationZoneStartRank: 7,
      ),
      records: PlayerLeagueRecords(
        playerId: 'current',
        allTimeBestFinalScore: 1800,
        currentWeeklyBestScore: 1250,
        currentSeasonId: LeagueSeasonId.fromDate(DateTime(2026, 5, 4)),
      ),
      history: [
        WeeklyLeagueHistoryEntry(
          playerId: 'current',
          seasonId: LeagueSeasonId.fromDate(DateTime(2026, 4, 27)),
          finalRank: 3,
          finalDivision: 2,
          result: WeeklyLeagueSeasonResult.promoted,
          finalWeeklyScore: 1400,
          seasonEndedAt: DateTime(2026, 5, 3, 23, 59),
        ),
      ],
      weeklyRuns: [
        WeeklyLeagueRun(
          playerId: 'current',
          score: 1250,
          completedAt: DateTime(2026, 5, 16, 14, 30),
        ),
        WeeklyLeagueRun(
          playerId: 'current',
          score: 1100,
          completedAt: DateTime(2026, 5, 15, 9, 5),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LeagueHomeScreen(
          playerProfile: playerProfile,
          authRepository: MockAuthRepository(),
          leagueRepository: repository,
          onPlayerProfileUpdated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Weekly Score'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Weekly runs: 6'), findsOneWidget);
    expect(find.text('Best runs used: 2'), findsOneWidget);
    expect(find.text('Average of selected best runs: 950'), findsOneWidget);
    expect(find.text('Active days this week: 3'), findsOneWidget);
    expect(find.text('Activity multiplier: x1.2'), findsOneWidget);
    expect(find.text('Final weekly score: 1140'), findsOneWidget);
    expect(find.text('All-time best final score: 1800'), findsOneWidget);
    expect(find.text('Current weekly best score: 1250'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pump();
    expect(find.text('Weekly Runs'), findsOneWidget);
    expect(find.text('1250'), findsWidgets);
    expect(find.text('2026-05-16 14:30'), findsOneWidget);
    expect(find.text('1100'), findsOneWidget);
    expect(find.text('2026-05-15 09:05'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Weekly Settlement'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(
      find.text('Next weekly settlement: Sunday 23:59 Europe/Lisbon time'),
      findsOneWidget,
    );
    expect(find.text('Last settlement: 2026-05-03'), findsOneWidget);
    expect(find.text('Result: promoted'), findsOneWidget);
    expect(find.text('Final division: 2'), findsOneWidget);
    expect(find.text('Final rank: #3'), findsOneWidget);
    expect(find.text('Final weekly score: 1400'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Nearby Ranking'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.byKey(const Key('current-player-ranking-row')), findsOneWidget);
    expect(find.text('#5 Current Player (You)'), findsOneWidget);
    expect(find.text('Promotion zone: #1-#4'), findsOneWidget);
    expect(find.text('Relegation zone: #7 and below'), findsOneWidget);
    expect(find.text('Promotion need: 1301'), findsOneWidget);
    expect(find.text('Stay need: 901'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('League History'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(
      find.text('2026-04-27 - Division 2 - #3 - promoted - 1400'),
      findsOneWidget,
    );
  });

  testWidgets('shows reserved slot loss settlement result', (
    WidgetTester tester,
  ) async {
    final playerProfile = PlayerProfile(
      id: 'current',
      username: 'Current Player',
      createdAt: DateTime(2026, 5, 1),
      currentLeagueDivision: 2,
      hasWeeklyLeagueEntry: false,
    );
    final currentEntry = _entry('current', 'Current Player', entryPaid: false);
    final repository = _LeagueScreenRepository(
      storedEntry: currentEntry,
      ranking: const [],
      snapshot: LeagueRankingSnapshot(
        currentPlayerRank: 1,
        currentPlayerEntry: LeagueRankingEntry(
          rank: 1,
          playerEntry: currentEntry,
          weeklyScore: WeeklyLeagueScore(
            playerId: 'current',
            isActive: false,
            runCount: 0,
            activeDays: 0,
            activityMultiplier: 0,
            baseScore: 0,
            finalScore: 0,
            bonusPoints: 0,
            countedRunScores: [],
            allRunScores: [],
          ),
        ),
        playersAbove: const [],
        playersBelow: const [],
        scoreNeededForPromotionZone: null,
        scoreNeededToStayInDivision: null,
        promotionZoneEndRank: null,
        relegationZoneStartRank: null,
      ),
      records: PlayerLeagueRecords.empty('current'),
      history: [
        WeeklyLeagueHistoryEntry(
          playerId: 'current',
          seasonId: LeagueSeasonId.fromDate(DateTime(2026, 4, 27)),
          finalRank: 14,
          finalDivision: 3,
          result: WeeklyLeagueSeasonResult.lostReservedSlot,
          finalWeeklyScore: 0,
          seasonEndedAt: DateTime(2026, 5, 3, 23, 59),
        ),
      ],
      weeklyRuns: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LeagueHomeScreen(
          playerProfile: playerProfile,
          authRepository: MockAuthRepository(),
          leagueRepository: repository,
          onPlayerProfileUpdated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Weekly Settlement'),
      200,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('Result: lost reserved slot'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('League History'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(
      find.text('2026-04-27 - Division 3 - #14 - lost reserved slot - 0'),
      findsOneWidget,
    );
  });

  testWidgets('shows re-entry CTA when player is outside the league', (
    WidgetTester tester,
  ) async {
    final playerProfile = PlayerProfile(
      id: 'current',
      username: 'Current Player',
      createdAt: DateTime(2026, 5, 1),
      gamePoints: 10,
      currentLeagueDivision: null,
      hasWeeklyLeagueEntry: false,
      reservedLeagueSlot: false,
    );
    final reentryEntry = _entry('current', 'Current Player', divisionNumber: 3);
    final repository = _LeagueScreenRepository(
      storedEntry: null,
      entryOnEnter: reentryEntry,
      ranking: const [],
      snapshot: _snapshotFor(reentryEntry),
      records: PlayerLeagueRecords.empty('current'),
      history: const [],
      weeklyRuns: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LeagueHomeScreen(
          playerProfile: playerProfile,
          authRepository: _UpdatingAuthRepository(playerProfile),
          leagueRepository: repository,
          onPlayerProfileUpdated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('League status: outside league'), findsOneWidget);
    expect(
      find.text(
        'You are outside the weekly league. Re-enter to reserve a slot again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Re-enter Weekly League'), findsOneWidget);
  });

  testWidgets(
    'stale weekly-entry profile still shows re-entry when repository has no slot',
    (WidgetTester tester) async {
      final playerProfile = PlayerProfile(
        id: 'current',
        username: 'Current Player',
        createdAt: DateTime(2026, 5, 1),
        gamePoints: 10,
        currentLeagueDivision: 2,
        hasWeeklyLeagueEntry: true,
        reservedLeagueSlot: true,
      );
      final repository = _LeagueScreenRepository(
        storedEntry: null,
        entryOnEnter: _entry('current', 'Current Player', divisionNumber: 3),
        ranking: const [],
        snapshot: null,
        records: PlayerLeagueRecords.empty('current'),
        history: const [],
        weeklyRuns: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LeagueHomeScreen(
            playerProfile: playerProfile,
            authRepository: _UpdatingAuthRepository(playerProfile),
            leagueRepository: repository,
            onPlayerProfileUpdated: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('League status: outside league'), findsOneWidget);
      expect(find.text('Re-enter Weekly League'), findsOneWidget);
    },
  );

  testWidgets(
    'entry without reserved slot does not request a player snapshot',
    (WidgetTester tester) async {
      final playerProfile = PlayerProfile(
        id: 'current',
        username: 'Current Player',
        createdAt: DateTime(2026, 5, 1),
        gamePoints: 10,
        currentLeagueDivision: 2,
      );
      final repository = _LeagueScreenRepository(
        storedEntry: _entry(
          'current',
          'Current Player',
          entryPaid: false,
          hasReservedSlot: false,
        ),
        ranking: const [],
        snapshot: null,
        records: PlayerLeagueRecords.empty('current'),
        history: const [],
        weeklyRuns: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LeagueHomeScreen(
            playerProfile: playerProfile,
            authRepository: _UpdatingAuthRepository(playerProfile),
            leagueRepository: repository,
            onPlayerProfileUpdated: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('League status: outside league'), findsOneWidget);
      expect(repository.snapshotRequestCount, 0);
    },
  );

  testWidgets('re-entry deducts GP and syncs player profile', (
    WidgetTester tester,
  ) async {
    PlayerProfile? updatedProfile;
    final playerProfile = PlayerProfile(
      id: 'current',
      username: 'Current Player',
      createdAt: DateTime(2026, 5, 1),
      gamePoints: 15,
      hasWeeklyLeagueEntry: false,
      reservedLeagueSlot: false,
    );
    final repository = _LeagueScreenRepository(
      storedEntry: null,
      entryOnEnter: _entry('current', 'Current Player', divisionNumber: 3),
      ranking: const [],
      snapshot: null,
      records: PlayerLeagueRecords.empty('current'),
      history: const [],
      weeklyRuns: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LeagueHomeScreen(
          playerProfile: playerProfile,
          authRepository: _UpdatingAuthRepository(playerProfile),
          leagueRepository: repository,
          onPlayerProfileUpdated: (profile) {
            updatedProfile = profile;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Re-enter Weekly League'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(updatedProfile?.gamePoints, 5);
    expect(updatedProfile?.currentLeagueDivision, 3);
    expect(updatedProfile?.hasWeeklyLeagueEntry, isTrue);
    expect(updatedProfile?.reservedLeagueSlot, isTrue);
  });

  testWidgets(
    're-entry with insufficient GP shows error without state changes',
    (WidgetTester tester) async {
      PlayerProfile? updatedProfile;
      final playerProfile = PlayerProfile(
        id: 'current',
        username: 'Current Player',
        createdAt: DateTime(2026, 5, 1),
        gamePoints: 9,
        hasWeeklyLeagueEntry: false,
        reservedLeagueSlot: false,
      );
      final repository = _LeagueScreenRepository(
        storedEntry: null,
        entryOnEnter: _entry('current', 'Current Player', divisionNumber: 3),
        ranking: const [],
        snapshot: null,
        records: PlayerLeagueRecords.empty('current'),
        history: const [],
        weeklyRuns: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LeagueHomeScreen(
            playerProfile: playerProfile,
            authRepository: _UpdatingAuthRepository(playerProfile),
            leagueRepository: repository,
            onPlayerProfileUpdated: (profile) {
              updatedProfile = profile;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Re-enter Weekly League'));
      await tester.pumpAndSettle();

      expect(
        find.text('You need 10 GP to enter the weekly league.'),
        findsOneWidget,
      );
      expect(updatedProfile, isNull);
      expect(repository.enterCallCount, 0);
    },
  );
}

LeaguePlayerEntry _entry(
  String playerId,
  String username, {
  bool entryPaid = true,
  int divisionNumber = 2,
  bool hasReservedSlot = true,
}) {
  return LeaguePlayerEntry(
    playerId: playerId,
    username: username,
    divisionNumber: divisionNumber,
    registeredAt: DateTime(2026, 5, 1),
    entryPaid: entryPaid,
    hasReservedSlot: hasReservedSlot,
  );
}

LeagueRankingEntry _rankingEntry(
  String playerId,
  String username, {
  required int rank,
  required double finalScore,
}) {
  return LeagueRankingEntry(
    rank: rank,
    playerEntry: _entry(playerId, username),
    weeklyScore: _score(
      playerId,
      runCount: 1,
      bestRunsCount: 1,
      activeDays: 1,
      activityMultiplier: 1,
      baseScore: finalScore,
      finalScore: finalScore,
    ),
  );
}

LeagueRankingSnapshot _snapshotFor(LeaguePlayerEntry entry) {
  final rankingEntry = LeagueRankingEntry(
    rank: 1,
    playerEntry: entry,
    weeklyScore: _score(
      entry.playerId,
      runCount: 0,
      bestRunsCount: 0,
      activeDays: 0,
      activityMultiplier: 0,
      baseScore: 0,
      finalScore: 0,
    ),
  );

  return LeagueRankingSnapshot(
    currentPlayerRank: 1,
    currentPlayerEntry: rankingEntry,
    playersAbove: const [],
    playersBelow: const [],
    scoreNeededForPromotionZone: null,
    scoreNeededToStayInDivision: null,
    promotionZoneEndRank: null,
    relegationZoneStartRank: null,
  );
}

WeeklyLeagueScore _score(
  String playerId, {
  bool isActive = true,
  required int runCount,
  required int bestRunsCount,
  required int activeDays,
  required double activityMultiplier,
  required double baseScore,
  required double finalScore,
}) {
  return WeeklyLeagueScore(
    playerId: playerId,
    isActive: isActive,
    runCount: runCount,
    activeDays: activeDays,
    activityMultiplier: activityMultiplier,
    baseScore: baseScore,
    finalScore: finalScore,
    bonusPoints: finalScore - baseScore,
    countedRunScores: List.filled(bestRunsCount, baseScore.round()),
    allRunScores: List.filled(runCount, baseScore.round()),
  );
}

class _LeagueScreenRepository implements LeagueRepository {
  _LeagueScreenRepository({
    required this.storedEntry,
    this.entryOnEnter,
    required this.ranking,
    required this.snapshot,
    required this.records,
    required this.history,
    required this.weeklyRuns,
  });

  LeaguePlayerEntry? storedEntry;
  final LeaguePlayerEntry? entryOnEnter;
  final List<LeagueRankingEntry> ranking;
  final LeagueRankingSnapshot? snapshot;
  final PlayerLeagueRecords records;
  final List<WeeklyLeagueHistoryEntry> history;
  final List<WeeklyLeagueRun> weeklyRuns;
  int enterCallCount = 0;
  int snapshotRequestCount = 0;

  @override
  Future<LeaguePlayerEntry?> currentEntry(String playerId) async {
    return storedEntry;
  }

  @override
  Future<LeaguePlayerEntry> enterWeeklyLeague(PlayerProfile profile) async {
    enterCallCount += 1;
    storedEntry = entryOnEnter ?? storedEntry;
    return storedEntry!;
  }

  @override
  Future<List<LeagueRankingEntry>> fetchDivisionRanking(
    int divisionNumber,
  ) async {
    return ranking;
  }

  @override
  Future<LeagueRankingSnapshot> fetchPlayerSnapshot({
    required String playerId,
    required int divisionNumber,
  }) async {
    snapshotRequestCount += 1;
    return snapshot!;
  }

  @override
  Future<PlayerLeagueRecords> fetchPlayerRecords(String playerId) async {
    return records;
  }

  @override
  Future<List<WeeklyLeagueHistoryEntry>> fetchPlayerHistory(
    String playerId,
  ) async {
    return history;
  }

  @override
  Future<List<WeeklyLeagueRun>> fetchPlayerWeeklyRuns({
    required String playerId,
    required LeagueSeasonId seasonId,
  }) async {
    return weeklyRuns;
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
    return LeagueRunSubmissionResult(accepted: true, playerRecords: records);
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
