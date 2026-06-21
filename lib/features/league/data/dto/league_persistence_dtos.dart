import 'package:stoppy_app/core/backend/json_reader.dart';

import '../../domain/models/league_division.dart';
import '../../domain/models/league_player_entry.dart';
import '../../domain/models/league_season_id.dart';
import '../../domain/models/player_league_achievements.dart';
import '../../domain/models/player_league_records.dart';
import '../../domain/models/weekly_league_history_entry.dart';
import '../../domain/models/weekly_league_score.dart';

class LeagueDivisionDto {
  const LeagueDivisionDto({required this.number, required this.capacity});

  final int number;
  final int capacity;

  factory LeagueDivisionDto.fromDomain(LeagueDivision division) {
    return LeagueDivisionDto(
      number: division.number,
      capacity: division.capacity,
    );
  }

  factory LeagueDivisionDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(json, context: 'LeagueDivisionDto');
    return LeagueDivisionDto(
      number: reader.requiredPositiveInt('number'),
      capacity: reader.requiredPositiveInt('capacity'),
    );
  }

  LeagueDivision toDomain() =>
      LeagueDivision(number: number, capacity: capacity);

  Map<String, Object?> toJson() => {'number': number, 'capacity': capacity};
}

class LeaguePlayerEntryDto {
  const LeaguePlayerEntryDto({
    required this.playerId,
    required this.username,
    required this.divisionNumber,
    required this.hasReservedSlot,
    required this.entryPaid,
    required this.registeredAt,
    required this.lifetimeLeagueTournamentRuns,
    required this.lifetimeAverageScorePerRun,
  });

  final String playerId;
  final String username;
  final int divisionNumber;
  final bool hasReservedSlot;
  final bool entryPaid;
  final DateTime registeredAt;
  final int lifetimeLeagueTournamentRuns;
  final double lifetimeAverageScorePerRun;

  factory LeaguePlayerEntryDto.fromDomain(LeaguePlayerEntry entry) {
    return LeaguePlayerEntryDto(
      playerId: entry.playerId,
      username: entry.username,
      divisionNumber: entry.divisionNumber,
      hasReservedSlot: entry.hasReservedSlot,
      entryPaid: entry.entryPaid,
      registeredAt: entry.registeredAt,
      lifetimeLeagueTournamentRuns: entry.lifetimeLeagueTournamentRuns,
      lifetimeAverageScorePerRun: entry.lifetimeAverageScorePerRun,
    );
  }

  factory LeaguePlayerEntryDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(json, context: 'LeaguePlayerEntryDto');
    return LeaguePlayerEntryDto(
      playerId: reader.requiredString('playerId'),
      username: reader.requiredString('username'),
      divisionNumber: reader.requiredPositiveInt('divisionNumber'),
      hasReservedSlot: reader.optionalBool(
        'hasReservedSlot',
        defaultValue: true,
      ),
      entryPaid: reader.optionalBool('entryPaid', defaultValue: false),
      registeredAt: reader.requiredDateTime('registeredAt'),
      lifetimeLeagueTournamentRuns: reader.optionalInt(
        'lifetimeLeagueTournamentRuns',
        defaultValue: 0,
      ),
      lifetimeAverageScorePerRun: reader.optionalDouble(
        'lifetimeAverageScorePerRun',
        defaultValue: 0,
      ),
    );
  }

  LeaguePlayerEntry toDomain() => LeaguePlayerEntry(
    playerId: playerId,
    username: username,
    divisionNumber: divisionNumber,
    hasReservedSlot: hasReservedSlot,
    entryPaid: entryPaid,
    registeredAt: registeredAt,
    lifetimeLeagueTournamentRuns: lifetimeLeagueTournamentRuns,
    lifetimeAverageScorePerRun: lifetimeAverageScorePerRun,
  );

  Map<String, Object?> toJson() => {
    'playerId': playerId,
    'username': username,
    'divisionNumber': divisionNumber,
    'hasReservedSlot': hasReservedSlot,
    'entryPaid': entryPaid,
    'registeredAt': registeredAt.toIso8601String(),
    'lifetimeLeagueTournamentRuns': lifetimeLeagueTournamentRuns,
    'lifetimeAverageScorePerRun': lifetimeAverageScorePerRun,
  };
}

class WeeklyLeagueScoreDto {
  const WeeklyLeagueScoreDto({
    required this.playerId,
    required this.isActive,
    required this.runCount,
    required this.activeDays,
    required this.activityMultiplier,
    required this.baseScore,
    required this.finalScore,
    required this.bonusPoints,
    required this.countedRunScores,
    required this.allRunScores,
  });

  final String playerId;
  final bool isActive;
  final int runCount;
  final int activeDays;
  final double activityMultiplier;
  final double baseScore;
  final double finalScore;
  final double bonusPoints;
  final List<int> countedRunScores;
  final List<int> allRunScores;

  factory WeeklyLeagueScoreDto.fromDomain(WeeklyLeagueScore score) {
    return WeeklyLeagueScoreDto(
      playerId: score.playerId,
      isActive: score.isActive,
      runCount: score.runCount,
      activeDays: score.activeDays,
      activityMultiplier: score.activityMultiplier,
      baseScore: score.baseScore,
      finalScore: score.finalScore,
      bonusPoints: score.bonusPoints,
      countedRunScores: score.countedRunScores,
      allRunScores: score.allRunScores,
    );
  }

  factory WeeklyLeagueScoreDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(json, context: 'WeeklyLeagueScoreDto');
    return WeeklyLeagueScoreDto(
      playerId: reader.requiredString('playerId'),
      isActive: reader.requiredBool('isActive'),
      runCount: reader.requiredNonNegativeInt('runCount'),
      activeDays: reader.requiredNonNegativeInt('activeDays'),
      activityMultiplier: reader.requiredDouble('activityMultiplier'),
      baseScore: reader.requiredDouble('baseScore'),
      finalScore: reader.requiredDouble('finalScore'),
      bonusPoints: reader.requiredDouble('bonusPoints'),
      countedRunScores: reader.optionalIntList('countedRunScores'),
      allRunScores: reader.optionalIntList('allRunScores'),
    );
  }

  WeeklyLeagueScore toDomain() => WeeklyLeagueScore(
    playerId: playerId,
    isActive: isActive,
    runCount: runCount,
    activeDays: activeDays,
    activityMultiplier: activityMultiplier,
    baseScore: baseScore,
    finalScore: finalScore,
    bonusPoints: bonusPoints,
    countedRunScores: countedRunScores,
    allRunScores: allRunScores,
  );

  Map<String, Object?> toJson() => {
    'playerId': playerId,
    'isActive': isActive,
    'runCount': runCount,
    'activeDays': activeDays,
    'activityMultiplier': activityMultiplier,
    'baseScore': baseScore,
    'finalScore': finalScore,
    'bonusPoints': bonusPoints,
    'countedRunScores': countedRunScores,
    'allRunScores': allRunScores,
  };
}

class WeeklyLeagueHistoryEntryDto {
  const WeeklyLeagueHistoryEntryDto({
    required this.playerId,
    required this.seasonId,
    required this.finalRank,
    required this.finalDivision,
    required this.result,
    required this.finalWeeklyScore,
    this.seasonEndedAt,
  });

  final String playerId;
  final String seasonId;
  final int finalRank;
  final int finalDivision;
  final WeeklyLeagueSeasonResult result;
  final double finalWeeklyScore;
  final DateTime? seasonEndedAt;

  factory WeeklyLeagueHistoryEntryDto.fromDomain(
    WeeklyLeagueHistoryEntry entry,
  ) {
    return WeeklyLeagueHistoryEntryDto(
      playerId: entry.playerId,
      seasonId: entry.seasonId.value,
      finalRank: entry.finalRank,
      finalDivision: entry.finalDivision,
      result: entry.result,
      finalWeeklyScore: entry.finalWeeklyScore,
      seasonEndedAt: entry.seasonEndedAt,
    );
  }

  factory WeeklyLeagueHistoryEntryDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'WeeklyLeagueHistoryEntryDto',
    );
    return WeeklyLeagueHistoryEntryDto(
      playerId: reader.requiredString('playerId'),
      seasonId: reader.requiredString('seasonId'),
      finalRank: reader.requiredPositiveInt('finalRank'),
      finalDivision: reader.requiredPositiveInt('finalDivision'),
      result: _seasonResultFromName(reader.requiredString('result')),
      finalWeeklyScore: reader.requiredDouble('finalWeeklyScore'),
      seasonEndedAt: reader.optionalDateTime('seasonEndedAt'),
    );
  }

  WeeklyLeagueHistoryEntry toDomain() => WeeklyLeagueHistoryEntry(
    playerId: playerId,
    seasonId: LeagueSeasonId(weekStartDate: _seasonDate(seasonId)),
    finalRank: finalRank,
    finalDivision: finalDivision,
    result: result,
    finalWeeklyScore: finalWeeklyScore,
    seasonEndedAt: seasonEndedAt,
  );

  Map<String, Object?> toJson() => {
    'playerId': playerId,
    'seasonId': seasonId,
    'finalRank': finalRank,
    'finalDivision': finalDivision,
    'result': result.name,
    'finalWeeklyScore': finalWeeklyScore,
    'seasonEndedAt': seasonEndedAt?.toIso8601String(),
  };
}

class PlayerLeagueRecordsDto {
  const PlayerLeagueRecordsDto({
    required this.playerId,
    required this.allTimeBestFinalScore,
    required this.currentWeeklyBestScore,
    this.currentSeasonId,
  });

  final String playerId;
  final int allTimeBestFinalScore;
  final int currentWeeklyBestScore;
  final String? currentSeasonId;

  factory PlayerLeagueRecordsDto.fromDomain(PlayerLeagueRecords records) {
    return PlayerLeagueRecordsDto(
      playerId: records.playerId,
      allTimeBestFinalScore: records.allTimeBestFinalScore,
      currentWeeklyBestScore: records.currentWeeklyBestScore,
      currentSeasonId: records.currentSeasonId?.value,
    );
  }

  factory PlayerLeagueRecordsDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'PlayerLeagueRecordsDto',
    );
    return PlayerLeagueRecordsDto(
      playerId: reader.requiredString('playerId'),
      allTimeBestFinalScore: reader.requiredNonNegativeInt(
        'allTimeBestFinalScore',
      ),
      currentWeeklyBestScore: reader.requiredNonNegativeInt(
        'currentWeeklyBestScore',
      ),
      currentSeasonId: reader.optionalString('currentSeasonId'),
    );
  }

  PlayerLeagueRecords toDomain() => PlayerLeagueRecords(
    playerId: playerId,
    allTimeBestFinalScore: allTimeBestFinalScore,
    currentWeeklyBestScore: currentWeeklyBestScore,
    currentSeasonId: currentSeasonId == null
        ? null
        : LeagueSeasonId(weekStartDate: _seasonDate(currentSeasonId!)),
  );

  Map<String, Object?> toJson() => {
    'playerId': playerId,
    'allTimeBestFinalScore': allTimeBestFinalScore,
    'currentWeeklyBestScore': currentWeeklyBestScore,
    'currentSeasonId': currentSeasonId,
  };
}

class PlayerLeagueAchievementsDto {
  const PlayerLeagueAchievementsDto({
    required this.playerId,
    this.bestDivisionReached,
    required this.promotions,
    required this.relegations,
  });

  final String playerId;
  final int? bestDivisionReached;
  final int promotions;
  final int relegations;

  factory PlayerLeagueAchievementsDto.fromDomain(
    PlayerLeagueAchievements achievements,
  ) {
    return PlayerLeagueAchievementsDto(
      playerId: achievements.playerId,
      bestDivisionReached: achievements.bestDivisionReached,
      promotions: achievements.promotions,
      relegations: achievements.relegations,
    );
  }

  factory PlayerLeagueAchievementsDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'PlayerLeagueAchievementsDto',
    );
    final bestDivision = reader.optionalPositiveInt('bestDivisionReached');
    return PlayerLeagueAchievementsDto(
      playerId: reader.requiredString('playerId'),
      bestDivisionReached: bestDivision,
      promotions: reader.requiredNonNegativeInt('promotions'),
      relegations: reader.requiredNonNegativeInt('relegations'),
    );
  }

  PlayerLeagueAchievements toDomain() => PlayerLeagueAchievements(
    playerId: playerId,
    bestDivisionReached: bestDivisionReached,
    promotions: promotions,
    relegations: relegations,
  );

  Map<String, Object?> toJson() => {
    'playerId': playerId,
    'bestDivisionReached': bestDivisionReached,
    'promotions': promotions,
    'relegations': relegations,
  };
}

WeeklyLeagueSeasonResult _seasonResultFromName(String value) {
  for (final result in WeeklyLeagueSeasonResult.values) {
    if (result.name == value) {
      return result;
    }
  }
  throw FormatException('Unknown weekly league season result: $value');
}

DateTime _seasonDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid league season identifier: $value');
  }
  return parsed;
}
