import '../../domain/models/weekly_league_run.dart';

class WeeklyLeagueRunDto {
  const WeeklyLeagueRunDto({
    required this.playerId,
    required this.score,
    required this.completedAt,
  });

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

  factory WeeklyLeagueRunDto.fromJson(Map<String, Object?> json) {
    return WeeklyLeagueRunDto(
      playerId: json['playerId'] as String,
      score: json['score'] as int,
      completedAt: DateTime.parse(json['completedAt'] as String),
    );
  }

  WeeklyLeagueRun toDomain() {
    return WeeklyLeagueRun(
      playerId: playerId,
      score: score,
      completedAt: completedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'playerId': playerId,
      'score': score,
      'completedAt': completedAt.toIso8601String(),
    };
  }
}
