import 'package:stoppy_app/core/backend/domain_mapper.dart';
import 'package:stoppy_app/core/backend/json_reader.dart';

import '../../domain/models/weekly_league_run.dart';

class WeeklyLeagueRunDto {
  const WeeklyLeagueRunDto({
    required this.playerId,
    required this.score,
    required this.completedAt,
  });

  static const playerIdKey = 'playerId';
  static const scoreKey = 'score';
  static const completedAtKey = 'completedAt';

  final String playerId;
  final int score;
  final DateTime completedAt;

  factory WeeklyLeagueRunDto.fromDomain(WeeklyLeagueRun run) {
    return WeeklyLeagueRunDto(
      playerId: run.playerId,
      score: run.score,
      completedAt: run.completedAt,
    );
  }

  factory WeeklyLeagueRunDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(json, context: 'WeeklyLeagueRunDto');
    return WeeklyLeagueRunDto(
      playerId: reader.requiredString(playerIdKey),
      score: reader.requiredNonNegativeInt(scoreKey),
      completedAt: reader.requiredDateTime(completedAtKey),
    );
  }

  WeeklyLeagueRun toDomain() {
    return WeeklyLeagueRun(
      playerId: playerId,
      score: score,
      completedAt: completedAt,
    );
  }

  WeeklyLeagueRunDto copyWith({
    String? playerId,
    int? score,
    DateTime? completedAt,
  }) {
    return WeeklyLeagueRunDto(
      playerId: playerId ?? this.playerId,
      score: score ?? this.score,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      playerIdKey: playerId,
      scoreKey: score,
      completedAtKey: completedAt.toIso8601String(),
    };
  }
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
