import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/features/league/data/dto/weekly_league_run_dto.dart';
import 'package:stoppy_app/features/league/domain/models/league_season_id.dart';
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
    final mapperDecoded = const WeeklyLeagueRunMapper().toDomain(
      const WeeklyLeagueRunMapper().toDto(run),
    );

    expect(decoded.playerId, run.playerId);
    expect(decoded.score, run.score);
    expect(decoded.completedAt, run.completedAt);
    expect(mapperDecoded.playerId, run.playerId);
    expect(mapperDecoded.score, run.score);
    expect(mapperDecoded.completedAt, run.completedAt);
  });

  test('WeeklyLeagueRunDto preserves optional backend claim metadata', () {
    final run = WeeklyLeagueRun(
      id: 'run-1',
      playerId: 'player-id',
      seasonId: LeagueSeasonId(weekStartDate: DateTime(2026, 6, 15)),
      startedAt: DateTime.utc(2026, 6, 21, 10),
      score: 12000,
      completedAt: DateTime.utc(2026, 6, 21, 10, 30),
      levelReached: 7,
      precisionPointTier: 5,
    );

    final decoded = WeeklyLeagueRunDto.fromJson(
      WeeklyLeagueRunDto.fromDomain(run).toJson(),
    ).toDomain();

    expect(decoded.id, 'run-1');
    expect(decoded.seasonId?.value, '2026-06-15');
    expect(decoded.startedAt, run.startedAt);
    expect(decoded.levelReached, 7);
    expect(decoded.precisionPointTier, 5);
  });

  test('WeeklyLeagueRunDto rejects malformed run payloads', () {
    expect(
      () => WeeklyLeagueRunDto.fromJson({
        'playerId': 'player-id',
        'score': '12000',
        'completedAt': '2026-06-21T10:00:00.000Z',
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
