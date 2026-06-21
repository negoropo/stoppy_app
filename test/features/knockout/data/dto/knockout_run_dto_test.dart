import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/features/knockout/data/dto/knockout_run_dto.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_run.dart';

void main() {
  test('KnockoutRunDto round-trips domain run JSON', () {
    final run = KnockoutRun(
      id: 'run-id',
      roundNumber: 3,
      matchId: 'match-id',
      playerId: 'player-id',
      score: 45000,
      completedAt: DateTime(2026, 6, 3, 19),
    );

    final dto = KnockoutRunDto.fromDomain(run);
    final decoded = KnockoutRunDto.fromJson(dto.toJson()).toDomain();
    final mapperDecoded = const KnockoutRunMapper().toDomain(
      const KnockoutRunMapper().toDto(run),
    );

    expect(decoded.id, run.id);
    expect(decoded.roundNumber, run.roundNumber);
    expect(decoded.matchId, run.matchId);
    expect(decoded.playerId, run.playerId);
    expect(decoded.score, run.score);
    expect(decoded.completedAt, run.completedAt);
    expect(mapperDecoded.id, run.id);
    expect(mapperDecoded.roundNumber, run.roundNumber);
    expect(mapperDecoded.matchId, run.matchId);
    expect(mapperDecoded.playerId, run.playerId);
    expect(mapperDecoded.score, run.score);
    expect(mapperDecoded.completedAt, run.completedAt);
  });

  test('KnockoutRunDto rejects malformed run payloads', () {
    expect(
      () => KnockoutRunDto.fromJson({
        'id': 'run-id',
        'roundNumber': 1,
        'matchId': 'match-id',
        'playerId': 'player-id',
        'score': 45000,
        'completedAt': false,
      }),
      throwsA(
        isA<ApiException>().having(
          (exception) => exception.error.code,
          'code',
          ApiErrorCode.malformedPayload,
        ),
      ),
    );
  });
}
