import 'package:stoppy_app/core/backend/api_contract.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/backend_api_client.dart';
import 'package:stoppy_app/core/backend/backend_repository_not_configured.dart';
import 'package:stoppy_app/core/backend/domain_error_mapper.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
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

final class BackendLeagueRepository implements LeagueRepository {
  const BackendLeagueRepository({
    required this.apiClient,
    DomainErrorMapper errorMapper = const DomainErrorMapper(),
  }) : _errorMapper = errorMapper;

  final BackendApiClient apiClient;
  final DomainErrorMapper _errorMapper;

  static const currentEntryPath = ApiContract.leagueCurrentEntry;
  static const rankingPath = ApiContract.leagueRanking;
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
  Future<LeaguePlayerEntry> enterWeeklyLeague(PlayerProfile profile) {
    return backendNotConnected('BackendLeagueRepository', 'enterWeeklyLeague');
  }

  @override
  Future<LeagueRunSubmissionResult> submitLeagueRun(WeeklyLeagueRun run) {
    return backendNotConnected('BackendLeagueRepository', 'submitLeagueRun');
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
}
