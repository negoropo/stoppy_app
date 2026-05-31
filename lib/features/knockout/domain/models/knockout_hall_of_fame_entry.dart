class KnockoutHallOfFameEntry {
  const KnockoutHallOfFameEntry({
    required this.playerId,
    required this.displayName,
    required this.titlesWon,
  }) : assert(playerId != ''),
       assert(displayName != ''),
       assert(titlesWon > 0);

  final String playerId;
  final String displayName;
  final int titlesWon;

  String get titlesLabel {
    return titlesWon == 1 ? '1 title' : '$titlesWon titles';
  }
}
