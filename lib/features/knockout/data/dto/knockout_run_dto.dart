import '../../domain/models/knockout_run.dart';

class KnockoutRunDto {
  const KnockoutRunDto({
    required this.id,
    required this.roundNumber,
    required this.matchId,
    required this.playerId,
    required this.score,
    required this.completedAt,
  });

  final String id;
  final int roundNumber;
  final String matchId;
  final String playerId;
  final int score;
  final DateTime completedAt;

  factory KnockoutRunDto.fromDomain(KnockoutRun run) {
    return KnockoutRunDto(
      id: run.id,
      roundNumber: run.roundNumber,
      matchId: run.matchId,
      playerId: run.playerId,
      score: run.score,
      completedAt: run.completedAt,
    );
  }

  factory KnockoutRunDto.fromJson(Map<String, Object?> json) {
    return KnockoutRunDto(
      id: json['id'] as String,
      roundNumber: json['roundNumber'] as int,
      matchId: json['matchId'] as String,
      playerId: json['playerId'] as String,
      score: json['score'] as int,
      completedAt: DateTime.parse(json['completedAt'] as String),
    );
  }

  KnockoutRun toDomain() {
    return KnockoutRun(
      id: id,
      roundNumber: roundNumber,
      matchId: matchId,
      playerId: playerId,
      score: score,
      completedAt: completedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'roundNumber': roundNumber,
      'matchId': matchId,
      'playerId': playerId,
      'score': score,
      'completedAt': completedAt.toIso8601String(),
    };
  }
}
