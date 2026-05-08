class LeaguePlayerEntry {
  const LeaguePlayerEntry({
    required this.playerId,
    required this.username,
    required this.divisionNumber,
    required this.registeredAt,
    this.hasReservedSlot = true,
    this.entryPaid = false,
    this.lifetimeLeagueTournamentRuns = 0,
    this.lifetimeAverageScorePerRun = 0,
  }) : assert(divisionNumber > 0),
       assert(lifetimeLeagueTournamentRuns >= 0),
       assert(lifetimeAverageScorePerRun >= 0);

  final String playerId;
  final String username;
  final int divisionNumber;
  final bool hasReservedSlot;
  final bool entryPaid;
  final DateTime registeredAt;
  final int lifetimeLeagueTournamentRuns;
  final double lifetimeAverageScorePerRun;

  bool get isActive => entryPaid;

  bool get isInactiveReserved => hasReservedSlot && !entryPaid;

  LeaguePlayerEntry markEntryPaid() {
    return copyWith(entryPaid: true);
  }

  LeaguePlayerEntry copyWith({
    String? playerId,
    String? username,
    int? divisionNumber,
    bool? hasReservedSlot,
    bool? entryPaid,
    DateTime? registeredAt,
    int? lifetimeLeagueTournamentRuns,
    double? lifetimeAverageScorePerRun,
  }) {
    return LeaguePlayerEntry(
      playerId: playerId ?? this.playerId,
      username: username ?? this.username,
      divisionNumber: divisionNumber ?? this.divisionNumber,
      hasReservedSlot: hasReservedSlot ?? this.hasReservedSlot,
      entryPaid: entryPaid ?? this.entryPaid,
      registeredAt: registeredAt ?? this.registeredAt,
      lifetimeLeagueTournamentRuns:
          lifetimeLeagueTournamentRuns ?? this.lifetimeLeagueTournamentRuns,
      lifetimeAverageScorePerRun:
          lifetimeAverageScorePerRun ?? this.lifetimeAverageScorePerRun,
    );
  }
}
