import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_contract.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/api_response.dart';
import 'package:stoppy_app/core/backend/backend_api_client.dart';
import 'package:stoppy_app/core/backend/domain_error_mapper.dart';
import 'package:stoppy_app/core/backend/idempotency_key.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/league/data/backend/backend_league_repository.dart';
import 'package:stoppy_app/features/league/domain/models/league_player_entry.dart';
import 'package:stoppy_app/features/league/domain/models/league_season_id.dart';
import 'package:stoppy_app/features/league/domain/models/weekly_league_run.dart';
import 'package:stoppy_app/features/league/domain/repositories/league_repository.dart';

void main() {
  group('BackendLeagueRepository read-only operations', () {
    test('currentEntry performs authenticated read and maps entry', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueueGetSuccess({'entry': _entryPayload('player-1')});
      final repository = BackendLeagueRepository(apiClient: apiClient);

      final entry = await repository.currentEntry('player-1');

      expect(entry, isA<LeaguePlayerEntry>());
      expect(entry?.playerId, 'player-1');
      expect(apiClient.getRequests.single.path, ApiContract.leagueCurrentEntry);
      expect(apiClient.getRequests.single.queryParameters, {
        'playerId': 'player-1',
      });
      expect(apiClient.postRequests, isEmpty);
    });

    test('currentEntry maps null entry', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueueGetSuccess({'entry': null});
      final repository = BackendLeagueRepository(apiClient: apiClient);

      expect(await repository.currentEntry('player-1'), isNull);
    });

    test('fetchDivisionRanking performs GET with division query', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueueGetSuccess({
          'entries': [_rankingEntryPayload(rank: 1, playerId: 'player-1')],
        });
      final repository = BackendLeagueRepository(apiClient: apiClient);

      final ranking = await repository.fetchDivisionRanking(2);

      expect(ranking.single.rank, 1);
      expect(apiClient.getRequests.single.path, ApiContract.leagueRanking);
      expect(apiClient.getRequests.single.queryParameters, {
        'divisionNumber': '2',
      });
    });

    test('fetchPlayerSnapshot maps server supplied snapshot', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueueGetSuccess(_snapshotPayload());
      final repository = BackendLeagueRepository(apiClient: apiClient);

      final snapshot = await repository.fetchPlayerSnapshot(
        playerId: 'player-1',
        divisionNumber: 2,
      );

      expect(snapshot.currentPlayerRank, 2);
      expect(snapshot.playersAbove.single.rank, 1);
      expect(apiClient.getRequests.single.path, ApiContract.leagueSnapshot);
      expect(apiClient.getRequests.single.queryParameters, {
        'playerId': 'player-1',
        'divisionNumber': '2',
      });
    });

    test('fetchPlayerHistory maps empty and populated collections', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueueGetSuccess({'entries': []})
        ..enqueueGetSuccess({
          'entries': [
            {
              'playerId': 'player-1',
              'seasonId': '2026-06-15',
              'finalRank': 2,
              'finalDivision': 1,
              'result': 'stayed',
              'finalWeeklyScore': 2000,
            },
          ],
        });
      final repository = BackendLeagueRepository(apiClient: apiClient);

      expect(await repository.fetchPlayerHistory('player-1'), isEmpty);
      final history = await repository.fetchPlayerHistory('player-1');

      expect(history.single.finalWeeklyScore, 2000);
      expect(apiClient.getRequests.first.path, ApiContract.leagueHistory);
      expect(apiClient.getRequests.first.queryParameters, {
        'playerId': 'player-1',
      });
    });

    test('fetchPlayerRecords and achievements map domain models', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueueGetSuccess({
          'playerId': 'player-1',
          'allTimeBestFinalScore': 30000,
          'currentWeeklyBestScore': 12000,
          'currentSeasonId': '2026-06-15',
        })
        ..enqueueGetSuccess({
          'playerId': 'player-1',
          'bestDivisionReached': 1,
          'promotions': 3,
          'relegations': 1,
        });
      final repository = BackendLeagueRepository(apiClient: apiClient);

      final records = await repository.fetchPlayerRecords('player-1');
      final achievements = await repository.fetchPlayerAchievements('player-1');

      expect(records.allTimeBestFinalScore, 30000);
      expect(achievements.bestDivisionReached, 1);
      expect(apiClient.getRequests[0].path, ApiContract.leagueRecords);
      expect(apiClient.getRequests[1].path, ApiContract.leagueAchievements);
    });

    test('fetchPlayerWeeklyRuns maps current weekly runs collection', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueueGetSuccess({
          'runs': [
            {
              'playerId': 'player-1',
              'score': 15000,
              'completedAt': '2026-06-16T12:00:00.000Z',
            },
          ],
        });
      final repository = BackendLeagueRepository(apiClient: apiClient);
      final seasonId = LeagueSeasonId(weekStartDate: DateTime(2026, 6, 15));

      final runs = await repository.fetchPlayerWeeklyRuns(
        playerId: 'player-1',
        seasonId: seasonId,
      );

      expect(runs.single.score, 15000);
      expect(apiClient.getRequests.single.path, ApiContract.leagueRuns);
      expect(apiClient.getRequests.single.queryParameters, {
        'playerId': 'player-1',
        'seasonId': '2026-06-15',
      });
    });

    test(
      'maps malformed success payloads to repository domain errors',
      () async {
        final apiClient = _FakeBackendApiClient()
          ..enqueueGetSuccess({
            'entry': _entryPayload('player-1')..remove('username'),
          });
        final repository = BackendLeagueRepository(apiClient: apiClient);

        await expectLater(
          repository.currentEntry('player-1'),
          throwsA(
            isA<RepositoryDomainException>().having(
              (exception) => exception.code,
              'code',
              ApiErrorCode.malformedPayload,
            ),
          ),
        );
      },
    );

    test('maps missing data to repository domain errors', () async {
      final apiClient = _FakeBackendApiClient()..enqueueGetSuccess({});
      final repository = BackendLeagueRepository(apiClient: apiClient);

      await expectLater(
        repository.fetchDivisionRanking(2),
        throwsA(isA<RepositoryDomainException>()),
      );
    });

    test('maps API failures safely', () async {
      const failures = [
        ApiErrorCode.unauthenticated,
        ApiErrorCode.forbidden,
        ApiErrorCode.networkUnavailable,
        ApiErrorCode.serverError,
      ];

      for (final code in failures) {
        final apiClient = _FakeBackendApiClient()
          ..enqueueGetFailure(ApiError(code: code, message: 'Backend detail.'));
        final repository = BackendLeagueRepository(apiClient: apiClient);

        await expectLater(
          repository.currentEntry('player-1'),
          throwsA(
            isA<RepositoryDomainException>().having(
              (exception) => exception.code,
              'code',
              code,
            ),
          ),
        );
      }
    });

    test('maps ApiException thrown by client safely', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueueGetException(
          const ApiException(
            ApiError(
              code: ApiErrorCode.networkUnavailable,
              message: 'Transport detail.',
            ),
          ),
        );
      final repository = BackendLeagueRepository(apiClient: apiClient);

      await expectLater(
        repository.currentEntry('player-1'),
        throwsA(
          isA<RepositoryDomainException>().having(
            (exception) => exception.message,
            'message',
            'Network unavailable. Please try again.',
          ),
        ),
      );
    });

    test('currentEntry rejects blank player ids before API calls', () async {
      for (final playerId in ['', '   ']) {
        final apiClient = _FakeBackendApiClient();
        final repository = BackendLeagueRepository(apiClient: apiClient);

        await _expectMalformedWithoutGet(
          apiClient,
          () => repository.currentEntry(playerId),
        );
      }
    });

    test(
      'fetchPlayerRecords rejects blank player ids before API calls',
      () async {
        for (final playerId in ['', '   ']) {
          final apiClient = _FakeBackendApiClient();
          final repository = BackendLeagueRepository(apiClient: apiClient);

          await _expectMalformedWithoutGet(
            apiClient,
            () => repository.fetchPlayerRecords(playerId),
          );
        }
      },
    );

    test(
      'fetchPlayerHistory rejects blank player ids before API calls',
      () async {
        for (final playerId in ['', '   ']) {
          final apiClient = _FakeBackendApiClient();
          final repository = BackendLeagueRepository(apiClient: apiClient);

          await _expectMalformedWithoutGet(
            apiClient,
            () => repository.fetchPlayerHistory(playerId),
          );
        }
      },
    );

    test(
      'fetchPlayerAchievements rejects blank player ids before API calls',
      () async {
        for (final playerId in ['', '   ']) {
          final apiClient = _FakeBackendApiClient();
          final repository = BackendLeagueRepository(apiClient: apiClient);

          await _expectMalformedWithoutGet(
            apiClient,
            () => repository.fetchPlayerAchievements(playerId),
          );
        }
      },
    );

    test(
      'fetchPlayerWeeklyRuns rejects blank player ids before API calls',
      () async {
        final seasonId = LeagueSeasonId(weekStartDate: DateTime(2026, 6, 15));

        for (final playerId in ['', '   ']) {
          final apiClient = _FakeBackendApiClient();
          final repository = BackendLeagueRepository(apiClient: apiClient);

          await _expectMalformedWithoutGet(
            apiClient,
            () => repository.fetchPlayerWeeklyRuns(
              playerId: playerId,
              seasonId: seasonId,
            ),
          );
        }
      },
    );

    test(
      'fetchPlayerSnapshot rejects blank player ids before API calls',
      () async {
        for (final playerId in ['', '   ']) {
          final apiClient = _FakeBackendApiClient();
          final repository = BackendLeagueRepository(apiClient: apiClient);

          await _expectMalformedWithoutGet(
            apiClient,
            () => repository.fetchPlayerSnapshot(
              playerId: playerId,
              divisionNumber: 1,
            ),
          );
        }
      },
    );

    test(
      'fetchDivisionRanking rejects invalid divisions before API calls',
      () async {
        for (final divisionNumber in [0, -1]) {
          final apiClient = _FakeBackendApiClient();
          final repository = BackendLeagueRepository(apiClient: apiClient);

          await _expectMalformedWithoutGet(
            apiClient,
            () => repository.fetchDivisionRanking(divisionNumber),
          );
        }
      },
    );

    test(
      'fetchPlayerSnapshot rejects invalid divisions before API calls',
      () async {
        for (final divisionNumber in [0, -1]) {
          final apiClient = _FakeBackendApiClient();
          final repository = BackendLeagueRepository(apiClient: apiClient);

          await _expectMalformedWithoutGet(
            apiClient,
            () => repository.fetchPlayerSnapshot(
              playerId: 'player-1',
              divisionNumber: divisionNumber,
            ),
          );
        }
      },
    );

    test('enterWeeklyLeague sends empty POST with idempotency key', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueuePostSuccess(_acceptedEntryResponsePayload());
      final repository = BackendLeagueRepository(apiClient: apiClient);

      await repository.enterWeeklyLeague(
        _playerProfile(gamePoints: 25),
        idempotencyKey: IdempotencyKey('league-entry:test-1'),
      );

      final request = apiClient.postRequests.single;
      expect(request.path, ApiContract.leagueEnter);
      expect(request.body, isEmpty);
      expect(request.headers, {
        ApiContract.idempotencyKeyHeader: 'league-entry:test-1',
      });
      expect(request.headers, isNot(contains(ApiContract.authorizationHeader)));
      expect(apiClient.getRequests, isEmpty);
    });

    test('enterWeeklyLeague maps accepted authoritative response', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueuePostSuccess(
          _acceptedEntryResponsePayload(
            playerId: 'server-player',
            username: 'Server Player',
            divisionNumber: 4,
            remainingGamePoints: 12,
          ),
        );
      final repository = BackendLeagueRepository(apiClient: apiClient);

      final entry = await repository.enterWeeklyLeague(
        _playerProfile(id: 'local-player', gamePoints: 25),
        idempotencyKey: IdempotencyKey('league-entry:accepted'),
      );

      expect(entry.playerId, 'server-player');
      expect(entry.username, 'Server Player');
      expect(entry.divisionNumber, 4);
      expect(entry.hasReservedSlot, isTrue);
      expect(entry.isActive, isTrue);
      expect(entry, isA<LeagueEntryResult>());
      final result = entry as LeagueEntryResult;
      expect(result.playerProfile?.gamePoints, 12);
      expect(result.remainingGamePoints, 12);
      expect(result.seasonId?.value, '2026-06-15');
    });

    test('enterWeeklyLeague maps idempotent replay as success', () async {
      final acceptedClient = _FakeBackendApiClient()
        ..enqueuePostSuccess(_acceptedEntryResponsePayload());
      final replayClient = _FakeBackendApiClient()
        ..enqueuePostSuccess(
          _acceptedEntryResponsePayload(status: 'idempotentReplay'),
        );
      final profile = _playerProfile(gamePoints: 25);

      final acceptedEntry =
          await BackendLeagueRepository(
            apiClient: acceptedClient,
          ).enterWeeklyLeague(
            profile,
            idempotencyKey: IdempotencyKey('league-entry:same-operation'),
          );
      final replayEntry = await BackendLeagueRepository(apiClient: replayClient)
          .enterWeeklyLeague(
            profile,
            idempotencyKey: IdempotencyKey('league-entry:same-operation'),
          );

      expect(replayEntry.playerId, acceptedEntry.playerId);
      expect(replayEntry.divisionNumber, acceptedEntry.divisionNumber);
      expect(replayEntry.isActive, acceptedEntry.isActive);
    });

    test('enterWeeklyLeague maps prepared rejection states', () async {
      final cases = {
        'insufficientGp': ApiErrorCode.validationFailed,
        'alreadyActive': ApiErrorCode.conflict,
        'settlementInProgress': ApiErrorCode.conflict,
        'stalePlayerState': ApiErrorCode.conflict,
        'noReservedSlot': ApiErrorCode.validationFailed,
      };

      for (final entry in cases.entries) {
        final apiClient = _FakeBackendApiClient()
          ..enqueuePostSuccess(_rejectedEntryResponsePayload(entry.key));
        final repository = BackendLeagueRepository(apiClient: apiClient);

        await expectLater(
          repository.enterWeeklyLeague(
            _playerProfile(gamePoints: 25),
            idempotencyKey: IdempotencyKey('league-entry:${entry.key}'),
          ),
          throwsA(
            isA<RepositoryDomainException>()
                .having((exception) => exception.code, 'code', entry.value)
                .having(
                  (exception) => exception.details['rejectionCode'],
                  'rejectionCode',
                  entry.key,
                ),
          ),
        );
      }
    });

    test('enterWeeklyLeague rejects malformed successful payloads', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueuePostSuccess({
          'status': 'accepted',
          'seasonId': '2026-06-15',
          'currentDivision': 2,
          'remainingGamePoints': 15,
        });
      final repository = BackendLeagueRepository(apiClient: apiClient);

      await expectLater(
        repository.enterWeeklyLeague(
          _playerProfile(gamePoints: 25),
          idempotencyKey: IdempotencyKey('league-entry:malformed'),
        ),
        throwsA(
          isA<RepositoryDomainException>().having(
            (exception) => exception.code,
            'code',
            ApiErrorCode.malformedPayload,
          ),
        ),
      );
    });

    test('enterWeeklyLeague maps API failures safely', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueuePostFailure(
          const ApiError(
            code: ApiErrorCode.networkUnavailable,
            message: 'Transport detail.',
          ),
        );
      final repository = BackendLeagueRepository(apiClient: apiClient);

      await expectLater(
        repository.enterWeeklyLeague(
          _playerProfile(gamePoints: 25),
          idempotencyKey: IdempotencyKey('league-entry:network'),
        ),
        throwsA(
          isA<RepositoryDomainException>().having(
            (exception) => exception.message,
            'message',
            'Network unavailable. Please try again.',
          ),
        ),
      );
    });

    test('enterWeeklyLeague requires explicit idempotency key', () async {
      final apiClient = _FakeBackendApiClient();
      final repository = BackendLeagueRepository(apiClient: apiClient);

      await expectLater(
        Future<Object?>.sync(
          () => repository.enterWeeklyLeague(_playerProfile(gamePoints: 25)),
        ),
        throwsA(
          isA<RepositoryDomainException>().having(
            (exception) => exception.code,
            'code',
            ApiErrorCode.malformedPayload,
          ),
        ),
      );
      expect(apiClient.getRequests, isEmpty);
      expect(apiClient.postRequests, isEmpty);
    });

    test(
      'enterWeeklyLeague does not mutate local profile on failure',
      () async {
        final profile = _playerProfile(gamePoints: 25);
        final apiClient = _FakeBackendApiClient()
          ..enqueuePostSuccess(_rejectedEntryResponsePayload('insufficientGp'));
        final repository = BackendLeagueRepository(apiClient: apiClient);

        await expectLater(
          repository.enterWeeklyLeague(
            profile,
            idempotencyKey: IdempotencyKey('league-entry:no-local-mutation'),
          ),
          throwsA(isA<RepositoryDomainException>()),
        );

        expect(profile.gamePoints, 25);
        expect(apiClient.postRequests.single.body, isEmpty);
      },
    );

    test(
      'submitLeagueRun sends claim without player identity authority',
      () async {
        final apiClient = _FakeBackendApiClient()
          ..enqueuePostSuccess(_acceptedRunSubmissionResponsePayload());
        final repository = BackendLeagueRepository(apiClient: apiClient);
        final run = _leagueRun();

        final result = await repository.submitLeagueRun(
          run,
          idempotencyKey: IdempotencyKey('league-run:test-1'),
        );

        expect(result.accepted, isTrue);
        expect(result.acceptedRun?.score, 25000);
        expect(result.playerRecords.currentWeeklyBestScore, 25000);
        expect(result.newlyPersisted, isTrue);

        final request = apiClient.postRequests.single;
        expect(request.path, ApiContract.leagueRunSubmission);
        expect(request.headers, {
          ApiContract.idempotencyKeyHeader: 'league-run:test-1',
        });
        expect(
          request.headers,
          isNot(contains(ApiContract.authorizationHeader)),
        );
        expect(request.body, {
          'runId': 'run-1',
          'seasonId': '2026-06-15',
          'runStartedAt': '2026-06-21T10:00:00.000Z',
          'runCompletedAt': '2026-06-21T10:30:00.000Z',
          'claimedFinalPrecisionPoints': 25000,
          'runMode': 'league',
          'validationClaim': {
            'runId': 'run-1',
            'runType': 'league',
            'finalPrecisionPoints': 25000,
            'levelReached': 12,
            'precisionPointTier': 8,
            'runStartedAt': '2026-06-21T10:00:00.000Z',
            'runEndedAt': '2026-06-21T10:30:00.000Z',
          },
        });
        expect(request.body, isNot(contains('playerId')));
        expect(apiClient.getRequests, isEmpty);
      },
    );

    test('submitLeagueRun maps idempotent replay as success', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueuePostSuccess(
          _acceptedRunSubmissionResponsePayload(
            status: 'idempotentReplay',
            newlyPersisted: false,
          ),
        );
      final repository = BackendLeagueRepository(apiClient: apiClient);

      final result = await repository.submitLeagueRun(
        _leagueRun(),
        idempotencyKey: IdempotencyKey('league-run:same-operation'),
      );

      expect(result.accepted, isTrue);
      expect(result.newlyPersisted, isFalse);
      expect(result.acceptedRun?.score, 25000);
    });

    test('submitLeagueRun maps prepared rejection states', () async {
      final cases = {
        'noActiveEntry': ApiErrorCode.validationFailed,
        'outsideLeague': ApiErrorCode.validationFailed,
        'seasonMismatch': ApiErrorCode.validationFailed,
        'alreadySubmitted': ApiErrorCode.conflict,
        'invalidRun': ApiErrorCode.validationFailed,
        'validationFailed': ApiErrorCode.validationFailed,
        'timestampInvalid': ApiErrorCode.validationFailed,
        'durationInvalid': ApiErrorCode.validationFailed,
        'settlementInProgress': ApiErrorCode.conflict,
        'stalePlayerState': ApiErrorCode.conflict,
      };

      for (final entry in cases.entries) {
        final apiClient = _FakeBackendApiClient()
          ..enqueuePostSuccess(
            _rejectedRunSubmissionResponsePayload(entry.key),
          );
        final repository = BackendLeagueRepository(apiClient: apiClient);

        await expectLater(
          repository.submitLeagueRun(
            _leagueRun(id: 'run-${entry.key}'),
            idempotencyKey: IdempotencyKey('league-run:${entry.key}'),
          ),
          throwsA(
            isA<RepositoryDomainException>()
                .having((exception) => exception.code, 'code', entry.value)
                .having(
                  (exception) => exception.details['rejectionCode'],
                  'rejectionCode',
                  entry.key,
                ),
          ),
        );
      }
    });

    test('submitLeagueRun rejects malformed successful payloads', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueuePostSuccess({'status': 'accepted', 'newlyPersisted': true});
      final repository = BackendLeagueRepository(apiClient: apiClient);

      await expectLater(
        repository.submitLeagueRun(
          _leagueRun(),
          idempotencyKey: IdempotencyKey('league-run:malformed'),
        ),
        throwsA(
          isA<RepositoryDomainException>().having(
            (exception) => exception.code,
            'code',
            ApiErrorCode.malformedPayload,
          ),
        ),
      );
    });

    test('submitLeagueRun validates outbound claim before API calls', () async {
      final apiClient = _FakeBackendApiClient();
      final repository = BackendLeagueRepository(apiClient: apiClient);

      await expectLater(
        Future<Object?>.sync(
          () => repository.submitLeagueRun(
            WeeklyLeagueRun(
              playerId: 'player-1',
              score: 12000,
              completedAt: DateTime.utc(2026, 6, 21, 10, 30),
            ),
            idempotencyKey: IdempotencyKey('league-run:missing-claim'),
          ),
        ),
        throwsA(
          isA<RepositoryDomainException>().having(
            (exception) => exception.code,
            'code',
            ApiErrorCode.malformedPayload,
          ),
        ),
      );
      expect(apiClient.postRequests, isEmpty);
    });

    test('submitLeagueRun requires explicit idempotency key', () async {
      final apiClient = _FakeBackendApiClient();
      final repository = BackendLeagueRepository(apiClient: apiClient);

      await expectLater(
        Future<Object?>.sync(() => repository.submitLeagueRun(_leagueRun())),
        throwsA(
          isA<RepositoryDomainException>().having(
            (exception) => exception.code,
            'code',
            ApiErrorCode.malformedPayload,
          ),
        ),
      );
      expect(apiClient.postRequests, isEmpty);
    });

    test(
      'submitLeagueRun maps ambiguous API failures without retrying',
      () async {
        final apiClient = _FakeBackendApiClient()
          ..enqueuePostFailure(
            const ApiError(
              code: ApiErrorCode.networkUnavailable,
              message: 'Transport detail.',
            ),
          );
        final repository = BackendLeagueRepository(apiClient: apiClient);

        await expectLater(
          repository.submitLeagueRun(
            _leagueRun(),
            idempotencyKey: IdempotencyKey('league-run:network'),
          ),
          throwsA(
            isA<RepositoryDomainException>().having(
              (exception) => exception.code,
              'code',
              ApiErrorCode.networkUnavailable,
            ),
          ),
        );

        expect(apiClient.postRequests, hasLength(1));
      },
    );

    test('submitLeagueRun maps timeout without retrying', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueuePostException(
          const ApiException(
            ApiError(
              code: ApiErrorCode.requestTimeout,
              message: 'Request timed out.',
            ),
          ),
        );
      final repository = BackendLeagueRepository(apiClient: apiClient);

      await expectLater(
        repository.submitLeagueRun(
          _leagueRun(),
          idempotencyKey: IdempotencyKey('league-run:timeout'),
        ),
        throwsA(
          isA<RepositoryDomainException>().having(
            (exception) => exception.code,
            'code',
            ApiErrorCode.requestTimeout,
          ),
        ),
      );

      expect(apiClient.postRequests, hasLength(1));
    });

    test('settlement stays explicitly disconnected', () async {
      final apiClient = _FakeBackendApiClient();
      final repository = BackendLeagueRepository(apiClient: apiClient);

      expect(
        () => repository.settleCurrentSeason(
          now: DateTime.utc(2026, 6, 21, 23, 59),
        ),
        throwsA(isA<ApiException>()),
      );
      expect(apiClient.getRequests, isEmpty);
      expect(apiClient.postRequests, isEmpty);
    });
  });
}

Future<void> _expectMalformedWithoutGet(
  _FakeBackendApiClient apiClient,
  Future<Object?> Function() action,
) async {
  await expectLater(
    Future<Object?>.sync(action),
    throwsA(
      isA<RepositoryDomainException>().having(
        (exception) => exception.code,
        'code',
        ApiErrorCode.malformedPayload,
      ),
    ),
  );
  expect(apiClient.getRequests, isEmpty);
}

Map<String, Object?> _snapshotPayload() {
  return {
    'currentPlayerRank': 2,
    'currentPlayerEntry': _rankingEntryPayload(rank: 2, playerId: 'player-1'),
    'playersAbove': [_rankingEntryPayload(rank: 1, playerId: 'player-2')],
    'playersBelow': [_rankingEntryPayload(rank: 3, playerId: 'player-3')],
    'scoreNeededForPromotionZone': 25001,
    'scoreNeededToStayInDivision': 12001,
    'promotionZoneEndRank': 1,
    'relegationZoneStartRank': 8,
  };
}

Map<String, Object?> _rankingEntryPayload({
  required int rank,
  required String playerId,
}) {
  return {
    'rank': rank,
    'playerEntry': _entryPayload(playerId),
    'weeklyScore': {
      'playerId': playerId,
      'isActive': true,
      'runCount': 3,
      'activeDays': 2,
      'activityMultiplier': 1.1,
      'baseScore': 24000,
      'finalScore': 26400,
      'bonusPoints': 2400,
      'countedRunScores': [24000],
      'allRunScores': [24000, 18000, 12000],
    },
  };
}

Map<String, Object?> _entryPayload(String playerId) {
  return {
    'playerId': playerId,
    'username': 'Tester $playerId',
    'divisionNumber': 2,
    'hasReservedSlot': true,
    'entryPaid': true,
    'registeredAt': '2026-06-01T12:00:00.000Z',
    'lifetimeLeagueTournamentRuns': 12,
    'lifetimeAverageScorePerRun': 345.5,
  };
}

Map<String, Object?> _acceptedEntryResponsePayload({
  String status = 'accepted',
  String playerId = 'player-1',
  String username = 'Tester player-1',
  int divisionNumber = 2,
  int remainingGamePoints = 15,
}) {
  return {
    'status': status,
    'seasonId': '2026-06-15',
    'entry': {
      ..._entryPayload(playerId),
      'username': username,
      'divisionNumber': divisionNumber,
    },
    'currentDivision': divisionNumber,
    'remainingGamePoints': remainingGamePoints,
    'playerProfile': _playerProfilePayload(
      id: playerId,
      username: username,
      gamePoints: remainingGamePoints,
      divisionNumber: divisionNumber,
    ),
  };
}

Map<String, Object?> _rejectedEntryResponsePayload(String rejectionCode) {
  return {
    'status': 'rejected',
    'seasonId': '2026-06-15',
    'rejectionCode': rejectionCode,
  };
}

WeeklyLeagueRun _leagueRun({String id = 'run-1'}) {
  return WeeklyLeagueRun(
    id: id,
    playerId: 'local-player-id-is-not-authority',
    seasonId: LeagueSeasonId(weekStartDate: DateTime(2026, 6, 15)),
    startedAt: DateTime.utc(2026, 6, 21, 10),
    score: 25000,
    completedAt: DateTime.utc(2026, 6, 21, 10, 30),
    levelReached: 12,
    precisionPointTier: 8,
  );
}

Map<String, Object?> _acceptedRunSubmissionResponsePayload({
  String status = 'accepted',
  bool newlyPersisted = true,
}) {
  return {
    'status': status,
    'newlyPersisted': newlyPersisted,
    'acceptedRun': {
      'playerId': 'server-player',
      'score': 25000,
      'completedAt': '2026-06-21T10:30:00.000Z',
    },
    'playerRecords': {
      'playerId': 'server-player',
      'allTimeBestFinalScore': 25000,
      'currentWeeklyBestScore': 25000,
      'currentSeasonId': '2026-06-15',
    },
    'validationResult': {'accepted': true, 'serverFinalPrecisionPoints': 25000},
  };
}

Map<String, Object?> _rejectedRunSubmissionResponsePayload(
  String rejectionCode,
) {
  return {
    'status': 'rejected',
    'newlyPersisted': false,
    'rejectionCode': rejectionCode,
    'validationResult': {'accepted': false, 'rejectionCode': rejectionCode},
  };
}

PlayerProfile _playerProfile({
  String id = 'player-1',
  String username = 'Tester',
  required int gamePoints,
}) {
  return PlayerProfile(
    id: id,
    username: username,
    createdAt: DateTime.utc(2026, 1, 1),
    gamePoints: gamePoints,
  );
}

Map<String, Object?> _playerProfilePayload({
  required String id,
  required String username,
  required int gamePoints,
  required int divisionNumber,
}) {
  return {
    'id': id,
    'username': username,
    'createdAt': '2026-01-01T00:00:00.000Z',
    'gamePoints': gamePoints,
    'adsRemoved': false,
    'currentLeagueDivision': divisionNumber,
    'hasWeeklyLeagueEntry': true,
    'reservedLeagueSlot': true,
  };
}

final class _FakeBackendApiClient implements BackendApiClient {
  final List<_GetRequest> getRequests = [];
  final List<_PostRequest> postRequests = [];

  final List<_QueuedApiResult> _getResults = [];
  final List<_QueuedApiResult> _postResults = [];

  void enqueueGetSuccess(Map<String, Object?> data) {
    _getResults.add(_QueuedApiResult.response(ApiResponse.success(data)));
  }

  void enqueueGetFailure(ApiError error) {
    _getResults.add(_QueuedApiResult.response(ApiResponse.failure(error)));
  }

  void enqueueGetException(ApiException exception) {
    _getResults.add(_QueuedApiResult.exception(exception));
  }

  void enqueuePostSuccess(Map<String, Object?> data) {
    _postResults.add(_QueuedApiResult.response(ApiResponse.success(data)));
  }

  void enqueuePostFailure(ApiError error) {
    _postResults.add(_QueuedApiResult.response(ApiResponse.failure(error)));
  }

  void enqueuePostException(ApiException exception) {
    _postResults.add(_QueuedApiResult.exception(exception));
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> get(
    String path, {
    Map<String, String> queryParameters = const {},
    Map<String, String> headers = const {},
  }) async {
    getRequests.add(_GetRequest(path, Map<String, String>.of(queryParameters)));

    if (_getResults.isEmpty) {
      throw StateError('No GET response or exception was enqueued for $path.');
    }

    return _getResults.removeAt(0).resolve();
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> post(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    postRequests.add(
      _PostRequest(
        path,
        Map<String, Object?>.of(body),
        Map<String, String>.of(headers),
      ),
    );

    if (_postResults.isEmpty) {
      throw StateError('No POST response or exception was enqueued for $path.');
    }

    return Future.value(_postResults.removeAt(0).resolve());
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> put(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> patch(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> delete(
    String path, {
    Map<String, String> queryParameters = const {},
    Map<String, String> headers = const {},
  }) {
    throw UnimplementedError();
  }
}

final class _GetRequest {
  const _GetRequest(this.path, this.queryParameters);

  final String path;
  final Map<String, String> queryParameters;
}

final class _PostRequest {
  const _PostRequest(this.path, this.body, this.headers);

  final String path;
  final Map<String, Object?> body;
  final Map<String, String> headers;
}

final class _QueuedApiResult {
  const _QueuedApiResult._({this.response, this.exception});

  const _QueuedApiResult.response(ApiResponse<Map<String, Object?>> response)
    : this._(response: response);

  const _QueuedApiResult.exception(ApiException exception)
    : this._(exception: exception);

  final ApiResponse<Map<String, Object?>>? response;
  final ApiException? exception;

  ApiResponse<Map<String, Object?>> resolve() {
    final queuedException = exception;
    if (queuedException != null) {
      throw queuedException;
    }

    final queuedResponse = response;
    if (queuedResponse == null) {
      throw StateError('Queued API result is empty.');
    }

    return queuedResponse;
  }
}
