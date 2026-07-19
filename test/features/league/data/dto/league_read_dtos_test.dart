import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/features/league/data/dto/league_read_dtos.dart';
import 'package:stoppy_app/features/league/domain/models/league_ranking_snapshot.dart';
import 'package:stoppy_app/features/league/domain/models/weekly_league_history_entry.dart';

void main() {
  group('League read DTOs', () {
    test('maps a valid ranking snapshot to domain', () {
      final dto = LeagueRankingSnapshotDto.fromJson(_snapshotPayload());
      final snapshot = dto.toDomain();

      expect(snapshot, isA<LeagueRankingSnapshot>());
      expect(snapshot.currentPlayerRank, 2);
      expect(snapshot.currentPlayerEntry.playerEntry.playerId, 'player-1');
      expect(snapshot.playersAbove.single.rank, 1);
      expect(snapshot.playersBelow.single.rank, 3);
      expect(snapshot.scoreNeededForPromotionZone, 25001);
    });

    test('accepts empty ranking history and weekly run collections', () {
      expect(
        LeagueRankingResponseDto.fromJson({'entries': []}).toDomain(),
        isEmpty,
      );
      expect(
        LeagueHistoryResponseDto.fromJson({'entries': []}).toDomain(),
        isEmpty,
      );
      expect(
        LeagueWeeklyRunsResponseDto.fromJson({'runs': []}).toDomain(),
        isEmpty,
      );
    });

    test('maps a null current entry response to no league entry', () {
      expect(
        LeagueCurrentEntryResponseDto.fromJson({'entry': null}).toDomain(),
        isNull,
      );
    });

    test('rejects missing current entry wrapper field', () {
      expect(
        () => LeagueCurrentEntryResponseDto.fromJson({}),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects malformed ranking response payloads', () {
      expect(
        () => LeagueRankingResponseDto.fromJson({'entries': 'invalid'}),
        throwsA(isA<ApiException>()),
      );
    });

    test('rejects missing required snapshot fields', () {
      final payload = Map<String, Object?>.of(_snapshotPayload())
        ..remove('currentPlayerEntry');

      expect(
        () => LeagueRankingSnapshotDto.fromJson(payload),
        throwsA(isA<ApiException>()),
      );
    });

    test('rejects invalid history result enum values', () {
      expect(
        () => LeagueHistoryResponseDto.fromJson({
          'entries': [
            {
              'playerId': 'player-1',
              'seasonId': '2026-06-15',
              'finalRank': 2,
              'finalDivision': 1,
              'result': 'teleported',
              'finalWeeklyScore': 1000,
            },
          ],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects negative competitive values', () {
      final payload = _snapshotPayload();
      final currentEntry = Map<String, Object?>.of(
        payload['currentPlayerEntry']! as Map<String, Object?>,
      );
      final weeklyScore = Map<String, Object?>.of(
        currentEntry['weeklyScore']! as Map<String, Object?>,
      );
      weeklyScore['finalScore'] = -1;
      currentEntry['weeklyScore'] = weeklyScore;
      payload['currentPlayerEntry'] = currentEntry;

      expect(
        () => LeagueRankingSnapshotDto.fromJson(payload),
        throwsA(isA<ApiException>()),
      );
    });

    test('rejects inconsistent snapshot rank relationships', () {
      final payload = _snapshotPayload();
      payload['currentPlayerRank'] = 4;

      expect(
        () => LeagueRankingSnapshotDto.fromJson(payload),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects duplicate ranks in snapshot', () {
      final payload = _snapshotPayload();
      payload['currentPlayerRank'] = 3;
      payload['currentPlayerEntry'] = _rankingEntryPayload(
        rank: 3,
        playerId: 'player-1',
        username: 'Tester',
        score: 24000,
      );
      payload['playersAbove'] = [
        _rankingEntryPayload(
          rank: 1,
          playerId: 'player-2',
          username: 'Above',
          score: 26000,
        ),
        _rankingEntryPayload(
          rank: 1,
          playerId: 'player-4',
          username: 'Also Above',
          score: 25500,
        ),
      ];
      payload['playersBelow'] = [
        _rankingEntryPayload(
          rank: 4,
          playerId: 'player-3',
          username: 'Below',
          score: 21000,
        ),
      ];

      expect(
        () => LeagueRankingSnapshotDto.fromJson(payload),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects current player repeated above or below', () {
      for (final nearbyKey in ['playersAbove', 'playersBelow']) {
        final payload = _snapshotPayload();
        payload[nearbyKey] = [
          _rankingEntryPayload(
            rank: nearbyKey == 'playersAbove' ? 1 : 3,
            playerId: 'player-1',
            username: 'Repeated Tester',
            score: nearbyKey == 'playersAbove' ? 26000 : 21000,
          ),
        ];

        expect(
              () => LeagueRankingSnapshotDto.fromJson(payload),
          throwsA(isA<FormatException>()),
          reason: 'Expected repeated current player in $nearbyKey to be rejected.',
        );
      }
    });

    test('maps history entries to domain settlement result', () {
      final history = LeagueHistoryResponseDto.fromJson({
        'entries': [
          {
            'playerId': 'player-1',
            'seasonId': '2026-06-15',
            'finalRank': 1,
            'finalDivision': 2,
            'result': 'promoted',
            'finalWeeklyScore': 3000,
            'seasonEndedAt': '2026-06-21T22:59:00.000Z',
          },
        ],
      }).toDomain();

      expect(history.single.result, WeeklyLeagueSeasonResult.promoted);
      expect(history.single.seasonId.value, '2026-06-15');
    });
  });
}

Map<String, Object?> _snapshotPayload() {
  return {
    'currentPlayerRank': 2,
    'currentPlayerEntry': _rankingEntryPayload(
      rank: 2,
      playerId: 'player-1',
      username: 'Tester',
      score: 24000,
    ),
    'playersAbove': [
      _rankingEntryPayload(
        rank: 1,
        playerId: 'player-2',
        username: 'Above',
        score: 26000,
      ),
    ],
    'playersBelow': [
      _rankingEntryPayload(
        rank: 3,
        playerId: 'player-3',
        username: 'Below',
        score: 21000,
      ),
    ],
    'scoreNeededForPromotionZone': 25001,
    'scoreNeededToStayInDivision': 12001,
    'promotionZoneEndRank': 1,
    'relegationZoneStartRank': 8,
  };
}

Map<String, Object?> _rankingEntryPayload({
  required int rank,
  required String playerId,
  required String username,
  required int score,
}) {
  return {
    'rank': rank,
    'playerEntry': {
      'playerId': playerId,
      'username': username,
      'divisionNumber': 2,
      'hasReservedSlot': true,
      'entryPaid': true,
      'registeredAt': '2026-06-01T12:00:00.000Z',
      'lifetimeLeagueTournamentRuns': 12,
      'lifetimeAverageScorePerRun': 345.5,
    },
    'weeklyScore': {
      'playerId': playerId,
      'isActive': true,
      'runCount': 3,
      'activeDays': 2,
      'activityMultiplier': 1.1,
      'baseScore': score,
      'finalScore': score,
      'bonusPoints': 0,
      'countedRunScores': [score],
      'allRunScores': [score, score - 1000],
    },
  };
}
