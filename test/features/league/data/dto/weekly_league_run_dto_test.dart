import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/league/data/dto/weekly_league_run_dto.dart';
import 'package:stoppy_app/features/league/domain/models/weekly_league_run.dart';

void main() {
  test('WeeklyLeagueRunDto round-trips domain run JSON', () {
    final run = WeeklyLeagueRun(
      playerId: 'player-id',
      score: 12000,
      completedAt: DateTime(2026, 6, 3, 18),
    );

    final dto = WeeklyLeagueRunDto.fromDomain(run);
    final decoded = WeeklyLeagueRunDto.fromJson(dto.toJson()).toDomain();

    expect(decoded.playerId, run.playerId);
    expect(decoded.score, run.score);
    expect(decoded.completedAt, run.completedAt);
  });
}
