import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/knockout/data/dto/knockout_persistence_dtos.dart';
import 'package:stoppy_app/features/knockout/data/dto/knockout_read_dtos.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_match.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_status.dart';

void main() {
  group('KnockoutCurrentEntryResponseDto', () {
    test('maps valid entry and valid no-entry response', () {
      final entry = KnockoutCurrentEntryResponseDto.fromJson({
        'playerEntry': _entryJson(),
      }).toDomain();
      final noEntry = KnockoutCurrentEntryResponseDto.fromJson({
        'playerEntry': null,
      }).toDomain();

      expect(entry?.playerId, 'player-1');
      expect(noEntry, isNull);
    });

    test('rejects malformed entry payload', () {
      expect(
        () => KnockoutCurrentEntryResponseDto.fromJson({
          'playerEntry': {'playerId': ' '},
        }),
        throwsA(isA<Object>()),
      );
    });
  });

  group('KnockoutPlayerStatusDto', () {
    test('decodes non-duel and active-duel statuses', () {
      final waiting = KnockoutPlayerStatusDto.fromJson({
        'state': 'registeredWaitingStart',
      }).toDomain();
      final active = KnockoutPlayerStatusDto.fromJson({
        'state': 'activeDuel',
        'duelSnapshot': _duelJson(),
      }).toDomain();

      expect(
        waiting.state,
        KnockoutPlayerTournamentState.registeredWaitingStart,
      );
      expect(active.state, KnockoutPlayerTournamentState.activeDuel);
      expect(active.duelSnapshot?.match.id, 'match-1');
    });

    test('rejects invalid and contradictory statuses', () {
      expect(
        () => KnockoutPlayerStatusDto.fromJson({'state': 'unknown'}),
        throwsFormatException,
      );
      expect(
        () => KnockoutPlayerStatusDto.fromJson({'state': 'activeDuel'}),
        throwsFormatException,
      );
      expect(
        () => KnockoutPlayerStatusDto.fromJson({
          'state': 'eliminated',
          'duelSnapshot': _duelJson(),
        }),
        throwsFormatException,
      );
    });
  });

  group('KnockoutActiveDuelResponseDto', () {
    test('maps valid duel and valid no-active-duel response', () {
      final duel = KnockoutActiveDuelResponseDto.fromJson({
        'duelSnapshot': _duelJson(),
      }).toDomain();
      final noDuel = KnockoutActiveDuelResponseDto.fromJson({
        'duelSnapshot': null,
      }).toDomain();

      expect(duel?.roundNumber, 2);
      expect(duel?.opponentId, 'opponent-1');
      expect(duel?.playerScore, 1200);
      expect(duel?.opponentRunCount, 2);
      expect(noDuel, isNull);
    });

    test('rejects malformed duel payloads', () {
      expect(
        () => KnockoutActiveDuelResponseDto.fromJson({
          'duelSnapshot': {..._duelJson(), 'roundNumber': 0},
        }),
        throwsA(isA<Object>()),
      );
      expect(
        () => KnockoutActiveDuelResponseDto.fromJson({
          'duelSnapshot': {..._duelJson(), 'playerScore': -1},
        }),
        throwsA(isA<Object>()),
      );
      expect(
        () => KnockoutActiveDuelResponseDto.fromJson({
          'duelSnapshot': {
            ..._duelJson(),
            'match': {..._matchJson(), 'roundNumber': 1},
          },
        }),
        throwsFormatException,
      );
    });
  });

  group('KnockoutDuelSnapshotDto consistency', () {
    test('rejects snapshot player missing from embedded match', () {
      expect(
        () => KnockoutDuelSnapshotDto.fromJson({
          ..._duelJson(),
          'playerId': 'other-player',
        }),
        throwsFormatException,
      );
    });

    test('rejects incorrect opponent identity', () {
      expect(
        () => KnockoutDuelSnapshotDto.fromJson({
          ..._duelJson(),
          'opponentId': 'other-opponent',
        }),
        throwsFormatException,
      );
    });

    test('accepts correct player-one orientation', () {
      final snapshot = KnockoutDuelSnapshotDto.fromJson(_duelJson()).toDomain();

      expect(snapshot.playerId, 'player-1');
      expect(snapshot.opponentId, 'opponent-1');
      expect(snapshot.playerScore, 1200);
      expect(snapshot.opponentScore, 900);
      expect(snapshot.playerRunCount, 3);
      expect(snapshot.opponentRunCount, 2);
    });

    test('accepts correct player-two orientation', () {
      final snapshot = KnockoutDuelSnapshotDto.fromJson({
        ..._duelJson(),
        'playerId': 'opponent-1',
        'opponentId': 'player-1',
        'playerScore': 900,
        'opponentScore': 1200,
        'playerRunCount': 2,
        'opponentRunCount': 3,
      }).toDomain();

      expect(snapshot.playerId, 'opponent-1');
      expect(snapshot.opponentId, 'player-1');
      expect(snapshot.playerScore, 900);
      expect(snapshot.opponentScore, 1200);
      expect(snapshot.playerRunCount, 2);
      expect(snapshot.opponentRunCount, 3);
    });

    test('rejects player score that contradicts embedded match', () {
      expect(
        () => KnockoutDuelSnapshotDto.fromJson({
          ..._duelJson(),
          'playerScore': 1199,
        }),
        throwsFormatException,
      );
    });

    test('rejects opponent score that contradicts embedded match', () {
      expect(
        () => KnockoutDuelSnapshotDto.fromJson({
          ..._duelJson(),
          'opponentScore': 901,
        }),
        throwsFormatException,
      );
    });

    test('rejects player run count that contradicts embedded match', () {
      expect(
        () => KnockoutDuelSnapshotDto.fromJson({
          ..._duelJson(),
          'playerRunCount': 4,
        }),
        throwsFormatException,
      );
    });

    test('rejects opponent run count that contradicts embedded match', () {
      expect(
        () => KnockoutDuelSnapshotDto.fromJson({
          ..._duelJson(),
          'opponentRunCount': 1,
        }),
        throwsFormatException,
      );
    });

    test('accepts valid player-one bye with no opponent', () {
      final snapshot = KnockoutDuelSnapshotDto.fromJson({
        ..._duelJson(),
        'opponentId': null,
        'opponentScore': 0,
        'opponentRunCount': 0,
        'hasBye': true,
        'match': _byeMatchJson(),
      }).toDomain();

      expect(snapshot.playerId, 'player-1');
      expect(snapshot.opponentId, isNull);
      expect(snapshot.playerScore, 1200);
      expect(snapshot.opponentScore, 0);
      expect(snapshot.playerRunCount, 3);
      expect(snapshot.opponentRunCount, 0);
      expect(snapshot.hasBye, isTrue);
    });
  });

  group('Knockout history and Hall of Fame responses', () {
    test('map list payloads', () {
      final history = KnockoutHistoryResponseDto.fromJson({
        'history': [_historyJson()],
      }).toDomain();
      final hallOfFame = KnockoutHallOfFameResponseDto.fromJson({
        'hallOfFame': [_hallOfFameJson()],
      }).toDomain();

      expect(history.single.tournamentId, '2026-06');
      expect(hallOfFame.single.displayName, 'Champion');
    });
  });
}

Matcher get throwsFormatException => throwsA(isA<FormatException>());

Map<String, Object?> _entryJson() {
  return {
    'playerId': 'player-1',
    'username': 'Tester',
    'tournamentId': '2026-06',
    'registeredAt': DateTime.utc(2026, 5, 22).toIso8601String(),
    'accountCreatedAt': DateTime.utc(2026).toIso8601String(),
    'entryCostGamePoints': 25,
  };
}

Map<String, Object?> _matchJson() {
  return KnockoutMatchDto.fromDomain(
    const KnockoutMatch(
      id: 'match-1',
      roundNumber: 2,
      status: KnockoutMatchStatus.active,
      playerOneId: 'player-1',
      playerTwoId: 'opponent-1',
      playerOneScore: 1200,
      playerTwoScore: 900,
      playerOneRunCount: 3,
      playerTwoRunCount: 2,
    ),
  ).toJson();
}

Map<String, Object?> _byeMatchJson() {
  return KnockoutMatchDto.fromDomain(
    const KnockoutMatch(
      id: 'match-1',
      roundNumber: 2,
      status: KnockoutMatchStatus.completed,
      playerOneId: 'player-1',
      playerTwoId: null,
      playerOneScore: 1200,
      playerTwoScore: 0,
      playerOneRunCount: 3,
      playerTwoRunCount: 0,
      winnerPlayerId: 'player-1',
    ),
  ).toJson();
}

Map<String, Object?> _duelJson() {
  return {
    'tournamentId': '2026-06',
    'roundNumber': 2,
    'roundEndsAt': DateTime.utc(2026, 6, 2, 23, 59).toIso8601String(),
    'playerId': 'player-1',
    'opponentId': 'opponent-1',
    'match': _matchJson(),
    'playerScore': 1200,
    'opponentScore': 900,
    'playerRunCount': 3,
    'opponentRunCount': 2,
  };
}

Map<String, Object?> _historyJson() {
  return {
    'tournamentId': '2026-06',
    'tournamentName': 'June Knockout',
    'tournamentMonth': DateTime.utc(2026, 6).toIso8601String(),
    'playerId': 'player-1',
    'outcome': 'eliminated',
    'finalRoundNumber': 2,
    'completedAt': DateTime.utc(2026, 6, 3).toIso8601String(),
  };
}

Map<String, Object?> _hallOfFameJson() {
  return {
    'playerId': 'champion-1',
    'displayName': 'Champion',
    'titlesWon': 1,
    'wonTournamentMonths': [DateTime.utc(2026, 6).toIso8601String()],
  };
}
