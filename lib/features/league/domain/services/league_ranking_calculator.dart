import 'dart:math' as math;

import '../models/league_division.dart';
import '../models/league_player_entry.dart';
import '../models/league_ranking_entry.dart';
import '../models/league_ranking_snapshot.dart';
import '../models/weekly_league_run.dart';
import 'weekly_league_score_calculator.dart';

class LeagueRankingCalculator {
  const LeagueRankingCalculator({
    this.scoreCalculator = const WeeklyLeagueScoreCalculator(),
  });

  final WeeklyLeagueScoreCalculator scoreCalculator;

  List<LeagueRankingEntry> rank({
    required List<LeaguePlayerEntry> entries,
    required List<WeeklyLeagueRun> runs,
    required int divisionNumber,
  }) {
    final rankingEntries =
        entries
            .where((entry) => entry.divisionNumber == divisionNumber)
            // A player without a reserved slot is outside the weekly league.
            // Keeping that filter in the ranking domain avoids UI-specific
            // checks and keeps future backend ranking validation reproducible.
            .where((entry) => entry.hasReservedSlot)
            .map(
              (entry) => LeagueRankingEntry(
                rank: 1,
                playerEntry: entry,
                weeklyScore: scoreCalculator.calculate(
                  playerEntry: entry,
                  runs: runs,
                ),
              ),
            )
            .toList()
          ..sort(_compareRankingEntries);

    return [
      for (var index = 0; index < rankingEntries.length; index += 1)
        LeagueRankingEntry(
          rank: index + 1,
          playerEntry: rankingEntries[index].playerEntry,
          weeklyScore: rankingEntries[index].weeklyScore,
        ),
    ];
  }

  LeagueRankingSnapshot snapshotForPlayer({
    required String currentPlayerId,
    required LeagueDivision division,
    required List<LeagueRankingEntry> rankedEntries,
    required int promotionCount,
    required int relegationCount,
  }) {
    final currentIndex = rankedEntries.indexWhere(
      (entry) => entry.playerEntry.playerId == currentPlayerId,
    );

    if (currentIndex == -1) {
      throw ArgumentError.value(
        currentPlayerId,
        'currentPlayerId',
        'Current player must exist in the ranking.',
      );
    }

    final currentEntry = rankedEntries[currentIndex];
    final startIndex = math.max(0, currentIndex - 5);
    final endIndex = math.min(rankedEntries.length, currentIndex + 6);
    final promotionScore = division.isFirstDivision || promotionCount <= 0
        ? null
        : _scoreAtRank(rankedEntries, promotionCount);
    final stayRank = rankedEntries.length - relegationCount;
    final stayScore = relegationCount <= 0 || stayRank <= 0
        ? null
        : _scoreAtRank(rankedEntries, stayRank);

    return LeagueRankingSnapshot(
      currentPlayerRank: currentEntry.rank,
      currentPlayerEntry: currentEntry,
      playersAbove: rankedEntries
          .sublist(startIndex, currentIndex)
          .reversed
          .toList(),
      playersBelow: rankedEntries.sublist(currentIndex + 1, endIndex),
      // These display values are absolute targets, not deltas from the current
      // player. Adding one point makes the requirement explicit because equal
      // scores still fall back to tie breakers.
      scoreNeededForPromotionZone: promotionScore == null
          ? null
          : promotionScore + 1,
      scoreNeededToStayInDivision: stayScore == null ? null : stayScore + 1,
      promotionZoneEndRank: promotionScore == null ? null : promotionCount,
      relegationZoneStartRank: stayScore == null ? null : stayRank + 1,
    );
  }

  int _compareRankingEntries(LeagueRankingEntry a, LeagueRankingEntry b) {
    if (a.weeklyScore.isActive != b.weeklyScore.isActive) {
      return a.weeklyScore.isActive ? -1 : 1;
    }

    if (!a.weeklyScore.isActive && !b.weeklyScore.isActive) {
      return _compareDescending(
            a.playerEntry.lifetimeLeagueTournamentRuns,
            b.playerEntry.lifetimeLeagueTournamentRuns,
          )
          .ifEqual(
            _compareDescending(
              a.playerEntry.lifetimeAverageScorePerRun,
              b.playerEntry.lifetimeAverageScorePerRun,
            ),
          )
          .ifEqual(
            a.playerEntry.registeredAt.compareTo(b.playerEntry.registeredAt),
          );
    }

    return _compareDescending(
          a.weeklyScore.finalScore,
          b.weeklyScore.finalScore,
        )
        // Tie breakers are explicit and deterministic so the future backend
        // can reproduce the same league order without client trust.
        .ifEqual(
          _compareDescending(
            a.weeklyScore.activeDays,
            b.weeklyScore.activeDays,
          ),
        )
        .ifEqual(
          _compareDescending(a.weeklyScore.runCount, b.weeklyScore.runCount),
        )
        .ifEqual(
          _compareDescending(
            a.weeklyScore.averageScorePerWeeklyRun,
            b.weeklyScore.averageScorePerWeeklyRun,
          ),
        )
        .ifEqual(
          _compareDescending(
            a.weeklyScore.bestRunAt(0),
            b.weeklyScore.bestRunAt(0),
          ),
        )
        .ifEqual(
          _compareDescending(
            a.playerEntry.lifetimeLeagueTournamentRuns,
            b.playerEntry.lifetimeLeagueTournamentRuns,
          ),
        )
        .ifEqual(
          _compareDescending(
            a.playerEntry.lifetimeAverageScorePerRun,
            b.playerEntry.lifetimeAverageScorePerRun,
          ),
        )
        .ifEqual(
          a.playerEntry.registeredAt.compareTo(b.playerEntry.registeredAt),
        );
  }

  double? _scoreAtRank(List<LeagueRankingEntry> rankedEntries, int rank) {
    if (rank < 1 || rank > rankedEntries.length) {
      return null;
    }

    return rankedEntries[rank - 1].weeklyScore.finalScore;
  }

  int _compareDescending(num a, num b) {
    return b.compareTo(a);
  }
}

extension on int {
  int ifEqual(int fallback) {
    if (this != 0) {
      return this;
    }

    return fallback;
  }
}
