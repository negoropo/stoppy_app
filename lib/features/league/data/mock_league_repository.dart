import 'dart:math' as math;

import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/league/domain/models/league_division.dart';
import 'package:stoppy_app/features/league/domain/models/league_player_entry.dart';
import 'package:stoppy_app/features/league/domain/models/league_ranking_entry.dart';
import 'package:stoppy_app/features/league/domain/models/league_ranking_snapshot.dart';
import 'package:stoppy_app/features/league/domain/models/weekly_league_run.dart';
import 'package:stoppy_app/features/league/domain/repositories/league_repository.dart';
import 'package:stoppy_app/features/league/domain/services/league_division_policy.dart';
import 'package:stoppy_app/features/league/domain/services/league_ranking_calculator.dart';
import 'package:stoppy_app/features/league/domain/services/league_season_settlement_calculator.dart';

class MockLeagueRepository implements LeagueRepository {
  MockLeagueRepository({
    LeagueDivisionPolicy divisionPolicy = const LeagueDivisionPolicy(),
    LeagueRankingCalculator rankingCalculator = const LeagueRankingCalculator(),
    LeagueSeasonSettlementCalculator settlementCalculator =
        const LeagueSeasonSettlementCalculator(),
    bool seedMockData = true,
  }) : _divisionPolicy = divisionPolicy,
       _rankingCalculator = rankingCalculator,
       _settlementCalculator = settlementCalculator {
    if (seedMockData) {
      _seedMockLeague();
    }
  }

  final LeagueDivisionPolicy _divisionPolicy;
  final LeagueRankingCalculator _rankingCalculator;
  final LeagueSeasonSettlementCalculator _settlementCalculator;
  final List<LeagueDivision> _divisions = [];
  final Map<String, LeaguePlayerEntry> _entriesByPlayerId = {};
  final List<WeeklyLeagueRun> _runs = [];

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
  Future<void> submitLeagueRun(WeeklyLeagueRun run) async {
    final entry = _entriesByPlayerId[run.playerId];
    if (entry == null || !entry.isActive) {
      return;
    }

    _runs.add(run);
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

  LeagueDivision _divisionForNumber(int divisionNumber) {
    return _divisions.firstWhere(
      (division) => division.number == divisionNumber,
      orElse: () => LeagueDivision(
        number: divisionNumber,
        capacity: _divisionPolicy.capacityForDivision(divisionNumber),
      ),
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
    _runs.add(
      WeeklyLeagueRun(
        playerId: playerId,
        score: score,
        completedAt: DateTime(2026, 5, 4, 12),
      ),
    );
  }
}
