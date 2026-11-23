import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_contract.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/api_response.dart';
import 'package:stoppy_app/core/backend/auth_session.dart';
import 'package:stoppy_app/core/backend/backend_api_client.dart';
import 'package:stoppy_app/core/backend/backend_api_client_config.dart';
import 'package:stoppy_app/core/backend/domain_error_mapper.dart';
import 'package:stoppy_app/core/backend/idempotency_key.dart';
import 'package:stoppy_app/core/backend/pending_backend_api_client.dart';
import 'package:stoppy_app/core/backend/secure_auth_session_store.dart';
import 'package:stoppy_app/features/auth/data/mock_auth_repository.dart';
import 'package:stoppy_app/features/auth/data/dto/player_profile_dto.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/knockout/data/backend/backend_knockout_repository.dart';
import 'package:stoppy_app/features/knockout/data/backend/knockout_registration_attempt_store.dart';
import 'package:stoppy_app/features/knockout/data/dto/knockout_persistence_dtos.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_hall_of_fame_entry.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_match.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_entry.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_records.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_status.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_run.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament_history_entry.dart';
import 'package:stoppy_app/features/knockout/presentation/screens/knockout_home_screen.dart';

const _tournamentId = 'cd30c422-9ea3-4b11-b621-93a9ffcd10b8';
const _nextTournamentId = '2935412d-8861-41a3-9e17-17ed913a9de2';

void main() {
  group('BackendKnockoutRepository preparation', () {
    test('exposes centralized Knockout API contract paths', () {
      expect(
        BackendKnockoutRepository.tournamentPath,
        ApiContract.knockoutTournament,
      );
      expect(
        BackendKnockoutRepository.currentEntryPath,
        ApiContract.knockoutEntry,
      );
      expect(BackendKnockoutRepository.statusPath, ApiContract.knockoutStatus);
      expect(
        BackendKnockoutRepository.activeDuelPath,
        ApiContract.knockoutActiveDuel,
      );
      expect(
        BackendKnockoutRepository.registerPath,
        ApiContract.knockoutRegistration,
      );
      expect(
        BackendKnockoutRepository.runSubmissionPath,
        ApiContract.knockoutRunSubmission,
      );
    });

    test(
      'discovery keeps competition and registration catalog slots separate',
      () async {
        final competition = _tournament().copyWith(
          status: KnockoutTournamentStatus.inProgress,
        );
        final registration = _nextTournament();
        final client = _FakeBackendApiClient()
          ..enqueueGetSuccess(
            _selectionPayload(registration, competition: competition),
          )
          ..enqueueGetSuccess({'tournament': _catalogPayload(competition)})
          ..enqueueGetSuccess(_selectionPayload(null));
        final repository = BackendKnockoutRepository(apiClient: client);

        final selection = await repository.discoverTournaments();
        expect(selection.competition?.id, competition.id);
        expect(selection.competition?.rounds, isEmpty);
        expect(selection.registration?.id, registration.id);
        expect(
          selection.registration?.status,
          KnockoutTournamentStatus.registrationClosed,
        );
        expect(selection.registration?.isRegistrationOpen, isFalse);
        expect(client.getRequests.first.queryParameters, isEmpty);
        expect(
          (await repository.fetchTournament(competition.id)).id,
          competition.id,
        );
        expect(client.getRequests[1].queryParameters, {
          'tournamentId': competition.id,
        });
        final empty = await repository.discoverTournaments();
        expect(empty.competition, isNull);
        expect(empty.registration, isNull);
      },
    );

    test(
      'fetchCurrentTournament maps API and malformed payload failures',
      () async {
        final failureClient = _FakeBackendApiClient()
          ..enqueueGetFailure(
            const ApiError(
              code: ApiErrorCode.serverError,
              message: 'Server unavailable.',
            ),
          );
        final malformedClient = _FakeBackendApiClient()
          ..enqueueGetSuccess({'id': _tournamentId});

        await expectLater(
          BackendKnockoutRepository(
            apiClient: failureClient,
          ).fetchCurrentTournament(),
          throwsA(
            isA<RepositoryDomainException>().having(
              (exception) => exception.code,
              'code',
              ApiErrorCode.serverError,
            ),
          ),
        );
        await expectLater(
          BackendKnockoutRepository(
            apiClient: malformedClient,
          ).fetchCurrentTournament(),
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

    test('currentEntry reads authenticated self-projection', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueueGetSuccess({
          ..._readScope(_tournamentId),
          'playerEntry': KnockoutPlayerEntryDto.fromDomain(_entry()).toJson(),
        });
      final repository = BackendKnockoutRepository(apiClient: apiClient);

      final result = await repository.currentEntry(
        tournamentId: _tournamentId,
        playerId: 'player-1',
      );

      expect(result?.playerId, 'player-1');
      expect(apiClient.getRequests.single.path, ApiContract.knockoutEntry);
      expect(apiClient.getRequests.single.queryParameters, {
        'tournamentId': _tournamentId,
      });
    });

    test('currentEntry supports valid no-entry response', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueueGetSuccess({
          ..._readScope(_tournamentId),
          'playerEntry': null,
        });
      final repository = BackendKnockoutRepository(apiClient: apiClient);

      final result = await repository.currentEntry(
        tournamentId: _tournamentId,
        playerId: 'player-1',
      );

      expect(result, isNull);
      expect(apiClient.getRequests.single.queryParameters, {
        'tournamentId': _tournamentId,
      });
    });

    test('currentEntry rejects malformed payload', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueueGetSuccess({
          ..._readScope(_tournamentId),
          'playerEntry': {'playerId': 'player-1'},
        });
      final repository = BackendKnockoutRepository(apiClient: apiClient);

      await expectLater(
        repository.currentEntry(
          tournamentId: _tournamentId,
          playerId: 'player-1',
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

    test(
      'scoped status distinguishes waiting from unavailable competition',
      () async {
        final client = _FakeBackendApiClient()
          ..enqueueGetSuccess(
            _statusPayload(_tournament(), 'registeredWaitingStart'),
          )
          ..enqueueGetSuccess(
            _statusPayload(
              _tournament().copyWith(
                status: KnockoutTournamentStatus.inProgress,
              ),
              'registeredCompetitionUnavailable',
            ),
          );
        final repository = BackendKnockoutRepository(apiClient: client);
        Future<KnockoutPlayerStatus> read() => repository.fetchPlayerStatus(
          tournamentId: _tournamentId,
          playerId: 'player-1',
        );

        expect(
          (await read()).state,
          KnockoutPlayerTournamentState.registeredWaitingStart,
        );
        final unavailable = await read();
        expect(
          unavailable.state,
          KnockoutPlayerTournamentState.registeredCompetitionUnavailable,
        );
        expect(unavailable.canPlayTournamentRun, isFalse);
        expect(
          client.getRequests.map((request) => request.queryParameters),
          everyElement({'tournamentId': _tournamentId}),
        );
      },
    );

    test(
      'entry and status refuse responses scoped to another tournament or player',
      () async {
        final client = _FakeBackendApiClient()
          ..enqueueGetSuccess({
            ..._readScope(_nextTournamentId),
            'playerEntry': null,
          })
          ..enqueueGetSuccess({
            ..._statusPayload(_tournament(), 'notRegistered'),
            'playerId': 'other',
          });
        final repository = BackendKnockoutRepository(apiClient: client);
        final malformed = throwsA(
          isA<RepositoryDomainException>().having(
            (error) => error.code,
            'code',
            ApiErrorCode.malformedPayload,
          ),
        );
        await expectLater(
          repository.currentEntry(
            tournamentId: _tournamentId,
            playerId: 'player-1',
          ),
          malformed,
        );
        await expectLater(
          repository.fetchPlayerStatus(
            tournamentId: _tournamentId,
            playerId: 'player-1',
          ),
          malformed,
        );
      },
    );

    test(
      'fetchPlayerStatus rejects invalid or contradictory payload',
      () async {
        final invalidClient = _FakeBackendApiClient()
          ..enqueueGetSuccess(_statusPayload(_tournament(), 'unknown'));
        final contradictoryClient = _FakeBackendApiClient()
          ..enqueueGetSuccess(_statusPayload(_tournament(), 'activeDuel'));

        await expectLater(
          BackendKnockoutRepository(apiClient: invalidClient).fetchPlayerStatus(
            tournamentId: _tournamentId,
            playerId: 'player-1',
          ),
          throwsA(
            isA<RepositoryDomainException>().having(
              (exception) => exception.code,
              'code',
              ApiErrorCode.malformedPayload,
            ),
          ),
        );
        await expectLater(
          BackendKnockoutRepository(
            apiClient: contradictoryClient,
          ).fetchPlayerStatus(
            tournamentId: _tournamentId,
            playerId: 'player-1',
          ),
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

    test('unsupported projections preserve their unavailable error', () async {
      const failure = ApiError(
        code: ApiErrorCode.notImplemented,
        message: 'Unavailable',
        details: {'reason': 'competitiveProjectionUnavailable'},
      );
      final client = _FakeBackendApiClient()
        ..enqueueGetFailure(failure)
        ..enqueueGetFailure(failure)
        ..enqueueGetFailure(failure)
        ..enqueueGetFailure(failure);
      final repository = BackendKnockoutRepository(apiClient: client);
      final matcher = throwsA(
        isA<RepositoryDomainException>()
            .having((error) => error.code, 'code', ApiErrorCode.notImplemented)
            .having(
              (error) => error.details['reason'],
              'reason',
              'competitiveProjectionUnavailable',
            ),
      );
      await expectLater(
        repository.fetchActiveDuel(
          tournamentId: _tournamentId,
          playerId: 'player-1',
        ),
        matcher,
      );
      await expectLater(repository.fetchPlayerRecords('player-1'), matcher);
      await expectLater(repository.fetchPlayerHistory('player-1'), matcher);
      await expectLater(repository.fetchHallOfFame(), matcher);
      expect(client.getRequests.first.queryParameters, {
        'tournamentId': _tournamentId,
      });
    });

    test('fetchActiveDuel rejects malformed duel payload', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueueGetSuccess({
          'duelSnapshot': {..._duelJson(), 'playerRunCount': -1},
        });
      final repository = BackendKnockoutRepository(apiClient: apiClient);

      await expectLater(
        repository.fetchActiveDuel(
          tournamentId: _tournamentId,
          playerId: 'player-1',
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

    test('records history and Hall of Fame reads map backend data', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueueGetSuccess(
          KnockoutPlayerRecordsDto.fromDomain(_records()).toJson(),
        )
        ..enqueueGetSuccess({
          'history': [
            KnockoutTournamentHistoryEntryDto.fromDomain(_history()).toJson(),
          ],
        })
        ..enqueueGetSuccess({
          'hallOfFame': [
            KnockoutHallOfFameEntryDto.fromDomain(_hallOfFame()).toJson(),
          ],
        });
      final repository = BackendKnockoutRepository(apiClient: apiClient);

      final records = await repository.fetchPlayerRecords('client-player-id');
      final history = await repository.fetchPlayerHistory('client-player-id');
      final hallOfFame = await repository.fetchHallOfFame();

      expect(records.playerId, 'player-1');
      expect(history.single.tournamentId, _tournamentId);
      expect(hallOfFame.single.displayName, 'Champion');
      expect(apiClient.getRequests.map((request) => request.path), [
        ApiContract.knockoutRecords,
        ApiContract.knockoutHistory,
        ApiContract.knockoutHallOfFame,
      ]);
      expect(
        apiClient.getRequests.every(
          (request) => request.queryParameters.isEmpty,
        ),
        isTrue,
      );
    });

    test(
      'registerPlayer sends the explicit tournament UUID with caller-owned key',
      () async {
        final tournament = _tournamentWithEntry();
        final apiClient = _FakeBackendApiClient()
          ..enqueuePostSuccess(
            _registrationResponsePayload(
              status: 'accepted',
              newlyPersisted: true,
              tournament: tournament,
              historicalRemainingGamePoints: 75,
            ),
          );
        final repository = _registrationRepository(apiClient);

        final result = await repository.registerPlayer(
          tournament: _tournament(),
          playerProfile: _playerProfile(gamePoints: 100),
          idempotencyKey: IdempotencyKey('knockout-register-attempt-1'),
        );

        expect(result.isSuccess, isTrue);
        expect(result.playerEntry?.playerId, 'player-1');
        expect(result.historicalRemainingGamePoints, 75);
        expect(result.playerProfile?.gamePoints, 75);
        expect(
          apiClient.postRequests.single.path,
          ApiContract.knockoutRegistration,
        );
        expect(apiClient.postRequests.single.body, {
          'tournamentId': _tournamentId,
        });
        expect(await repository.hasPendingRegistration('player-1'), isFalse);
        expect(apiClient.postRequests.single.headers, {
          ApiContract.idempotencyKeyHeader: 'knockout-register-attempt-1',
        });
        expect(
          apiClient.postRequests.single.headers.keys,
          isNot(contains(ApiContract.authorizationHeader)),
        );
      },
    );

    test('registerPlayer maps idempotent replay as success', () async {
      final tournament = _tournamentWithEntry();
      final apiClient = _FakeBackendApiClient()
        ..enqueuePostSuccess(
          _registrationResponsePayload(
            status: 'idempotentReplay',
            newlyPersisted: false,
            tournament: tournament,
            historicalRemainingGamePoints: 75,
            profileGamePoints: 84,
          ),
        );
      final repository = _registrationRepository(apiClient);

      final result = await repository.registerPlayer(
        tournament: _tournament(),
        playerProfile: _playerProfile(gamePoints: 100),
        idempotencyKey: IdempotencyKey('knockout-register-attempt-1'),
      );

      expect(result.isSuccess, isTrue);
      expect(result.playerEntry?.tournamentId, tournament.id);
      expect(result.historicalRemainingGamePoints, 75);
      expect(result.playerProfile?.gamePoints, 84);
    });

    test('registerPlayer maps definitive rejection to domain result', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueuePostSuccess({
          'status': 'rejected',
          'newlyPersisted': false,
          'replayed': true,
          'tournamentId': _tournamentId,
          'playerId': 'player-1',
          'rejectionCode': 'insufficientGp',
        });
      final repository = _registrationRepository(apiClient);

      final result = await repository.registerPlayer(
        tournament: _tournament(),
        playerProfile: _playerProfile(gamePoints: 24),
        idempotencyKey: IdempotencyKey('knockout-register-attempt-1'),
      );

      expect(result.isFailure, isTrue);
      expect(result.playerEntry, isNull);
      expect(result.message, 'You need 25 GP to register.');
      expect(apiClient.postRequests.length, 1);
    });

    test('registerPlayer requires explicit idempotency key before HTTP', () {
      final apiClient = _FakeBackendApiClient();
      final repository = _registrationRepository(apiClient);

      expect(
        () => repository.registerPlayer(
          tournament: _tournament(),
          playerProfile: _playerProfile(),
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

    test('registerPlayer maps API failures and does not retry', () async {
      final apiClient = _FakeBackendApiClient()
        ..enqueuePostFailure(
          const ApiError(
            code: ApiErrorCode.networkUnavailable,
            message: 'Network down.',
          ),
        );
      final repository = _registrationRepository(apiClient);

      await expectLater(
        repository.registerPlayer(
          tournament: _tournament(),
          playerProfile: _playerProfile(),
          idempotencyKey: IdempotencyKey('knockout-register-attempt-1'),
        ),
        throwsA(
          isA<RepositoryDomainException>().having(
            (exception) => exception.code,
            'code',
            ApiErrorCode.networkUnavailable,
          ),
        ),
      );
      expect(apiClient.postRequests.length, 1);
    });

    test('registerPlayer rejects malformed success payloads', () async {
      final tournament = _tournamentWithEntry();
      final apiClient = _FakeBackendApiClient()
        ..enqueuePostSuccess(
          _registrationResponsePayload(
            status: 'accepted',
            newlyPersisted: true,
            tournament: tournament,
            historicalRemainingGamePoints: 75,
          )..remove('playerProfile'),
        );
      final repository = _registrationRepository(apiClient);

      await expectLater(
        repository.registerPlayer(
          tournament: _tournament(),
          playerProfile: _playerProfile(),
          idempotencyKey: IdempotencyKey('knockout-register-attempt-1'),
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

    test(
      'retry after repository recreation uses stored target and key',
      () async {
        final storage = _MemorySecureStore();
        final client = _FakeBackendApiClient()
          ..enqueuePostFailure(
            const ApiError(
              code: ApiErrorCode.requestTimeout,
              message: 'Timed out.',
            ),
          )
          ..enqueuePostFailure(
            const ApiError(
              code: ApiErrorCode.serverError,
              message: 'Outcome unknown.',
              details: {'reason': 'commitOutcomeUnknown'},
            ),
          )
          ..enqueuePostFailure(
            const ApiError(
              code: ApiErrorCode.conflict,
              message: 'Idempotency key conflict.',
              details: {'reason': 'idempotencyConflict'},
            ),
          )
          ..enqueuePostFailure(
            const ApiError(
              code: ApiErrorCode.serverError,
              message: 'Registration could not be verified.',
              details: {'reason': 'infrastructureFailure'},
            ),
          )
          ..enqueuePostSuccess(
            _closedRegistration(
              _tournament().copyWith(
                status: KnockoutTournamentStatus.registrationClosed,
              ),
            ),
          );
        final player = _playerProfile();
        final originalKey = IdempotencyKey('original-registration');
        await expectLater(
          _registrationRepository(client, storage: storage).registerPlayer(
            tournament: _tournament(),
            playerProfile: player,
            idempotencyKey: originalKey,
          ),
          throwsA(isA<RepositoryDomainException>()),
        );

        final restarted = _registrationRepository(client, storage: storage);
        expect(await restarted.hasPendingRegistration(player.id), isTrue);
        expect(
          await restarted.hasPendingRegistration('another-player'),
          isFalse,
        );
        expect(
          await _registrationRepository(
            client,
            storage: storage,
            backendScope: 'https://other.example',
          ).hasPendingRegistration(player.id),
          isFalse,
        );
        await expectLater(
          restarted.registerPlayer(
            tournament: _nextTournament(),
            playerProfile: player,
            idempotencyKey: originalKey,
          ),
          throwsA(
            isA<RepositoryDomainException>().having(
              (e) => e.code,
              'code',
              ApiErrorCode.conflict,
            ),
          ),
        );
        expect(client.postRequests, hasLength(1));

        for (final code in [
          ApiErrorCode.serverError,
          ApiErrorCode.conflict,
          ApiErrorCode.serverError,
        ]) {
          await expectLater(
            restarted.retryRegistration(playerProfile: player),
            throwsA(
              isA<RepositoryDomainException>().having(
                (error) => error.code,
                'code',
                code,
              ),
            ),
          );
          expect(await restarted.hasPendingRegistration(player.id), isTrue);
        }
        final outcome = await restarted.retryRegistration(
          playerProfile: player,
        );
        expect(outcome.isFailure, isTrue);
        expect(outcome.tournamentId, _tournamentId);
        expect(await restarted.hasPendingRegistration(player.id), isFalse);
        expect(client.postRequests, hasLength(5));
        for (final request in client.postRequests) {
          expect(request.body, {'tournamentId': _tournamentId});
          expect(request.headers, originalKey.toHeader());
        }
      },
    );

    test(
      'a response for a different target or player cannot clear the pending attempt',
      () async {
        final client = _FakeBackendApiClient()
          ..enqueuePostSuccess(_closedRegistration(_nextTournament()))
          ..enqueuePostSuccess({
            ..._closedRegistration(_tournament()),
            'playerId': 'another-player',
          });
        final repository = _registrationRepository(client);
        final player = _playerProfile();
        await expectLater(
          repository.registerPlayer(
            tournament: _tournament(),
            playerProfile: player,
            idempotencyKey: IdempotencyKey('wrong-target'),
          ),
          throwsA(
            isA<RepositoryDomainException>().having(
              (e) => e.code,
              'code',
              ApiErrorCode.malformedPayload,
            ),
          ),
        );
        expect(await repository.hasPendingRegistration(player.id), isTrue);
        await expectLater(
          repository.retryRegistration(playerProfile: player),
          throwsA(
            isA<RepositoryDomainException>().having(
              (e) => e.code,
              'code',
              ApiErrorCode.malformedPayload,
            ),
          ),
        );
        expect(await repository.hasPendingRegistration(player.id), isTrue);
      },
    );

    test(
      'invalid targets and failed recovery storage never send a POST',
      () async {
        final client = _FakeBackendApiClient();
        final storage = _MemorySecureStore()..rejectWrites = true;
        final repository = _registrationRepository(client, storage: storage);
        final player = _playerProfile();
        final key = IdempotencyKey('no-post');
        expect(
          () => repository.registerPlayer(
            tournament: _tournament().copyWith(id: '2026-06'),
            playerProfile: player,
            idempotencyKey: key,
          ),
          throwsA(
            isA<RepositoryDomainException>().having(
              (e) => e.code,
              'code',
              ApiErrorCode.malformedPayload,
            ),
          ),
        );
        await expectLater(
          repository.registerPlayer(
            tournament: _tournament(),
            playerProfile: player,
            idempotencyKey: key,
          ),
          throwsA(
            isA<RepositoryDomainException>().having(
              (e) => e.code,
              'code',
              ApiErrorCode.localStorageUnavailable,
            ),
          ),
        );
        expect(client.postRequests, isEmpty);
      },
    );

    test(
      'registration refuses a transport that cannot bind the bearer to the pending account',
      () async {
        final repository = BackendKnockoutRepository(
          apiClient: PendingBackendApiClient(
            config: BackendConfig(baseUrl: 'https://stoppy.example'),
            authSessionStore: InMemoryAuthSessionStore(),
          ),
          registrationAttemptStore: KnockoutRegistrationAttemptStore(
            storage: _MemorySecureStore(),
            backendScope: 'https://stoppy.example',
          ),
        );
        final player = _playerProfile();
        await expectLater(
          repository.registerPlayer(
            tournament: _tournament(),
            playerProfile: player,
            idempotencyKey: IdempotencyKey('unsafe-transport'),
          ),
          throwsA(
            isA<RepositoryDomainException>().having(
              (e) => e.code,
              'code',
              ApiErrorCode.invalidConfiguration,
            ),
          ),
        );
        expect(await repository.hasPendingRegistration(player.id), isFalse);
      },
    );

    testWidgets(
      'backend screen loads scoped registration across refresh and skips unavailable projections',
      (tester) async {
        final competition = _tournament().copyWith(
          status: KnockoutTournamentStatus.inProgress,
        );
        final upcoming = _nextTournament().copyWith(
          status: KnockoutTournamentStatus.registrationOpen,
        );
        final client = _FakeBackendApiClient()
          ..enqueueGetSuccess(_selectionPayload(null))
          ..enqueueGetSuccess(
            _selectionPayload(upcoming, competition: competition),
          )
          ..enqueueGetSuccess({
            ..._readScope(upcoming.id),
            'playerEntry': {
              ...KnockoutPlayerEntryDto.fromDomain(_entry()).toJson(),
              'tournamentId': upcoming.id,
            },
          })
          ..enqueueGetSuccess(
            _statusPayload(
              upcoming.copyWith(
                status: KnockoutTournamentStatus.registrationClosed,
              ),
              'registeredWaitingStart',
            ),
          )
          ..enqueueGetSuccess({
            ..._readScope(competition.id),
            'playerEntry': null,
          })
          ..enqueueGetSuccess(_statusPayload(competition, 'notRegistered'))
          ..enqueueGetSuccess(_selectionPayload(upcoming))
          ..enqueueGetSuccess({
            ..._readScope(competition.id),
            'playerEntry': null,
          })
          ..enqueueGetSuccess(_statusPayload(upcoming, 'notRegistered'));

        await tester.pumpWidget(
          MaterialApp(
            home: KnockoutHomeScreen(
              playerProfile: _playerProfile(),
              authRepository: MockAuthRepository(),
              knockoutRepository: _registrationRepository(client),
              onPlayerProfileUpdated: (_) => fail('Reads must not update GP.'),
              onPlayTournamentRun: () => fail('No authoritative duel exists.'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('No relevant Knockout tournament is available.'),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('Refresh Knockout'));
        await tester.pumpAndSettle();
        expect(find.text('July Knockout'), findsOneWidget);
        expect(find.text('Status: Registration closed'), findsOneWidget);
        expect(
          find.text('Registered - waiting for tournament start'),
          findsOneWidget,
        );
        expect(find.text('Play tournament run'), findsNothing);
        expect(find.text('No completed Knockout records yet.'), findsNothing);
        final unavailable = find.text(
          'Duels, records, history, Hall of Fame and achievements are unavailable.',
        );
        await tester.ensureVisible(unavailable);
        expect(unavailable, findsOneWidget);

        final competitionChip = find.widgetWithText(ChoiceChip, 'Competition');
        await tester.ensureVisible(competitionChip);
        await tester.tap(competitionChip);
        await tester.pumpAndSettle();
        expect(find.text('June Knockout'), findsOneWidget);
        expect(find.text('Not registered'), findsOneWidget);
        expect(client.getRequests.map((request) => request.path), [
          ApiContract.knockoutTournament,
          ApiContract.knockoutTournament,
          ApiContract.knockoutEntry,
          ApiContract.knockoutStatus,
          ApiContract.knockoutEntry,
          ApiContract.knockoutStatus,
        ]);
        expect(client.getRequests[2].queryParameters, {
          'tournamentId': upcoming.id,
        });
        expect(client.getRequests[5].queryParameters, {
          'tournamentId': competition.id,
        });
        await tester.tap(find.byTooltip('Refresh Knockout'));
        await tester.pumpAndSettle();
        expect(find.text('July Knockout'), findsOneWidget);
        expect(find.text('Registration status unavailable.'), findsOneWidget);
        expect(find.text('Not registered'), findsNothing);
        expect(client.postRequests, isEmpty);
      },
    );

    testWidgets(
      'returning to Knockout exposes original retry during month rollover',
      (tester) async {
        final player = _playerProfile();
        final storage = _MemorySecureStore();
        final firstClient = _FakeBackendApiClient()
          ..enqueueKnockoutScreen(_tournament())
          ..enqueuePostFailure(
            const ApiError(
              code: ApiErrorCode.requestTimeout,
              message: 'Timed out.',
            ),
          );
        final nextClient = _FakeBackendApiClient()
          ..enqueueKnockoutScreen(_nextTournament())
          ..enqueuePostSuccess(
            _closedRegistration(
              _tournament().copyWith(
                status: KnockoutTournamentStatus.registrationClosed,
              ),
            ),
          );
        final firstRepository = _registrationRepository(
          firstClient,
          storage: storage,
        );
        final nextRepository = _registrationRepository(
          nextClient,
          storage: storage,
        );
        await expectLater(
          firstRepository.registerPlayer(
            tournament: _tournament(),
            playerProfile: player,
            idempotencyKey: IdempotencyKey('pending-before-rollover'),
          ),
          throwsA(isA<RepositoryDomainException>()),
        );
        var opens = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) {
                          return KnockoutHomeScreen(
                            playerProfile: player,
                            authRepository: MockAuthRepository(),
                            knockoutRepository: opens++ == 0
                                ? firstRepository
                                : nextRepository,
                            onPlayerProfileUpdated: (_) => fail(
                              'A rejection must not update the profile.',
                            ),
                          );
                        },
                      ),
                    ),
                    child: const Text('Open Knockout'),
                  ),
                );
              },
            ),
          ),
        );
        await tester.tap(find.text('Open Knockout'));
        await tester.pumpAndSettle();
        expect(find.text('Register for Knockout'), findsNothing);
        expect(find.text('Paid registration is unavailable.'), findsOneWidget);
        const retryLabel = 'Retry pending Knockout registration';
        expect(find.text(retryLabel), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Knockout'));
        await tester.pumpAndSettle();
        expect(find.text('July Knockout'), findsOneWidget);
        await tester.tap(find.text(retryLabel));
        await tester.pumpAndSettle();
        expect(
          nextClient.postRequests.single.body,
          firstClient.postRequests.single.body,
        );
        expect(
          nextClient.postRequests.single.headers,
          firstClient.postRequests.single.headers,
        );
        expect(find.text('July Knockout'), findsOneWidget);
        expect(find.text(retryLabel), findsNothing);
      },
    );

    for (final status in ['accepted', 'idempotentReplay']) {
      test(
        'run submission resolves $status with claim and explicit key',
        () async {
          final apiClient = _FakeBackendApiClient()
            ..enqueuePostSuccess({
              'status': status,
              'newlyPersisted': status == 'accepted',
              'acceptedRun': {
                'id': 'run-1',
                'playerId': 'server-player',
                'matchId': 'match-1',
                'roundNumber': 1,
                'score': 40000,
                'completedAt': DateTime.utc(2026, 6, 2, 10).toIso8601String(),
              },
            });
          final run = _runClaim();
          final accepted = await BackendKnockoutRepository(
            apiClient: apiClient,
          ).submitKnockoutRun(run, idempotencyKey: IdempotencyKey('run-key'));
          expect(accepted, isTrue);
          final request = apiClient.postRequests.single;
          expect(request.path, ApiContract.knockoutRunSubmission);
          expect(request.headers, {
            ApiContract.idempotencyKeyHeader: 'run-key',
          });
          expect(request.body, {
            'runId': run.id,
            'tournamentId': _tournamentId,
            'roundNumber': 1,
            'matchId': 'match-1',
            'runStartedAt': run.startedAt!.toIso8601String(),
            'runCompletedAt': run.completedAt.toIso8601String(),
            'claimedFinalPrecisionPoints': 42000,
            'runMode': 'knockout',
          });
          expect(apiClient.getRequests, isEmpty);
        },
      );
    }

    for (final status in ['accepted', 'idempotentReplay']) {
      for (final field in ['id', 'matchId', 'roundNumber']) {
        test('$status rejects mismatched accepted run $field', () async {
          final apiClient = _FakeBackendApiClient()
            ..enqueuePostSuccess({
              'status': status,
              'newlyPersisted': status == 'accepted',
              'acceptedRun': {
                'id': 'run-1',
                'matchId': 'match-1',
                'roundNumber': 1,
                'playerId': 'authenticated-player',
                'score': 40000,
                'completedAt': DateTime.utc(2026, 6, 2, 10).toIso8601String(),
                field: field == 'roundNumber' ? 2 : 'different-id',
              },
            });
          await expectLater(
            BackendKnockoutRepository(apiClient: apiClient).submitKnockoutRun(
              _runClaim(),
              idempotencyKey: IdempotencyKey('key'),
            ),
            throwsA(
              isA<RepositoryDomainException>().having(
                (e) => e.code,
                'code',
                ApiErrorCode.malformedPayload,
              ),
            ),
          );
          expect(apiClient.postRequests, hasLength(1));
        });
      }
    }

    for (final rejection in [
      'noActiveDuel',
      'roundMismatch',
      'validationFailed',
      'settlementInProgress',
    ]) {
      test(
        'run rejection $rejection preserves machine-readable reason',
        () async {
          final apiClient = _FakeBackendApiClient()
            ..enqueuePostSuccess({
              'status': 'rejected',
              'newlyPersisted': false,
              'rejectionCode': rejection,
            });
          await expectLater(
            BackendKnockoutRepository(apiClient: apiClient).submitKnockoutRun(
              _runClaim(),
              idempotencyKey: IdempotencyKey('key'),
            ),
            throwsA(
              isA<RepositoryDomainException>()
                  .having((e) => e.code, 'code', ApiErrorCode.validationFailed)
                  .having(
                    (e) => e.details['rejectionCode'],
                    'reason',
                    rejection,
                  ),
            ),
          );
          expect(apiClient.postRequests, hasLength(1));
        },
      );
    }

    for (final payload in <Map<String, Object?>>[
      {'status': 'accepted', 'newlyPersisted': true},
      {'status': 'rejected', 'newlyPersisted': false},
    ]) {
      test(
        'malformed run response $payload maps to malformedPayload',
        () async {
          final apiClient = _FakeBackendApiClient()
            ..enqueuePostSuccess(payload);
          await expectLater(
            BackendKnockoutRepository(apiClient: apiClient).submitKnockoutRun(
              _runClaim(),
              idempotencyKey: IdempotencyKey('key'),
            ),
            throwsA(
              isA<RepositoryDomainException>().having(
                (e) => e.code,
                'code',
                ApiErrorCode.malformedPayload,
              ),
            ),
          );
        },
      );
    }

    for (final code in [
      ApiErrorCode.networkUnavailable,
      ApiErrorCode.requestTimeout,
      ApiErrorCode.serverError,
      ApiErrorCode.unauthenticated,
    ]) {
      test('run submission maps $code without automatic retry', () async {
        final apiClient = _FakeBackendApiClient()
          ..enqueuePostFailure(ApiError(code: code, message: 'unavailable'));
        await expectLater(
          BackendKnockoutRepository(apiClient: apiClient).submitKnockoutRun(
            _runClaim(),
            idempotencyKey: IdempotencyKey('key'),
          ),
          throwsA(
            isA<RepositoryDomainException>().having(
              (e) => e.code,
              'code',
              code,
            ),
          ),
        );
        expect(apiClient.postRequests, hasLength(1));
        expect(apiClient.getRequests, isEmpty);
      });
    }

    test('run submission rejects invalid claim before transport', () {
      final client = _FakeBackendApiClient();
      final repository = BackendKnockoutRepository(apiClient: client);
      for (final run in [
        _runClaim().copyWith(tournamentId: ' '),
        _runClaim().copyWith(startedAt: DateTime.utc(2026, 6, 1)),
        _runClaim().copyWith(startedAt: DateTime.utc(2026, 6, 3)),
      ]) {
        expect(
          () => repository.submitKnockoutRun(
            run,
            idempotencyKey: IdempotencyKey('key'),
          ),
          throwsA(
            isA<RepositoryDomainException>().having(
              (e) => e.code,
              'code',
              ApiErrorCode.malformedPayload,
            ),
          ),
        );
      }
      expect(client.postRequests, isEmpty);
    });

    test('run submission requires explicit key before transport', () {
      final apiClient = _FakeBackendApiClient();
      final repository = BackendKnockoutRepository(apiClient: apiClient);
      expect(
        () => repository.submitKnockoutRun(_runClaim()),
        throwsA(
          isA<RepositoryDomainException>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.malformedPayload,
          ),
        ),
      );
      expect(apiClient.postRequests, isEmpty);
      expect(apiClient.getRequests, isEmpty);
    });

    test('server-only lifecycle mutations remain disconnected', () {
      final apiClient = _FakeBackendApiClient();
      final repository = BackendKnockoutRepository(apiClient: apiClient);

      expect(
        () => repository.closeRegistration(tournamentId: _tournamentId),
        throwsNotImplementedFor('closeRegistration'),
      );
      expect(
        () => repository.startTournament(tournamentId: _tournamentId),
        throwsNotImplementedFor('startTournament'),
      );
      expect(
        () => repository.settleCurrentRound(tournamentId: _tournamentId),
        throwsNotImplementedFor('settleCurrentRound'),
      );
      expect(apiClient.postRequests, isEmpty);
      expect(apiClient.getRequests, isEmpty);
    });
  });
}

Matcher throwsNotImplementedFor(String methodName) {
  return throwsA(
    isA<ApiException>()
        .having(
          (exception) => exception.error.code,
          'code',
          ApiErrorCode.notImplemented,
        )
        .having(
          (exception) => exception.error.details['method'],
          'method',
          methodName,
        ),
  );
}

KnockoutRun _runClaim() => KnockoutRun(
  id: 'run-1',
  playerId: 'untrusted-player',
  matchId: 'match-1',
  roundNumber: 1,
  score: 42000,
  tournamentId: _tournamentId,
  startedAt: DateTime.utc(2026, 6, 2, 9, 55),
  completedAt: DateTime.utc(2026, 6, 2, 10),
);

KnockoutTournament _tournament({List<KnockoutPlayerEntry> entries = const []}) {
  return KnockoutTournament(
    id: _tournamentId,
    name: 'June Knockout',
    entryCostGamePoints: 25,
    tournamentMonth: DateTime.utc(2026, 6),
    registrationOpensAt: DateTime.utc(2026, 5),
    registrationClosesAt: DateTime.utc(2026, 5, 31, 23, 59),
    startsAt: DateTime.utc(2026, 6),
    entries: entries,
  );
}

KnockoutTournament _tournamentWithEntry() {
  return _tournament(entries: [_entry()]);
}

KnockoutTournament _nextTournament() => _tournament().copyWith(
  id: _nextTournamentId,
  name: 'July Knockout',
  tournamentMonth: DateTime.utc(2026, 7),
  registrationOpensAt: DateTime.utc(2026, 6),
  registrationClosesAt: DateTime.utc(2026, 6, 30, 23, 59),
  startsAt: DateTime.utc(2026, 7),
  status: KnockoutTournamentStatus.registrationClosed,
);

Map<String, Object?> _catalogPayload(KnockoutTournament tournament) => {
  ...KnockoutTournamentDto.fromDomain(tournament).toRegistrationCatalogJson(),
  'registrationWindowOpen': tournament.isRegistrationOpen,
};

Map<String, Object?> _selectionPayload(
  KnockoutTournament? registration, {
  KnockoutTournament? competition,
}) => {
  'registration': registration == null ? null : _catalogPayload(registration),
  'competition': competition == null ? null : _catalogPayload(competition),
};

Map<String, Object?> _readScope(String tournamentId) => {
  'tournamentId': tournamentId,
  'playerId': 'player-1',
};

Map<String, Object?> _statusPayload(
  KnockoutTournament tournament,
  String state,
) => {
  ..._readScope(tournament.id),
  'tournamentStatus': tournament.status.name,
  'registrationWindowOpen': tournament.isRegistrationOpen,
  'state': state,
};

Map<String, Object?> _closedRegistration(KnockoutTournament tournament) => {
  'status': 'rejected',
  'newlyPersisted': false,
  'replayed': false,
  'tournamentId': tournament.id,
  'playerId': 'player-1',
  'rejectionCode': 'registrationClosed',
};

BackendKnockoutRepository _registrationRepository(
  _FakeBackendApiClient client, {
  _MemorySecureStore? storage,
  String backendScope = 'https://stoppy.example',
}) => BackendKnockoutRepository(
  apiClient: client,
  registrationAttemptStore: KnockoutRegistrationAttemptStore(
    storage: storage ?? _MemorySecureStore(),
    backendScope: backendScope,
  ),
);

final class _MemorySecureStore implements SecureKeyValueStore {
  final _values = <String, String>{};
  bool rejectWrites = false;

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    if (rejectWrites) throw StateError('Storage write failed');
    _values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }
}

KnockoutPlayerEntry _entry() {
  return KnockoutPlayerEntry(
    playerId: 'player-1',
    username: 'Tester',
    tournamentId: _tournamentId,
    registeredAt: DateTime.utc(2026, 5, 22, 12),
    accountCreatedAt: DateTime.utc(2026),
    entryCostGamePoints: 25,
  );
}

KnockoutMatch _match() {
  return const KnockoutMatch(
    id: 'match-1',
    roundNumber: 2,
    status: KnockoutMatchStatus.active,
    playerOneId: 'player-1',
    playerTwoId: 'opponent-1',
    playerOneScore: 1200,
    playerTwoScore: 900,
    playerOneRunCount: 3,
    playerTwoRunCount: 2,
  );
}

Map<String, Object?> _duelJson() {
  return {
    'tournamentId': _tournamentId,
    'roundNumber': 2,
    'roundEndsAt': DateTime.utc(2026, 6, 2, 23, 59).toIso8601String(),
    'playerId': 'player-1',
    'opponentId': 'opponent-1',
    'match': KnockoutMatchDto.fromDomain(_match()).toJson(),
    'playerScore': 1200,
    'opponentScore': 900,
    'playerRunCount': 3,
    'opponentRunCount': 2,
  };
}

KnockoutPlayerRecords _records() {
  return const KnockoutPlayerRecords(
    playerId: 'player-1',
    tournamentsPlayed: 2,
    tournamentsWon: 1,
    highestRoundReached: 4,
    totalDuelsPlayed: 6,
    totalDuelsWon: 4,
  );
}

KnockoutTournamentHistoryEntry _history() {
  return KnockoutTournamentHistoryEntry(
    tournamentId: _tournamentId,
    tournamentName: 'June Knockout',
    tournamentMonth: DateTime.utc(2026, 6),
    playerId: 'player-1',
    outcome: KnockoutTournamentOutcome.eliminated,
    finalRoundNumber: 2,
    completedAt: DateTime.utc(2026, 6, 3),
  );
}

KnockoutHallOfFameEntry _hallOfFame() {
  return KnockoutHallOfFameEntry(
    playerId: 'champion-1',
    displayName: 'Champion',
    titlesWon: 1,
    wonTournamentMonths: [DateTime.utc(2026, 6)],
  );
}

PlayerProfile _playerProfile({int gamePoints = 50}) {
  return PlayerProfile(
    id: 'player-1',
    username: 'Tester',
    createdAt: DateTime.utc(2026),
    gamePoints: gamePoints,
  );
}

Map<String, Object?> _registrationResponsePayload({
  required String status,
  required bool newlyPersisted,
  required KnockoutTournament tournament,
  required int historicalRemainingGamePoints,
  int? profileGamePoints,
}) {
  return {
    'status': status,
    'newlyPersisted': newlyPersisted,
    'replayed': !newlyPersisted,
    'tournamentId': tournament.id,
    'playerId': 'player-1',
    'tournament': KnockoutTournamentDto.fromDomain(
      tournament,
    ).toRegistrationCatalogJson(),
    'playerEntry': KnockoutPlayerEntryDto.fromDomain(
      tournament.entries.single,
    ).toJson(),
    'historicalRemainingGamePoints': historicalRemainingGamePoints,
    'playerProfile': PlayerProfileDto.fromDomain(
      _playerProfile(
        gamePoints: profileGamePoints ?? historicalRemainingGamePoints,
      ),
    ).toJson(),
  };
}

final class _FakeBackendApiClient implements PlayerBoundBackendApiClient {
  final List<_GetRequest> getRequests = [];
  final List<_PostRequest> postRequests = [];
  final List<_QueuedApiResult> _getResults = [];
  final List<_QueuedApiResult> _postResults = [];

  void enqueueKnockoutScreen(KnockoutTournament tournament) {
    enqueueGetSuccess(_selectionPayload(tournament));
    enqueueGetSuccess({..._readScope(tournament.id), 'playerEntry': null});
    enqueueGetSuccess(_statusPayload(tournament, 'notRegistered'));
  }

  void enqueueGetSuccess(Map<String, Object?> data) {
    _getResults.add(_QueuedApiResult.response(ApiResponse.success(data)));
  }

  void enqueueGetFailure(ApiError error) {
    _getResults.add(_QueuedApiResult.response(ApiResponse.failure(error)));
  }

  void enqueuePostSuccess(Map<String, Object?> data) {
    _postResults.add(_QueuedApiResult.response(ApiResponse.success(data)));
  }

  void enqueuePostFailure(ApiError error) {
    _postResults.add(_QueuedApiResult.response(ApiResponse.failure(error)));
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> delete(
    String path, {
    Map<String, String> queryParameters = const {},
    Map<String, String> headers = const {},
  }) async {
    return const ApiResponse.success({});
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> get(
    String path, {
    Map<String, String> queryParameters = const {},
    Map<String, String> headers = const {},
  }) async {
    getRequests.add(_GetRequest(path, Map<String, String>.of(queryParameters)));

    if (_getResults.isEmpty) {
      throw StateError('No GET response was enqueued for $path.');
    }

    return _getResults.removeAt(0).resolve();
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> patch(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    return const ApiResponse.success({});
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> post(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    postRequests.add(
      _PostRequest(
        path,
        Map<String, Object?>.of(body),
        Map<String, String>.of(headers),
      ),
    );

    if (_postResults.isEmpty) {
      throw StateError('No POST response was enqueued for $path.');
    }

    return _postResults.removeAt(0).resolve();
  }

  @override
  Future<ApiResponse<Map<String, Object?>>> postForPlayer(
    String path, {
    required String playerId,
    required Map<String, Object?> body,
    required Map<String, String> headers,
  }) => post(path, body: body, headers: headers);

  @override
  Future<ApiResponse<Map<String, Object?>>> put(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    return const ApiResponse.success({});
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
  const _QueuedApiResult.response(this.response);

  final ApiResponse<Map<String, Object?>> response;

  ApiResponse<Map<String, Object?>> resolve() => response;
}
