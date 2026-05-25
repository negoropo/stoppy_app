import 'knockout_match.dart';

class KnockoutDuelSnapshot {
  const KnockoutDuelSnapshot({
    required this.tournamentId,
    required this.roundNumber,
    required this.roundEndsAt,
    required this.playerId,
    required this.match,
    this.opponentId,
    this.playerScore = 0,
    this.opponentScore = 0,
    this.playerRunCount = 0,
    this.opponentRunCount = 0,
    this.hasBye = false,
  }) : assert(tournamentId != ''),
       assert(roundNumber > 0),
       assert(playerId != ''),
       assert(playerScore >= 0),
       assert(opponentScore >= 0),
       assert(playerRunCount >= 0),
       assert(opponentRunCount >= 0);

  final String tournamentId;
  final int roundNumber;
  final DateTime roundEndsAt;
  final String playerId;
  final String? opponentId;
  final KnockoutMatch match;
  final int playerScore;
  final int opponentScore;
  final int playerRunCount;
  final int opponentRunCount;

  /// A bye means the player is already carried into the next settlement pool.
  final bool hasBye;
}
