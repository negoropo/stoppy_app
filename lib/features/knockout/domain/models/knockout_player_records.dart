class KnockoutPlayerRecords {
  const KnockoutPlayerRecords({
    required this.playerId,
    this.tournamentsPlayed = 0,
    this.tournamentsWon = 0,
    this.highestRoundReached = 0,
    this.totalDuelsPlayed = 0,
    this.totalDuelsWon = 0,
  }) : assert(playerId != ''),
       assert(tournamentsPlayed >= 0),
       assert(tournamentsWon >= 0),
       assert(tournamentsWon <= tournamentsPlayed),
       assert(highestRoundReached >= 0),
       assert(tournamentsPlayed > 0 || highestRoundReached == 0),
       assert(totalDuelsPlayed >= 0),
       assert(totalDuelsWon >= 0),
       assert(totalDuelsWon <= totalDuelsPlayed);

  factory KnockoutPlayerRecords.empty(String playerId) {
    return KnockoutPlayerRecords(playerId: playerId);
  }

  final String playerId;
  final int tournamentsPlayed;
  final int tournamentsWon;
  final int highestRoundReached;
  final int totalDuelsPlayed;
  final int totalDuelsWon;

  int get titlesWon {
    return tournamentsWon;
  }

  int get tournamentsParticipated {
    return tournamentsPlayed;
  }

  double get duelWinPercentage {
    if (totalDuelsPlayed == 0) {
      return 0;
    }
    return (totalDuelsWon / totalDuelsPlayed) * 100;
  }

  String get duelWinPercentageLabel {
    return '${duelWinPercentage.toStringAsFixed(1)}%';
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
    int? totalDuelsPlayed,
    int? totalDuelsWon,
  }) {
    return KnockoutPlayerRecords(
      playerId: playerId ?? this.playerId,
      tournamentsPlayed: tournamentsPlayed ?? this.tournamentsPlayed,
      tournamentsWon: tournamentsWon ?? this.tournamentsWon,
      highestRoundReached: highestRoundReached ?? this.highestRoundReached,
      totalDuelsPlayed: totalDuelsPlayed ?? this.totalDuelsPlayed,
      totalDuelsWon: totalDuelsWon ?? this.totalDuelsWon,
    );
  }
}
