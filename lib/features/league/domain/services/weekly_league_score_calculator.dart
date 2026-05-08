import '../models/league_player_entry.dart';
import '../models/weekly_league_run.dart';
import '../models/weekly_league_score.dart';

class WeeklyLeagueScoreCalculator {
  const WeeklyLeagueScoreCalculator();

  /// Expects [runs] to already be filtered by the target
  /// league season/week before calculation.
  WeeklyLeagueScore calculate({
    required LeaguePlayerEntry playerEntry,
    required List<WeeklyLeagueRun> runs,
  }) {
    final playerRuns = runs
        .where((run) => run.playerId == playerEntry.playerId)
        .toList();

    if (!playerEntry.isActive) {
      return WeeklyLeagueScore(
        playerId: playerEntry.playerId,
        isActive: false,
        runCount: 0,
        activeDays: 0,
        activityMultiplier: 0,
        baseScore: 0,
        finalScore: 0,
        bonusPoints: 0,
        countedRunScores: const [],
        allRunScores: const [],
      );
    }

    final allRunScores = playerRuns.map((run) => run.score).toList();
    final activeDays = _activeDays(playerRuns);
    final activityMultiplier = multiplierForActiveDays(activeDays);
    final countedRunScores = _countedRunScores(allRunScores);
    final baseScore = countedRunScores.isEmpty
        ? 0.0
        : countedRunScores.reduce((a, b) => a + b) / countedRunScores.length;
    final finalScore = baseScore * activityMultiplier;

    // Bonus points are stored separately so future backend settlement can
    // audit the exact effect of weekly activity without recomputing the score.
    return WeeklyLeagueScore(
      playerId: playerEntry.playerId,
      isActive: true,
      runCount: allRunScores.length,
      activeDays: activeDays,
      activityMultiplier: activityMultiplier,
      baseScore: baseScore,
      finalScore: finalScore,
      bonusPoints: finalScore - baseScore,
      countedRunScores: countedRunScores,
      allRunScores: allRunScores,
    );
  }

  double multiplierForActiveDays(int activeDays) {
    return switch (activeDays.clamp(0, 7)) {
      0 => 0,
      1 => 1.0,
      2 => 1.1,
      3 => 1.2,
      4 => 1.4,
      5 => 1.6,
      6 => 1.8,
      _ => 2.0,
    };
  }

  List<int> _countedRunScores(List<int> scores) {
    if (scores.isEmpty) {
      return const [];
    }

    final sortedScores = [...scores]..sort((a, b) => b.compareTo(a));
    // Weekly scoring rewards consistency in blocks of five runs: the first
    // five runs count only the best run, then every extra block of five adds
    // one more counted run to the average.
    final countedRunCount = ((scores.length - 1) ~/ 5) + 1;

    return sortedScores.take(countedRunCount).toList();
  }

  int _activeDays(List<WeeklyLeagueRun> runs) {
    final days = runs.map((run) {
      final localCompletedAt = run.completedAt.toLocal();
      return DateTime(
        localCompletedAt.year,
        localCompletedAt.month,
        localCompletedAt.day,
      );
    }).toSet();

    return days.length.clamp(0, 7);
  }
}
