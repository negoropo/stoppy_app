enum KnockoutTournamentOutcome { champion, eliminated }

extension KnockoutTournamentOutcomeLabel on KnockoutTournamentOutcome {
  String get label {
    return switch (this) {
      KnockoutTournamentOutcome.champion => 'Champion',
      KnockoutTournamentOutcome.eliminated => 'Eliminated',
    };
  }
}

class KnockoutTournamentHistoryEntry {
  const KnockoutTournamentHistoryEntry({
    required this.tournamentId,
    required this.tournamentName,
    required this.tournamentMonth,
    required this.playerId,
    this.playerUsername,
    required this.outcome,
    required this.finalRoundNumber,
    required this.completedAt,
  }) : assert(tournamentId != ''),
       assert(tournamentName != ''),
       assert(playerId != ''),
       assert(finalRoundNumber > 0);

  final String tournamentId;
  final String tournamentName;
  final DateTime tournamentMonth;
  final String playerId;
  final String? playerUsername;
  final KnockoutTournamentOutcome outcome;
  final int finalRoundNumber;
  final DateTime completedAt;

  bool get wasChampion {
    return outcome == KnockoutTournamentOutcome.champion;
  }
}
