import 'package:stoppy_app/core/backend/domain_mapper.dart';
import 'package:stoppy_app/core/backend/json_reader.dart';

import '../../domain/models/league_season_id.dart';
import '../../domain/models/weekly_league_run.dart';

class WeeklyLeagueRunDto {
  const WeeklyLeagueRunDto({
    required this.playerId,
    required this.score,
    required this.completedAt,
    this.id,
    this.seasonId,
    this.startedAt,
    this.levelReached,
    this.precisionPointTier,
  });

  static const playerIdKey = 'playerId';
  static const scoreKey = 'score';
  static const completedAtKey = 'completedAt';
  static const idKey = 'id';
  static const seasonIdKey = 'seasonId';
  static const startedAtKey = 'startedAt';
  static const levelReachedKey = 'levelReached';
  static const precisionPointTierKey = 'precisionPointTier';

  final String playerId;
  final int score;
  final DateTime completedAt;
  final String? id;
  final LeagueSeasonId? seasonId;
  final DateTime? startedAt;
  final int? levelReached;
  final int? precisionPointTier;

  factory WeeklyLeagueRunDto.fromDomain(WeeklyLeagueRun run) {
    return WeeklyLeagueRunDto(
      playerId: run.playerId,
      score: run.score,
      completedAt: run.completedAt,
      id: run.id,
      seasonId: run.seasonId,
      startedAt: run.startedAt,
      levelReached: run.levelReached,
      precisionPointTier: run.precisionPointTier,
    );
  }

  factory WeeklyLeagueRunDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(json, context: 'WeeklyLeagueRunDto');
    return WeeklyLeagueRunDto(
      playerId: reader.requiredString(playerIdKey),
      score: reader.requiredNonNegativeInt(scoreKey),
      completedAt: reader.requiredDateTime(completedAtKey),
      id: reader.optionalString(idKey),
      seasonId: _optionalSeasonId(reader.optionalString(seasonIdKey)),
      startedAt: reader.optionalDateTime(startedAtKey),
      levelReached: reader.optionalPositiveInt(levelReachedKey),
      precisionPointTier: reader.optionalPositiveInt(precisionPointTierKey),
    );
  }

  WeeklyLeagueRun toDomain() {
    return WeeklyLeagueRun(
      playerId: playerId,
      score: score,
      completedAt: completedAt,
      id: id,
      seasonId: seasonId,
      startedAt: startedAt,
      levelReached: levelReached,
      precisionPointTier: precisionPointTier,
    );
  }

  WeeklyLeagueRunDto copyWith({
    String? playerId,
    int? score,
    DateTime? completedAt,
    String? id,
    LeagueSeasonId? seasonId,
    DateTime? startedAt,
    int? levelReached,
    int? precisionPointTier,
  }) {
    return WeeklyLeagueRunDto(
      playerId: playerId ?? this.playerId,
      score: score ?? this.score,
      completedAt: completedAt ?? this.completedAt,
      id: id ?? this.id,
      seasonId: seasonId ?? this.seasonId,
      startedAt: startedAt ?? this.startedAt,
      levelReached: levelReached ?? this.levelReached,
      precisionPointTier: precisionPointTier ?? this.precisionPointTier,
    );
  }

  Map<String, Object?> toJson() {
    return {
      if (id != null) idKey: id,
      playerIdKey: playerId,
      if (seasonId != null) seasonIdKey: seasonId!.value,
      if (startedAt != null) startedAtKey: startedAt!.toIso8601String(),
      scoreKey: score,
      completedAtKey: completedAt.toIso8601String(),
      if (levelReached != null) levelReachedKey: levelReached,
      if (precisionPointTier != null) precisionPointTierKey: precisionPointTier,
    };
  }
}

LeagueSeasonId? _optionalSeasonId(String? value) {
  if (value == null) {
    return null;
  }

  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid weekly league run season ID: $value.');
  }

  return LeagueSeasonId(weekStartDate: parsed);
}

class WeeklyLeagueRunMapper
    extends DomainMapper<WeeklyLeagueRun, WeeklyLeagueRunDto> {
  const WeeklyLeagueRunMapper();

  @override
  WeeklyLeagueRunDto toDto(WeeklyLeagueRun domain) {
    return WeeklyLeagueRunDto.fromDomain(domain);
  }

  @override
  WeeklyLeagueRun toDomain(WeeklyLeagueRunDto dto) {
    return dto.toDomain();
  }
}
