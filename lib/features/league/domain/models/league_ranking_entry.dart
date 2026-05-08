import 'league_player_entry.dart';
import 'weekly_league_score.dart';

class LeagueRankingEntry {
  const LeagueRankingEntry({
    required this.rank,
    required this.playerEntry,
    required this.weeklyScore,
  }) : assert(rank > 0);

  final int rank;
  final LeaguePlayerEntry playerEntry;
  final WeeklyLeagueScore weeklyScore;

  bool get isInactive => !weeklyScore.isActive;

  String get displayScore => weeklyScore.displayScore;
}
