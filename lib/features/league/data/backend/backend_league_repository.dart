import 'package:stoppy_app/core/backend/api_contract.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/backend_api_client.dart';
import 'package:stoppy_app/core/backend/backend_repository_not_configured.dart';
import 'package:stoppy_app/core/backend/domain_error_mapper.dart';
import 'package:stoppy_app/core/backend/idempotency_key.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/league/data/dto/league_mutation_dtos.dart';
import 'package:stoppy_app/features/league/data/dto/league_persistence_dtos.dart';
import 'package:stoppy_app/features/league/data/dto/league_read_dtos.dart';
import 'package:stoppy_app/features/league/domain/models/league_player_entry.dart';
import 'package:stoppy_app/features/league/domain/models/league_ranking_entry.dart';
import 'package:stoppy_app/features/league/domain/models/league_ranking_snapshot.dart';
import 'package:stoppy_app/features/league/domain/models/league_season_id.dart';
import 'package:stoppy_app/features/league/domain/models/league_season_settlement_result.dart';
import 'package:stoppy_app/features/league/domain/models/player_league_achievements.dart';
import 'package:stoppy_app/features/league/domain/models/player_league_records.dart';
import 'package:stoppy_app/features/league/domain/models/weekly_league_history_entry.dart';
import 'package:stoppy_app/features/league/domain/models/weekly_league_run.dart';
import 'package:stoppy_app/features/league/domain/repositories/league_repository.dart';

final class BackendLeagueRepository
    implements LeagueRepository, ServerAuthoritativeLeagueEntryRepository {
  const BackendLeagueRepository({
    required this.apiClient,
    DomainErrorMapper errorMapper = const DomainErrorMapper(),
  }) : _errorMapper = errorMapper;

  final BackendApiClient apiClient;
  final DomainErrorMapper _errorMapper;

  static const currentEntryPath = ApiContract.leagueCurrentEntry;
  static const rankingPath = ApiContract.leagueRanking;
  static const enterPath = ApiContract.leagueEnter;
  static const runSubmissionPath = ApiContract.leagueRunSubmission;
  static const snapshotPath = ApiContract.leagueSnapshot;
  static const historyPath = ApiContract.leagueHistory;
  static const recordsPath = ApiContract.leagueRecords;
  static const achievementsPath = ApiContract.leagueAchievements;
  static const weeklyRunsPath = ApiContract.leagueRuns;

  @override
  Future<LeaguePlayerEntry?> currentEntry(String playerId) {
    final normalizedPlayerId = _requirePlayerId(playerId);

    return _get(
      currentEntryPath,
      queryParameters: {'playerId': normalizedPlayerId},
      decode: (data) => LeagueCurrentEntryResponseDto.fromJson(data).toDomain(),
    );
  }

  @override
  Future<List<LeagueRankingEntry>> fetchDivisionRanking(int divisionNumber) {
    final validDivisionNumber = _requireDivisionNumber(divisionNumber);

    return _get(
      rankingPath,
      queryParameters: {'divisionNumber': '$validDivisionNumber'},
      decode: (data) => LeagueRankingResponseDto.fromJson(data).toDomain(),
    );
  }

  @override
  Future<LeaguePlayerEntry> enterWeeklyLeague(
    PlayerProfile profile, {
    IdempotencyKey? idempotencyKey,
  }) {
    final key = idempotencyKey;
    if (key == null) {
      throw _malformedPayload('League entry requires an idempotency key.');
    }

    return _post(
      enterPath,
      body: const LeagueEntryRequestDto().toJson(),
      headers: key.toHeader(),
      decode: (data) {
        final response = LeagueEntryResponseDto.fromJson(data);
        if (!response.accepted) {
          throw _leagueEntryRejection(response);
        }

        return LeagueEntryResult(
          entry: response.entry!.toDomain(),
          seasonId: response.parsedSeasonId,
          remainingGamePoints: response.remainingGamePoints,
          playerProfile: response.playerProfile?.toDomain(),
        );
      },
    );
  }

  @override
  Future<LeagueRunSubmissionResult> submitLeagueRun(
    WeeklyLeagueRun run, {
    IdempotencyKey? idempotencyKey,
  }) {
    final key = idempotencyKey;
    if (key == null) {
      throw _malformedPayload(
        'League run submission requires an idempotency key.',
      );
    }

    final LeagueRunSubmissionRequestDto request;
    try {
      request = LeagueRunSubmissionRequestDto.fromDomain(run);
    } on FormatException catch (exception) {
      throw _malformedPayload(exception.message);
    }

    // The client submits a claim only. Player identity, run validity,
    // duplicate detection, and accepted score remain server-authoritative.
    return _post(
      runSubmissionPath,
      body: request.toJson(),
      headers: key.toHeader(),
      decode: (data) {
        final response = LeagueRunSubmissionResponseDto.fromJson(data);
        if (!response.accepted) {
          throw _leagueRunSubmissionRejection(response);
        }

        final acceptedRun = response.acceptedRun!.toDomain();
        final playerRecords =
            response.playerRecords?.toDomain() ??
            PlayerLeagueRecords.empty(acceptedRun.playerId);

        return LeagueRunSubmissionResult(
          accepted: true,
          playerRecords: playerRecords,
          acceptedRun: acceptedRun,
          playerProfile: response.playerProfile?.toDomain(),
          newlyPersisted: response.newlyPersisted,
        );
      },
    );
  }

  @override
  Future<PlayerLeagueRecords> fetchPlayerRecords(String playerId) {
    final normalizedPlayerId = _requirePlayerId(playerId);

    return _get(
      recordsPath,
      queryParameters: {'playerId': normalizedPlayerId},
      decode: (data) => PlayerLeagueRecordsDto.fromJson(data).toDomain(),
    );
  }

  @override
  Future<PlayerLeagueAchievements> fetchPlayerAchievements(String playerId) {
    final normalizedPlayerId = _requirePlayerId(playerId);

    return _get(
      achievementsPath,
      queryParameters: {'playerId': normalizedPlayerId},
      decode: (data) => PlayerLeagueAchievementsDto.fromJson(data).toDomain(),
    );
  }

  @override
  Future<List<WeeklyLeagueHistoryEntry>> fetchPlayerHistory(String playerId) {
    final normalizedPlayerId = _requirePlayerId(playerId);

    return _get(
      historyPath,
      queryParameters: {'playerId': normalizedPlayerId},
      decode: (data) => LeagueHistoryResponseDto.fromJson(data).toDomain(),
    );
  }

  @override
  Future<List<WeeklyLeagueRun>> fetchPlayerWeeklyRuns({
    required String playerId,
    required LeagueSeasonId seasonId,
  }) {
    final normalizedPlayerId = _requirePlayerId(playerId);

    return _get(
      weeklyRunsPath,
      queryParameters: {
        'playerId': normalizedPlayerId,
        'seasonId': seasonId.value,
      },
      decode: (data) => LeagueWeeklyRunsResponseDto.fromJson(data).toDomain(),
    );
  }

  @override
  Future<LeagueRankingSnapshot> fetchPlayerSnapshot({
    required String playerId,
    required int divisionNumber,
  }) {
    final normalizedPlayerId = _requirePlayerId(playerId);
    final validDivisionNumber = _requireDivisionNumber(divisionNumber);

    return _get(
      snapshotPath,
      queryParameters: {
        'playerId': normalizedPlayerId,
        'divisionNumber': '$validDivisionNumber',
      },
      decode: (data) => LeagueRankingSnapshotDto.fromJson(data).toDomain(),
    );
  }

  @override
  Future<LeagueSeasonSettlementResult> settleCurrentSeason({
    required DateTime now,
  }) {
    return backendNotConnected(
      'BackendLeagueRepository',
      'settleCurrentSeason',
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
        exception.message?.toString() ?? 'Malformed League payload.',
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
  }) async {
    try {
      final response = await apiClient.post(path, body: body, headers: headers);

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
        exception.message?.toString() ?? 'Malformed League payload.',
      );
    } on StateError catch (exception) {
      throw _malformedPayload(exception.message);
    }
  }

  String _requirePlayerId(String playerId) {
    final normalizedPlayerId = playerId.trim();

    if (normalizedPlayerId.isEmpty) {
      throw _malformedPayload('Player ID is required.');
    }

    return normalizedPlayerId;
  }

  int _requireDivisionNumber(int divisionNumber) {
    if (divisionNumber <= 0) {
      throw _malformedPayload('Division number must be positive.');
    }

    return divisionNumber;
  }

  RepositoryDomainException _malformedPayload(String message) {
    return _errorMapper.toRepositoryException(
      ApiError(code: ApiErrorCode.malformedPayload, message: message),
    );
  }

  RepositoryDomainException _leagueEntryRejection(
    LeagueEntryResponseDto response,
  ) {
    final rejectionCode = response.rejectionCode;
    if (rejectionCode == null) {
      return _malformedPayload(
        'Rejected League entry response is missing code.',
      );
    }

    final apiError = switch (rejectionCode) {
      LeagueEntryRejectionCode.alreadyActive => ApiError(
        code: ApiErrorCode.conflict,
        message: 'Weekly league entry is already active.',
        details: {'rejectionCode': rejectionCode.name},
      ),
      LeagueEntryRejectionCode.insufficientGp => ApiError(
        code: ApiErrorCode.validationFailed,
        message: 'You do not have enough GP to enter the weekly league.',
        details: {'rejectionCode': rejectionCode.name},
      ),
      LeagueEntryRejectionCode.entryWindowClosed => ApiError(
        code: ApiErrorCode.validationFailed,
        message: 'Weekly league entry is currently closed.',
        details: {'rejectionCode': rejectionCode.name},
      ),
      LeagueEntryRejectionCode.noReservedSlot ||
      LeagueEntryRejectionCode.outsideLeague => ApiError(
        code: ApiErrorCode.validationFailed,
        message: 'Weekly league entry is not available for this player state.',
        details: {'rejectionCode': rejectionCode.name},
      ),
      LeagueEntryRejectionCode.settlementInProgress => ApiError(
        code: ApiErrorCode.conflict,
        message: 'Weekly league settlement is currently in progress.',
        details: {'rejectionCode': rejectionCode.name},
      ),
      LeagueEntryRejectionCode.stalePlayerState => ApiError(
        code: ApiErrorCode.conflict,
        message: 'Player league state is stale. Please refresh and try again.',
        details: {'rejectionCode': rejectionCode.name},
      ),
    };

    return _errorMapper.toRepositoryException(apiError);
  }

  RepositoryDomainException _leagueRunSubmissionRejection(
    LeagueRunSubmissionResponseDto response,
  ) {
    final rejectionCode = response.rejectionCode;
    if (rejectionCode == null) {
      return _malformedPayload('Rejected League run response is missing code.');
    }

    final apiError = switch (rejectionCode) {
      LeagueRunSubmissionRejectionCode.noActiveEntry ||
      LeagueRunSubmissionRejectionCode.outsideLeague => ApiError(
        code: ApiErrorCode.validationFailed,
        message: 'No active weekly league entry is available for this run.',
        details: {'rejectionCode': rejectionCode.name},
      ),
      LeagueRunSubmissionRejectionCode.seasonMismatch => ApiError(
        code: ApiErrorCode.validationFailed,
        message: 'League run belongs to a stale or invalid season.',
        details: {'rejectionCode': rejectionCode.name},
      ),
      LeagueRunSubmissionRejectionCode.alreadySubmitted => ApiError(
        code: ApiErrorCode.conflict,
        message: 'League run submission was already processed.',
        details: {'rejectionCode': rejectionCode.name},
      ),
      LeagueRunSubmissionRejectionCode.invalidRun ||
      LeagueRunSubmissionRejectionCode.validationFailed ||
      LeagueRunSubmissionRejectionCode.timestampInvalid ||
      LeagueRunSubmissionRejectionCode.durationInvalid => ApiError(
        code: ApiErrorCode.validationFailed,
        message: 'League run claim was rejected by server validation.',
        details: {'rejectionCode': rejectionCode.name},
      ),
      LeagueRunSubmissionRejectionCode.settlementInProgress => ApiError(
        code: ApiErrorCode.conflict,
        message: 'Weekly league settlement is currently in progress.',
        details: {'rejectionCode': rejectionCode.name},
      ),
      LeagueRunSubmissionRejectionCode.stalePlayerState => ApiError(
        code: ApiErrorCode.conflict,
        message: 'Player league state is stale. Please refresh and try again.',
        details: {'rejectionCode': rejectionCode.name},
      ),
    };

    return _errorMapper.toRepositoryException(apiError);
  }
}
