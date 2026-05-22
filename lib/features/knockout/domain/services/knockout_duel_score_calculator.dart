import '../models/knockout_duel_score.dart';
import '../models/knockout_run.dart';

class KnockoutDuelScoreCalculator {
  const KnockoutDuelScoreCalculator();

  KnockoutDuelScore calculate({
    required String playerId,
    required List<KnockoutRun> runs,
  }) {
    assert(playerId != '');

    final allRunScores = runs
        .where((run) => run.playerId == playerId)
        .map((run) => run.score)
        .toList();

    final countedRunScores = _countedRunScores(allRunScores);

    final baseScore = countedRunScores.isEmpty
        ? 0.0
        : countedRunScores.reduce((a, b) => a + b) / countedRunScores.length;

    // Knockout duels deliberately reuse the league best-runs block rule but do
    // not apply activity multipliers or bonus points. A one-day duel should be
    // decided only by the selected run scores.
    return KnockoutDuelScore(
      playerId: playerId,
      runCount: allRunScores.length,
      baseScore: baseScore,
      countedRunScores: countedRunScores,
      allRunScores: allRunScores,
    );
  }

  List<int> _countedRunScores(List<int> scores) {
    if (scores.isEmpty) {
      return const [];
    }

    final sortedScores = [...scores]..sort((a, b) => b.compareTo(a));
    final countedRunCount = ((scores.length - 1) ~/ 5) + 1;

    return sortedScores.take(countedRunCount).toList();
  }
}