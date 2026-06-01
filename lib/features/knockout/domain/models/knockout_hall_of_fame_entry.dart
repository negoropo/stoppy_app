class KnockoutHallOfFameEntry {
  KnockoutHallOfFameEntry({
    required this.playerId,
    required this.displayName,
    required this.titlesWon,
    List<DateTime> wonTournamentMonths = const [],
  }) : assert(playerId != ''),
        assert(displayName != ''),
        assert(titlesWon > 0),
        assert(
        wonTournamentMonths.isEmpty ||
            wonTournamentMonths.length == titlesWon,
        ),
        wonTournamentMonths = List.unmodifiable(
          [...wonTournamentMonths]..sort((a, b) => a.compareTo(b)),
        );

  final String playerId;
  final String displayName;
  final int titlesWon;
  final List<DateTime> wonTournamentMonths;
}