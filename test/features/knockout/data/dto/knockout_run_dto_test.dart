import 'package:flutter_test/flutter_test.dart';
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

    expect(decoded.id, run.id);
    expect(decoded.roundNumber, run.roundNumber);
    expect(decoded.matchId, run.matchId);
    expect(decoded.playerId, run.playerId);
    expect(decoded.score, run.score);
    expect(decoded.completedAt, run.completedAt);
  });
}
