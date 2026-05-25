import 'dart:collection';

class KnockoutDuelScore {
  KnockoutDuelScore({
    required this.playerId,
    required this.runCount,
    required this.baseScore,
    required List<int> countedRunScores,
    required List<int> allRunScores,
  }) : assert(playerId != ''),
       assert(runCount >= 0),
       assert(baseScore >= 0),
       assert(countedRunScores.length <= allRunScores.length),
       assert(runCount == allRunScores.length),
        assert(countedRunScores.every((score) => score >= 0)),
        assert(allRunScores.every((score) => score >= 0)),
       countedRunScores = UnmodifiableListView(countedRunScores),
       allRunScores = UnmodifiableListView(allRunScores);

  final String playerId;

  /// Total runs submitted during the duel.
  final int runCount;

  /// Final knockout duel score.
  ///
  /// Uses the same best-runs block logic as the weekly league,
  /// but without activity multipliers or bonus points.
  final double baseScore;

  /// Runs used for the final score calculation.
  final List<int> countedRunScores;

  /// All submitted duel runs.
  final List<int> allRunScores;

  int get bestRunsCount {
    return countedRunScores.length;
  }

  bool get hasRuns {
    return runCount > 0;
  }

  bool get hasNoRuns {
    return !hasRuns;
  }

  int get bestRunScore {
    if (allRunScores.isEmpty) {
      return 0;
    }

    return allRunScores.reduce(
      (current, next) => current > next ? current : next,
    );
  }

  KnockoutDuelScore copyWith({
    String? playerId,
    int? runCount,
    double? baseScore,
    List<int>? countedRunScores,
    List<int>? allRunScores,
  }) {
    return KnockoutDuelScore(
      playerId: playerId ?? this.playerId,
      runCount: runCount ?? this.runCount,
      baseScore: baseScore ?? this.baseScore,
      countedRunScores: countedRunScores ?? this.countedRunScores,
      allRunScores: allRunScores ?? this.allRunScores,
    );
  }
}
