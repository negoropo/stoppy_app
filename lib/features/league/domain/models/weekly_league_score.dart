import 'dart:collection';

class WeeklyLeagueScore {
  WeeklyLeagueScore({
    required this.playerId,
    required this.isActive,
    required this.runCount,
    required this.activeDays,
    required this.activityMultiplier,
    required this.baseScore,
    required this.finalScore,
    required this.bonusPoints,
    required List<int> countedRunScores,
    required List<int> allRunScores,
  }) : assert(runCount >= 0),
       assert(activeDays >= 0 && activeDays <= 7),
       assert(activityMultiplier >= 0),
       assert(baseScore >= 0),
       assert(finalScore >= 0),
       assert(bonusPoints >= 0),
       countedRunScores = UnmodifiableListView(countedRunScores),
       allRunScores = UnmodifiableListView(allRunScores);

  final String playerId;
  final bool isActive;
  final int runCount;
  final int activeDays;
  final double activityMultiplier;
  final double baseScore;
  final double finalScore;
  final double bonusPoints;
  final List<int> countedRunScores;
  final List<int> allRunScores;

  String get displayScore {
    if (!isActive) {
      return 'inactive';
    }

    return finalScore.round().toString();
  }

  double get averageScorePerWeeklyRun {
    if (allRunScores.isEmpty) {
      return 0;
    }

    return allRunScores.reduce((a, b) => a + b) / allRunScores.length;
  }

  int bestRunAt(int index) {
    if (index < 0) {
      return 0;
    }

    final sortedScores = [...allRunScores]..sort((a, b) => b.compareTo(a));
    if (index >= sortedScores.length) {
      return 0;
    }

    return sortedScores[index];
  }
}
