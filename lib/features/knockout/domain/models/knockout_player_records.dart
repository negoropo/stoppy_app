class KnockoutPlayerRecords {
  const KnockoutPlayerRecords({
    required this.playerId,
    this.tournamentsPlayed = 0,
    this.tournamentsWon = 0,
    this.highestRoundReached = 0,
    this.bestDuelScore = 0,
  }) : assert(playerId != ''),
       assert(tournamentsPlayed >= 0),
       assert(tournamentsWon >= 0),
       assert(tournamentsWon <= tournamentsPlayed),
       assert(highestRoundReached >= 0),
       assert(bestDuelScore >= 0);

  factory KnockoutPlayerRecords.empty(String playerId) {
    return KnockoutPlayerRecords(playerId: playerId);
  }

  final String playerId;
  final int tournamentsPlayed;
  final int tournamentsWon;
  final int highestRoundReached;
  final int bestDuelScore;

  KnockoutPlayerRecords copyWith({
    String? playerId,
    int? tournamentsPlayed,
    int? tournamentsWon,
    int? highestRoundReached,
    int? bestDuelScore,
  }) {
    return KnockoutPlayerRecords(
      playerId: playerId ?? this.playerId,
      tournamentsPlayed: tournamentsPlayed ?? this.tournamentsPlayed,
      tournamentsWon: tournamentsWon ?? this.tournamentsWon,
      highestRoundReached: highestRoundReached ?? this.highestRoundReached,
      bestDuelScore: bestDuelScore ?? this.bestDuelScore,
    );
  }
}
