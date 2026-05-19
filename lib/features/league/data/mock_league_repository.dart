import 'dart:math' as math;

import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/league/domain/models/league_division.dart';
import 'package:stoppy_app/features/league/domain/models/league_division_settlement.dart';
import 'package:stoppy_app/features/league/domain/models/league_player_entry.dart';
import 'package:stoppy_app/features/league/domain/models/league_ranking_entry.dart';
import 'package:stoppy_app/features/league/domain/models/league_ranking_snapshot.dart';
import 'package:stoppy_app/features/league/domain/models/league_season_id.dart';
import 'package:stoppy_app/features/league/domain/models/league_season_settlement_result.dart';
import 'package:stoppy_app/features/league/domain/models/player_league_records.dart';
import 'package:stoppy_app/features/league/domain/models/weekly_league_history_entry.dart';
import 'package:stoppy_app/features/league/domain/models/weekly_league_run.dart';
import 'package:stoppy_app/features/league/domain/repositories/league_repository.dart';
import 'package:stoppy_app/features/league/domain/services/league_division_policy.dart';
import 'package:stoppy_app/features/league/domain/services/league_ranking_calculator.dart';
import 'package:stoppy_app/features/league/domain/services/league_season_settlement_calculator.dart';
import 'package:stoppy_app/features/league/domain/services/player_league_records_calculator.dart';
import 'package:stoppy_app/features/league/domain/services/weekly_league_history_generator.dart';
import 'package:stoppy_app/features/league/domain/services/weekly_league_settlement_schedule.dart';

class MockLeagueRepository implements LeagueRepository {
  MockLeagueRepository({
    LeagueDivisionPolicy divisionPolicy = const LeagueDivisionPolicy(),
    LeagueRankingCalculator rankingCalculator = const LeagueRankingCalculator(),
    LeagueSeasonSettlementCalculator settlementCalculator =
        const LeagueSeasonSettlementCalculator(),
    PlayerLeagueRecordsCalculator recordsCalculator =
        const PlayerLeagueRecordsCalculator(),
    WeeklyLeagueHistoryGenerator historyGenerator =
        const WeeklyLeagueHistoryGenerator(),
    WeeklyLeagueSettlementSchedule settlementSchedule =
        const WeeklyLeagueSettlementSchedule(),
    bool seedMockData = true,
  }) : _divisionPolicy = divisionPolicy,
       _rankingCalculator = rankingCalculator,
       _settlementCalculator = settlementCalculator,
       _recordsCalculator = recordsCalculator,
       _historyGenerator = historyGenerator,
       _settlementSchedule = settlementSchedule {
    if (seedMockData) {
      _seedMockLeague();
    }
  }

  final LeagueDivisionPolicy _divisionPolicy;
  final LeagueRankingCalculator _rankingCalculator;
  final LeagueSeasonSettlementCalculator _settlementCalculator;
  final PlayerLeagueRecordsCalculator _recordsCalculator;
  final WeeklyLeagueHistoryGenerator _historyGenerator;
  final WeeklyLeagueSettlementSchedule _settlementSchedule;

  final List<LeagueDivision> _divisions = [];
  final Map<String, LeaguePlayerEntry> _entriesByPlayerId = {};
  final List<WeeklyLeagueRun> _runs = [];
  final Map<String, PlayerLeagueRecords> _recordsByPlayerId = {};
  final Map<String, List<WeeklyLeagueHistoryEntry>> _historyByPlayerId = {};
  final Set<String> _settledSeasonIds = {};

  @override
  Future<LeaguePlayerEntry?> currentEntry(String playerId) async {
    return _entriesByPlayerId[playerId];
  }

  @override
  Future<List<LeagueRankingEntry>> fetchDivisionRanking(
    int divisionNumber,
  ) async {
    return _rankingCalculator.rank(
      entries: _entriesByPlayerId.values.toList(),
      runs: _runs,
      divisionNumber: divisionNumber,
    );
  }

  @override
  Future<LeaguePlayerEntry> enterWeeklyLeague(PlayerProfile profile) async {
    final existingEntry = _entriesByPlayerId[profile.id];

    if (existingEntry != null) {
      if (existingEntry.isActive) {
        return existingEntry;
      }

      final activeEntry = _divisionPolicy.activateWeeklyEntry(existingEntry);
      _entriesByPlayerId[profile.id] = activeEntry;
      return activeEntry;
    }

    final division = _divisionPolicy.placeNewPlayer(
      divisions: _divisions,
      entries: _entriesByPlayerId.values.toList(),
    );

    if (!_divisions.any((existing) => existing.number == division.number)) {
      _divisions.add(division);
    }

    final entry = LeaguePlayerEntry(
      playerId: profile.id,
      username: profile.username,
      divisionNumber: division.number,
      registeredAt: profile.createdAt,
      entryPaid: true,
    );

    _entriesByPlayerId[profile.id] = entry;
    return entry;
  }

  @override
  Future<LeagueRunSubmissionResult> submitLeagueRun(WeeklyLeagueRun run) async {
    final entry = _entriesByPlayerId[run.playerId];
    final previousRecords =
        _recordsByPlayerId[run.playerId] ??
        PlayerLeagueRecords.empty(run.playerId);

    if (entry == null || !entry.isActive) {
      return LeagueRunSubmissionResult(
        accepted: false,
        playerRecords: previousRecords,
      );
    }

    _runs.add(run);
    final updatedRecords = _recordSubmittedRun(run);

    return LeagueRunSubmissionResult(
      accepted: true,
      playerRecords: updatedRecords,
    );
  }

  @override
  Future<PlayerLeagueRecords> fetchPlayerRecords(String playerId) async {
    return _recordsByPlayerId[playerId] ?? PlayerLeagueRecords.empty(playerId);
  }

  @override
  Future<List<WeeklyLeagueHistoryEntry>> fetchPlayerHistory(
    String playerId,
  ) async {
    final history = [...?_historyByPlayerId[playerId]]
      ..sort((a, b) => _historySortDate(b).compareTo(_historySortDate(a)));

    return List.unmodifiable(history);
  }

  @override
  Future<List<WeeklyLeagueRun>> fetchPlayerWeeklyRuns({
    required String playerId,
    required LeagueSeasonId seasonId,
  }) async {
    final weeklyRuns =
        _runs.where((run) {
          return run.playerId == playerId &&
              LeagueSeasonId.fromDate(run.completedAt).value == seasonId.value;
        }).toList()..sort((a, b) {
          final scoreOrder = b.score.compareTo(a.score);
          if (scoreOrder != 0) {
            return scoreOrder;
          }

          // Equal-score attempts show newest first so a player can see the most
          // recent run before older runs with the same competitive value.
          return b.completedAt.compareTo(a.completedAt);
        });

    return List.unmodifiable(weeklyRuns);
  }

  @override
  Future<LeagueRankingSnapshot> fetchPlayerSnapshot({
    required String playerId,
    required int divisionNumber,
  }) async {
    final ranking = await fetchDivisionRanking(divisionNumber);
    final division = _divisionForNumber(divisionNumber);

    final highestDivisionNumber = _divisions.isEmpty
        ? divisionNumber
        : _divisions.map((division) => division.number).reduce(math.max);

    final isLastDivision = divisionNumber == highestDivisionNumber;

    final relegationCount = isLastDivision
        ? 0
        : _settlementCalculator.minimumRelegationCount(division);

    final promotionCount = division.isFirstDivision
        ? 0
        : _settlementCalculator.minimumPromotionCountWherePossible(division);

    return _rankingCalculator.snapshotForPlayer(
      currentPlayerId: playerId,
      division: division,
      rankedEntries: ranking,
      promotionCount: promotionCount,
      relegationCount: relegationCount,
    );
  }

  @override
  Future<LeagueSeasonSettlementResult> settleCurrentSeason({
    required DateTime now,
  }) async {
    final seasonId = LeagueSeasonId.fromDate(now);

    if (_settledSeasonIds.contains(seasonId.value) ||
        !_settlementSchedule.isSettlementDue(now: now, seasonId: seasonId)) {
      return LeagueSeasonSettlementResult(
        seasonId: seasonId,
        settledAt: now,
        executed: false,
      );
    }

    final settlements = _buildSeasonSettlements(seasonId, settledAt: now);
    _applySeasonSettlements(settlements);
    _clearSettledSeasonRuns(seasonId);
    _settledSeasonIds.add(seasonId.value);

    return LeagueSeasonSettlementResult(
      seasonId: seasonId,
      settledAt: now,
      executed: true,
      divisionSettlements: settlements,
    );
  }

  LeagueDivision _divisionForNumber(int divisionNumber) {
    return _divisions.firstWhere(
      (division) => division.number == divisionNumber,
      orElse: () => LeagueDivision(
        number: divisionNumber,
        capacity: _divisionPolicy.capacityForDivision(divisionNumber),
      ),
    );
  }

  PlayerLeagueRecords _recordSubmittedRun(WeeklyLeagueRun run) {
    final previousRecords =
        _recordsByPlayerId[run.playerId] ??
        PlayerLeagueRecords.empty(run.playerId);

    final updatedRecords = _recordsCalculator.recordRun(
      previousRecords: previousRecords,
      finalScore: run.score,
      seasonId: LeagueSeasonId.fromDate(run.completedAt),
    );

    _recordsByPlayerId[run.playerId] = updatedRecords;
    return updatedRecords;
  }

  List<LeagueDivisionSettlement> _buildSeasonSettlements(
    LeagueSeasonId seasonId, {
    required DateTime settledAt,
  }) {
    final sortedDivisions = [..._divisions]
      ..sort((a, b) => a.number.compareTo(b.number));

    if (sortedDivisions.isEmpty) {
      return const [];
    }

    final seasonRuns = _runs
        .where(
          (run) =>
              LeagueSeasonId.fromDate(run.completedAt).value == seasonId.value,
        )
        .toList();
    final rankedByDivision = {
      for (final division in sortedDivisions)
        division.number: _rankingCalculator.rank(
          entries: _entriesByPlayerId.values.toList(),
          runs: seasonRuns,
          divisionNumber: division.number,
        ),
    };

    if (sortedDivisions.length == 1) {
      final division = sortedDivisions.single;
      final rankedEntries = rankedByDivision[division.number] ?? const [];
      final settlement = LeagueDivisionSettlement(
        divisionNumber: division.number,
        keptPlayerIds: rankedEntries
            .map((entry) => entry.playerEntry.playerId)
            .toList(),
      );
      _recordHistoryEntries(
        seasonId: seasonId,
        rankedEntries: rankedEntries,
        settlement: settlement,
        settledAt: settledAt,
      );
      return [settlement];
    }

    final settlements = <LeagueDivisionSettlement>[];
    final promotedIds = <String>{};
    final relegatedIds = <String>{};

    for (var index = 0; index < sortedDivisions.length - 2; index += 1) {
      final division = sortedDivisions[index];
      final lowerDivision = sortedDivisions[index + 1];
      final rankedEntries = rankedByDivision[division.number] ?? const [];
      final lowerRankedEntries =
          rankedByDivision[lowerDivision.number] ?? const [];
      final relegatedPlayerIds = _settlementCalculator
          .relegatedPlayerIdsForDivision(
            division: division,
            isLastDivision: false,
            rankedEntries: rankedEntries,
          );
      final promotedPlayerIds = _settlementCalculator
          .promotedPlayerIdsForLowerDivision(
            lowerDivision: lowerDivision,
            aboveDivisionRelegationCount: relegatedPlayerIds.length,
            lowerDivisionRankedEntries: lowerRankedEntries,
          );
      final settlement = LeagueDivisionSettlement(
        divisionNumber: division.number,
        promotedPlayerIds: promotedPlayerIds,
        relegatedPlayerIds: relegatedPlayerIds,
        keptPlayerIds: rankedEntries
            .map((entry) => entry.playerEntry.playerId)
            .where((playerId) => !relegatedPlayerIds.contains(playerId))
            .toList(),
      );

      settlements.add(settlement);
      promotedIds.addAll(promotedPlayerIds);
      relegatedIds.addAll(relegatedPlayerIds);
      _recordHistoryEntries(
        seasonId: seasonId,
        rankedEntries: rankedEntries,
        settlement: settlement,
        settledAt: settledAt,
      );
    }

    final penultimateDivision = sortedDivisions[sortedDivisions.length - 2];
    final lastDivision = sortedDivisions.last;
    final specialSettlement = _settlementCalculator
        .settlePenultimateAndLastDivision(
          penultimateDivision: penultimateDivision,
          lastDivision: lastDivision,
          penultimateRankedEntries:
              rankedByDivision[penultimateDivision.number] ?? const [],
          lastRankedEntries: rankedByDivision[lastDivision.number] ?? const [],
        );
    settlements.add(specialSettlement);
    promotedIds.addAll(specialSettlement.promotedPlayerIds);
    relegatedIds.addAll(specialSettlement.relegatedPlayerIds);
    _recordHistoryEntries(
      seasonId: seasonId,
      rankedEntries: [
        ...?rankedByDivision[penultimateDivision.number],
        ...?rankedByDivision[lastDivision.number],
      ],
      settlement: specialSettlement,
      settledAt: settledAt,
    );

    return settlements;
  }

  void _recordHistoryEntries({
    required LeagueSeasonId seasonId,
    required List<LeagueRankingEntry> rankedEntries,
    required LeagueDivisionSettlement settlement,
    required DateTime settledAt,
  }) {
    for (final rankedEntry in rankedEntries) {
      final historyEntry = _historyGenerator.generate(
        seasonId: seasonId,
        finalRankingEntry: rankedEntry,
        settlement: settlement,
        seasonEndedAt: settledAt,
      );
      _historyByPlayerId
          .putIfAbsent(historyEntry.playerId, () => [])
          .add(historyEntry);
    }
  }

  DateTime _historySortDate(WeeklyLeagueHistoryEntry entry) {
    return entry.seasonEndedAt ?? entry.seasonId.weekStartDate;
  }

  void _applySeasonSettlements(List<LeagueDivisionSettlement> settlements) {
    final lostReservationIds = <String>{
      for (final settlement in settlements)
        ...settlement.lostReservationPlayerIds,
    };
    final activePlayerIds = _entriesByPlayerId.values
        .where((entry) => entry.isActive)
        .map((entry) => entry.playerId)
        .toSet();

    for (final settlement in settlements) {
      for (final playerId in settlement.promotedPlayerIds) {
        _movePlayer(playerId: playerId, divisionDelta: -1);
      }
      for (final playerId in settlement.relegatedPlayerIds) {
        _movePlayer(playerId: playerId, divisionDelta: 1);
      }
    }

    final closedDivisionNumbers = settlements
        .where((settlement) => settlement.closedDivision)
        .map((settlement) => settlement.divisionNumber + 1)
        .toSet();
    _divisions.removeWhere(
      (division) => closedDivisionNumbers.contains(division.number),
    );
    _entriesByPlayerId.removeWhere(
      (_, entry) => closedDivisionNumbers.contains(entry.divisionNumber),
    );

    _entriesByPlayerId.updateAll((_, entry) {
      // Entry payment is reset for the next week, but reservation rights depend
      // on settlement status. Active players keep their slot after moving;
      // inactive players marked by settlement lose reservation unless they were
      // already removed because their division closed.
      return entry.copyWith(
        entryPaid: false,
        hasReservedSlot:
            activePlayerIds.contains(entry.playerId) ||
            !lostReservationIds.contains(entry.playerId),
      );
    });
  }

  void _movePlayer({required String playerId, required int divisionDelta}) {
    final entry = _entriesByPlayerId[playerId];
    if (entry == null) {
      return;
    }

    _entriesByPlayerId[playerId] = entry.copyWith(
      divisionNumber: math.max(1, entry.divisionNumber + divisionDelta),
      hasReservedSlot: true,
    );
  }

  void _clearSettledSeasonRuns(LeagueSeasonId seasonId) {
    _runs.removeWhere(
      (run) => LeagueSeasonId.fromDate(run.completedAt).value == seasonId.value,
    );
  }

  void _seedMockLeague() {
    _divisions.addAll(const [
      LeagueDivision(number: 1, capacity: 10),
      LeagueDivision(number: 2, capacity: 20),
    ]);

    for (var index = 0; index < 10; index += 1) {
      _addSeedPlayer(
        playerId: 'mock-d1-$index',
        username: 'Division 1 Player ${index + 1}',
        divisionNumber: 1,
        score: 22000 - index * 650,
      );
    }

    for (var index = 0; index < 8; index += 1) {
      _addSeedPlayer(
        playerId: 'mock-d2-active-$index',
        username: 'Division 2 Player ${index + 1}',
        divisionNumber: 2,
        score: 12000 - index * 450,
      );
    }

    for (var index = 0; index < 2; index += 1) {
      final entry = LeaguePlayerEntry(
        playerId: 'mock-d2-inactive-$index',
        username: 'Inactive Player ${index + 1}',
        divisionNumber: 2,
        registeredAt: DateTime(2026, 1, 1).add(Duration(days: index)),
        entryPaid: false,
      );

      _entriesByPlayerId[entry.playerId] = entry;
    }
  }

  void _addSeedPlayer({
    required String playerId,
    required String username,
    required int divisionNumber,
    required int score,
  }) {
    final entry = LeaguePlayerEntry(
      playerId: playerId,
      username: username,
      divisionNumber: divisionNumber,
      registeredAt: DateTime(2026, 1, 1),
      entryPaid: true,
    );

    _entriesByPlayerId[playerId] = entry;

    final run = WeeklyLeagueRun(
      playerId: playerId,
      score: score,
      completedAt: DateTime(2026, 5, 4, 12),
    );

    _runs.add(run);
    _recordSubmittedRun(run);
  }
}
