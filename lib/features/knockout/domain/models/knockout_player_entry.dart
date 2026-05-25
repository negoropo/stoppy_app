class KnockoutPlayerEntry {
  const KnockoutPlayerEntry({
    required this.playerId,
    required this.username,
    required this.tournamentId,
    required this.registeredAt,
    required this.accountCreatedAt,
    required this.entryCostGamePoints,
    this.lifetimeRunCount = 0,
    this.lifetimeAverageRunScore = 0,
  }) : assert(playerId != ''),
       assert(username != ''),
       assert(tournamentId != ''),
       assert(entryCostGamePoints >= 0),
       assert(lifetimeRunCount >= 0),
       assert(lifetimeAverageRunScore >= 0);

  final String playerId;
  final String username;

  final String tournamentId;

  final DateTime registeredAt;

  /// Used for deterministic repechage tie-breakers.
  final DateTime accountCreatedAt;

  final int entryCostGamePoints;

  /// Total runs performed across all game modes.
  final int lifetimeRunCount;

  /// Lifetime average score per run across all runs.
  final double lifetimeAverageRunScore;

  KnockoutPlayerEntry copyWith({
    String? playerId,
    String? username,
    String? tournamentId,
    DateTime? registeredAt,
    DateTime? accountCreatedAt,
    int? entryCostGamePoints,
    int? lifetimeRunCount,
    double? lifetimeAverageRunScore,
  }) {
    return KnockoutPlayerEntry(
      playerId: playerId ?? this.playerId,
      username: username ?? this.username,
      tournamentId: tournamentId ?? this.tournamentId,
      registeredAt: registeredAt ?? this.registeredAt,
      accountCreatedAt: accountCreatedAt ?? this.accountCreatedAt,
      entryCostGamePoints: entryCostGamePoints ?? this.entryCostGamePoints,
      lifetimeRunCount: lifetimeRunCount ?? this.lifetimeRunCount,
      lifetimeAverageRunScore:
          lifetimeAverageRunScore ?? this.lifetimeAverageRunScore,
    );
  }
}
