import 'dart:math';

import '../models/league_season_id.dart';
import '../models/player_league_records.dart';

class PlayerLeagueRecordsCalculator {
  const PlayerLeagueRecordsCalculator();

  PlayerLeagueRecords recordRun({
    required PlayerLeagueRecords previousRecords,
    required int finalScore,
    required LeagueSeasonId seasonId,
  }) {
    assert(finalScore >= 0);

    final isSameSeason =
        previousRecords.currentSeasonId?.value == seasonId.value;

    return previousRecords.copyWith(
      allTimeBestFinalScore: max(
        previousRecords.allTimeBestFinalScore,
        finalScore,
      ),
      currentWeeklyBestScore: isSameSeason
          ? max(previousRecords.currentWeeklyBestScore, finalScore)
          : finalScore,
      currentSeasonId: seasonId,
    );
  }
}
