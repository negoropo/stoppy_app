class KnockoutRun {
  const KnockoutRun({
    required this.id,
    required this.playerId,
    required this.matchId,
    required this.roundNumber,
    required this.score,
    required this.completedAt,
  }) : assert(id != ''),
       assert(playerId != ''),
       assert(matchId != ''),
       assert(roundNumber > 0),
       assert(score >= 0);

  final String id;

  final String playerId;

  /// Match this run belongs to.
  final String matchId;

  /// Tournament round this run belongs to.
  final int roundNumber;

  final int score;

  final DateTime completedAt;

  KnockoutRun copyWith({
    String? id,
    String? playerId,
    String? matchId,
    int? roundNumber,
    int? score,
    DateTime? completedAt,
  }) {
    return KnockoutRun(
      id: id ?? this.id,
      playerId: playerId ?? this.playerId,
      matchId: matchId ?? this.matchId,
      roundNumber: roundNumber ?? this.roundNumber,
      score: score ?? this.score,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
