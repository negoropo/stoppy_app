import 'package:stoppy_app/core/backend/domain_mapper.dart';

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

  static const idKey = 'id';
  static const roundNumberKey = 'roundNumber';
  static const matchIdKey = 'matchId';
  static const playerIdKey = 'playerId';
  static const scoreKey = 'score';
  static const completedAtKey = 'completedAt';

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
      id: json[idKey] as String,
      roundNumber: json[roundNumberKey] as int,
      matchId: json[matchIdKey] as String,
      playerId: json[playerIdKey] as String,
      score: json[scoreKey] as int,
      completedAt: DateTime.parse(json[completedAtKey] as String),
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

  KnockoutRunDto copyWith({
    String? id,
    int? roundNumber,
    String? matchId,
    String? playerId,
    int? score,
    DateTime? completedAt,
  }) {
    return KnockoutRunDto(
      id: id ?? this.id,
      roundNumber: roundNumber ?? this.roundNumber,
      matchId: matchId ?? this.matchId,
      playerId: playerId ?? this.playerId,
      score: score ?? this.score,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      idKey: id,
      roundNumberKey: roundNumber,
      matchIdKey: matchId,
      playerIdKey: playerId,
      scoreKey: score,
      completedAtKey: completedAt.toIso8601String(),
    };
  }
}

class KnockoutRunMapper extends DomainMapper<KnockoutRun, KnockoutRunDto> {
  const KnockoutRunMapper();

  @override
  KnockoutRunDto toDto(KnockoutRun domain) {
    return KnockoutRunDto.fromDomain(domain);
  }

  @override
  KnockoutRun toDomain(KnockoutRunDto dto) {
    return dto.toDomain();
  }
}