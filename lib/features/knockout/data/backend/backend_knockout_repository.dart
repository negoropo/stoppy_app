import 'package:stoppy_app/core/backend/api_contract.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/backend_api_client.dart';
import 'package:stoppy_app/core/backend/backend_repository_not_configured.dart';
import 'package:stoppy_app/core/backend/domain_error_mapper.dart';
import 'package:stoppy_app/core/backend/idempotency_key.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/knockout/data/dto/knockout_mutation_dtos.dart';
import 'package:stoppy_app/features/knockout/data/dto/knockout_persistence_dtos.dart';
import 'package:stoppy_app/features/knockout/data/dto/knockout_read_dtos.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_duel_snapshot.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_hall_of_fame_entry.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_entry.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_records.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_status.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_registration_result.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_run.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament_selection.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament_history_entry.dart';
import 'package:stoppy_app/features/knockout/domain/repositories/knockout_repository.dart';

import 'knockout_registration_attempt_store.dart';

final class BackendKnockoutRepository
    implements
        KnockoutRepository,
        AuthoritativeKnockoutReadRepository,
        ServerAuthoritativeKnockoutRegistrationRepository,
        KnockoutRegistrationRecoveryRepository {
  BackendKnockoutRepository({
    required this.apiClient,
    this.registrationAttemptStore,
    DomainErrorMapper errorMapper = const DomainErrorMapper(),
  }) : _errorMapper = errorMapper;

  final BackendApiClient apiClient;
  final KnockoutRegistrationAttemptStore? registrationAttemptStore;
  final DomainErrorMapper _errorMapper;

  static const tournamentPath = ApiContract.knockoutTournament;
  static const currentEntryPath = ApiContract.knockoutEntry;
  static const registerPath = ApiContract.knockoutRegistration;
  static const statusPath = ApiContract.knockoutStatus;
  static const activeDuelPath = ApiContract.knockoutActiveDuel;
  static const historyPath = ApiContract.knockoutHistory;
  static const recordsPath = ApiContract.knockoutRecords;
  static const hallOfFamePath = ApiContract.knockoutHallOfFame;
  static const runSubmissionPath = ApiContract.knockoutRunSubmission;

  @override
  Future<KnockoutTournament> fetchCurrentTournament() async {
    final selection = await discoverTournaments();
    return selection.competition ??
        selection.registration ??
        (throw const RepositoryDomainException(
          'No relevant Knockout tournament is available.',
          code: ApiErrorCode.notFound,
        ));
  }

  @override
  Future<KnockoutTournamentSelection> discoverTournaments() {
    return _get(
      tournamentPath,
      queryParameters: const {},
      decode: (data) {
        if (!data.containsKey('competition') ||
            !data.containsKey('registration')) {
          throw const FormatException(
            'Knockout discovery is missing selection slots.',
          );
        }
        KnockoutTournament? decodeSlot(Object? json) => json == null
            ? null
            : KnockoutTournamentDto.fromReadCatalog(json).toDomain();
        return KnockoutTournamentSelection(
          competition: decodeSlot(data['competition']),
          registration: decodeSlot(data['registration']),
        );
      },
    );
  }

  @override
  Future<KnockoutTournament> fetchTournament(String tournamentId) {
    return _get(
      tournamentPath,
      queryParameters: {'tournamentId': tournamentId},
      decode: (data) {
        final tournament = KnockoutTournamentDto.fromReadCatalog(
          data['tournament'],
        ).toDomain();
        if (tournament.id != tournamentId) {
          throw const FormatException(
            'Knockout catalog target does not match the request.',
          );
        }
        return tournament;
      },
    );
  }

  @override
  Future<KnockoutPlayerEntry?> currentEntry({
    required String tournamentId,
    required String playerId,
  }) {
    return _get(
      currentEntryPath,
      queryParameters: {'tournamentId': tournamentId},
      decode: (data) {
        _verifyReadScope(data, tournamentId, playerId);
        if (!data.containsKey('playerEntry')) {
          throw const FormatException(
            'Knockout entry response is missing playerEntry.',
          );
        }
        final entry = KnockoutCurrentEntryResponseDto.fromJson(data).toDomain();
        if (entry != null &&
            (entry.tournamentId != tournamentId ||
                entry.playerId != playerId)) {
          throw const FormatException(
            'Knockout entry does not match the request.',
          );
        }
        return entry;
      },
    );
  }

  @override
  Future<KnockoutRegistrationResult> registerPlayer({
    required KnockoutTournament tournament,
    required PlayerProfile playerProfile,
    IdempotencyKey? idempotencyKey,
  }) {
    final key = idempotencyKey;
    if (key == null) {
      throw _malformedPayload(
        'Knockout registration requires an idempotency key.',
      );
    }

    try {
      return _submitRegistration(
        playerProfile.id,
        requested: KnockoutRegistrationAttempt(
          target: KnockoutRegistrationRequestDto(tournamentId: tournament.id),
          key: key,
        ),
      );
    } on FormatException catch (exception) {
      throw _malformedPayload(exception.message);
    }
  }

  KnockoutRegistrationAttemptStore get _attemptStore =>
      registrationAttemptStore ??
      (throw KnockoutRegistrationAttemptStore.unavailable);

  @override
  Future<bool> hasPendingRegistration(String playerId) async =>
      await _attemptStore.read(playerId) != null;

  @override
  Future<KnockoutRegistrationResult> retryRegistration({
    required PlayerProfile playerProfile,
  }) => _submitRegistration(playerProfile.id);

  Future<KnockoutRegistrationResult> _submitRegistration(
    String playerId, {
    KnockoutRegistrationAttempt? requested,
  }) async {
    final client = apiClient;
    if (client is! PlayerBoundBackendApiClient) {
      throw const RepositoryDomainException(
        'The backend client cannot verify the registration account.',
        code: ApiErrorCode.invalidConfiguration,
      );
    }
    final store = _attemptStore;
    return store.whileSubmitting(playerId, () async {
      final pending = await store.read(playerId);
      if (pending != null &&
          requested != null &&
          (pending.target.tournamentId != requested.target.tournamentId ||
              pending.key != requested.key)) {
        throw const RepositoryDomainException(
          'Retry the pending Knockout registration before starting another.',
          code: ApiErrorCode.conflict,
        );
      }
      final attempt = pending ?? requested;
      if (attempt == null) {
        throw const RepositoryDomainException(
          'There is no pending Knockout registration to retry.',
          code: ApiErrorCode.notFound,
        );
      }
      // Persist before transport so navigation, a lost response, or a restart
      // can never reconstruct this operation from the newly displayed month.
      if (pending == null) await store.save(playerId, attempt);
      final result = await _post(
        registerPath,
        body: attempt.target.toJson(),
        headers: attempt.key.toHeader(),
        player: (client: client, id: playerId),
        decode: (data) {
          final response = KnockoutRegistrationResponseDto.fromJson(data);
          if (response.tournamentId != attempt.target.tournamentId ||
              response.playerId != playerId) {
            throw const FormatException(
              'Knockout registration response does not match the attempt.',
            );
          }
          return response.toDomain();
        },
      );
      // Only a verified semantic outcome resolves the pending operation.
      // Transport and HTTP errors can occur after the original COMMIT.
      await store.clear(playerId);
      return result;
    });
  }

  @override
  Future<KnockoutTournament> closeRegistration({required String tournamentId}) {
    return backendNotConnected(
      'BackendKnockoutRepository',
      'closeRegistration',
    );
  }

  @override
  Future<KnockoutTournament> startTournament({required String tournamentId}) {
    return backendNotConnected('BackendKnockoutRepository', 'startTournament');
  }

  @override
  Future<KnockoutDuelSnapshot?> fetchActiveDuel({
    required String tournamentId,
    required String playerId,
  }) {
    return _get(
      activeDuelPath,
      queryParameters: {'tournamentId': tournamentId},
      decode: (data) {
        final duel = KnockoutActiveDuelResponseDto.fromJson(data).toDomain();
        if (duel != null &&
            (duel.tournamentId != tournamentId || duel.playerId != playerId)) {
          throw const FormatException(
            'Knockout duel does not match the request.',
          );
        }
        return duel;
      },
    );
  }

  @override
  Future<KnockoutPlayerStatus> fetchPlayerStatus({
    required String tournamentId,
    required String playerId,
  }) {
    return _get(
      statusPath,
      queryParameters: {'tournamentId': tournamentId},
      decode: (data) {
        _verifyReadScope(data, tournamentId, playerId);
        final status = KnockoutPlayerStatusDto.fromJson(data).toDomain();
        final catalogStatus = data['tournamentStatus'];
        final windowOpen = data['registrationWindowOpen'];
        final duel = status.duelSnapshot;
        if (catalogStatus is! String ||
            windowOpen is! bool ||
            (duel != null &&
                (duel.tournamentId != tournamentId ||
                    duel.playerId != playerId))) {
          throw const FormatException(
            'Knockout status does not match the request.',
          );
        }
        final tournamentStatus = KnockoutTournamentStatus.values.byName(
          catalogStatus,
        );
        if (windowOpen &&
            tournamentStatus != KnockoutTournamentStatus.registrationOpen) {
          throw const FormatException(
            'An open Knockout window requires an open catalog state.',
          );
        }
        return KnockoutPlayerStatus(
          state: status.state,
          duelSnapshot: duel,
          tournamentStatus: tournamentStatus,
          registrationWindowOpen: windowOpen,
        );
      },
    );
  }

  void _verifyReadScope(
    Map<String, Object?> data,
    String tournamentId,
    String playerId,
  ) {
    if (data['tournamentId'] != tournamentId || data['playerId'] != playerId) {
      throw const FormatException(
        'Knockout read response does not match the request.',
      );
    }
  }

  @override
  Future<bool> submitKnockoutRun(
    KnockoutRun run, {
    IdempotencyKey? idempotencyKey,
  }) {
    if (idempotencyKey == null ||
        run.startedAt == null ||
        run.tournamentId == null) {
      throw _malformedPayload(
        'Knockout submission requires a key and run context.',
      );
    }
    final Map<String, Object?> body;
    try {
      body = KnockoutRunSubmissionRequestDto.fromJson({
        'runId': run.id,
        'tournamentId': run.tournamentId,
        'roundNumber': run.roundNumber,
        'matchId': run.matchId,
        'runStartedAt': run.startedAt!.toIso8601String(),
        'runCompletedAt': run.completedAt.toIso8601String(),
        'claimedFinalPrecisionPoints': run.score,
        'runMode': 'knockout',
      }).toJson();
    } on FormatException catch (error) {
      throw _malformedPayload(error.message);
    } on ApiException catch (error) {
      throw _errorMapper.toRepositoryException(error.error);
    }
    // Context and score are claims. Authentication, duel assignment, accepted
    // scoring and persistence are validated exclusively by the server.
    return _post(
      runSubmissionPath,
      body: body,
      headers: idempotencyKey.toHeader(),
      decode: (data) {
        final response = KnockoutRunSubmissionResponseDto.fromJson(data);
        if (!response.accepted) {
          throw _errorMapper.toRepositoryException(
            ApiError(
              code: ApiErrorCode.validationFailed,
              message: 'Knockout run submission was rejected.',
              details: {'rejectionCode': response.rejectionCode!.name},
            ),
          );
        }
        final acceptedRun = response.acceptedRun!;
        // Identity and association must resolve this logical claim. Player
        // identity and the accepted score remain server-authoritative.
        if (acceptedRun.id != body['runId'] ||
            acceptedRun.matchId != body['matchId'] ||
            acceptedRun.roundNumber != body['roundNumber']) {
          throw const FormatException(
            'Accepted Knockout run does not match the submitted run association.',
          );
        }
        // The existing bool contract exposes resolution only, not a locally
        // reconstructed competitive projection. Replay is successful too.
        acceptedRun.toDomain();
        return true;
      },
    );
  }

  @override
  Future<KnockoutTournament> settleCurrentRound({
    required String tournamentId,
  }) {
    return backendNotConnected(
      'BackendKnockoutRepository',
      'settleCurrentRound',
    );
  }

  @override
  Future<KnockoutPlayerRecords> fetchPlayerRecords(String playerId) {
    return _get(
      recordsPath,
      queryParameters: const {},
      decode: (data) => KnockoutPlayerRecordsDto.fromJson(data).toDomain(),
    );
  }

  @override
  Future<List<KnockoutTournamentHistoryEntry>> fetchPlayerHistory(
    String playerId,
  ) {
    return _get(
      historyPath,
      queryParameters: const {},
      decode: (data) => KnockoutHistoryResponseDto.fromJson(data).toDomain(),
    );
  }

  @override
  Future<List<KnockoutHallOfFameEntry>> fetchHallOfFame() {
    return _get(
      hallOfFamePath,
      queryParameters: const {},
      decode: (data) => KnockoutHallOfFameResponseDto.fromJson(data).toDomain(),
    );
  }

  Future<T> _get<T>(
    String path, {
    required Map<String, String> queryParameters,
    required T Function(Map<String, Object?> data) decode,
  }) async {
    try {
      final response = await apiClient.get(
        path,
        queryParameters: queryParameters,
      );

      if (!response.isSuccess) {
        throw _errorMapper.toRepositoryException(response.requireError());
      }

      return decode(response.requireData());
    } on RepositoryDomainException {
      rethrow;
    } on ApiException catch (exception) {
      throw _errorMapper.toRepositoryException(exception.error);
    } on FormatException catch (exception) {
      throw _malformedPayload(exception.message);
    } on ArgumentError catch (exception) {
      throw _malformedPayload(
        exception.message?.toString() ?? 'Malformed Knockout payload.',
      );
    } on StateError catch (exception) {
      throw _malformedPayload(exception.message);
    }
  }

  Future<T> _post<T>(
    String path, {
    required Map<String, Object?> body,
    required Map<String, String> headers,
    required T Function(Map<String, Object?> data) decode,
    ({PlayerBoundBackendApiClient client, String id})? player,
  }) async {
    try {
      final response = await (player != null
          ? player.client.postForPlayer(
              path,
              playerId: player.id,
              body: body,
              headers: headers,
            )
          : apiClient.post(path, body: body, headers: headers));

      if (!response.isSuccess) {
        throw _errorMapper.toRepositoryException(response.requireError());
      }

      return decode(response.requireData());
    } on RepositoryDomainException {
      rethrow;
    } on ApiException catch (exception) {
      throw _errorMapper.toRepositoryException(exception.error);
    } on FormatException catch (exception) {
      throw _malformedPayload(exception.message);
    } on ArgumentError catch (exception) {
      throw _malformedPayload(
        exception.message?.toString() ?? 'Malformed Knockout payload.',
      );
    } on StateError catch (exception) {
      throw _malformedPayload(exception.message);
    }
  }

  RepositoryDomainException _malformedPayload(String message) {
    return _errorMapper.toRepositoryException(
      ApiError(code: ApiErrorCode.malformedPayload, message: message),
    );
  }
}
