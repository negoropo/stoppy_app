class KnockoutPlayerRecords {
  const KnockoutPlayerRecords({
    required this.playerId,
    this.tournamentsPlayed = 0,
    this.tournamentsWon = 0,
    this.highestRoundReached = 0,
  }) : assert(playerId != ''),
       assert(tournamentsPlayed >= 0),
       assert(tournamentsWon >= 0),
       assert(tournamentsWon <= tournamentsPlayed),
       assert(highestRoundReached >= 0);

  factory KnockoutPlayerRecords.empty(String playerId) {
    return KnockoutPlayerRecords(playerId: playerId);
  }

  final String playerId;
  final int tournamentsPlayed;
  final int tournamentsWon;
  final int highestRoundReached;

  int get titlesWon {
    return tournamentsWon;
  }

  String get bestTournamentResultLabel {
    if (tournamentsPlayed == 0) {
      return 'No completed tournaments';
    }
    if (titlesWon > 0) {
      return 'Champion';
    }
    return 'Round $highestRoundReached';
  }

  KnockoutPlayerRecords copyWith({
    String? playerId,
    int? tournamentsPlayed,
    int? tournamentsWon,
    int? highestRoundReached,
  }) {
    return KnockoutPlayerRecords(
      playerId: playerId ?? this.playerId,
      tournamentsPlayed: tournamentsPlayed ?? this.tournamentsPlayed,
      tournamentsWon: tournamentsWon ?? this.tournamentsWon,
      highestRoundReached: highestRoundReached ?? this.highestRoundReached,
    );
  }
}
