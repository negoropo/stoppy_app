import 'package:stoppy_app/core/backend/api_contract.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/backend_api_client.dart';
import 'package:stoppy_app/core/backend/backend_repository_not_configured.dart';
import 'package:stoppy_app/core/backend/domain_error_mapper.dart';
import 'package:stoppy_app/core/backend/idempotency_key.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/knockout/data/dto/knockout_mutation_dtos.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_duel_snapshot.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_hall_of_fame_entry.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_entry.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_records.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_status.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_registration_result.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_run.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament_history_entry.dart';
import 'package:stoppy_app/features/knockout/domain/repositories/knockout_repository.dart';

final class BackendKnockoutRepository
    implements
        KnockoutRepository,
        ServerAuthoritativeKnockoutRegistrationRepository {
  const BackendKnockoutRepository({
    required this.apiClient,
    DomainErrorMapper errorMapper = const DomainErrorMapper(),
  }) : _errorMapper = errorMapper;

  final BackendApiClient apiClient;
  final DomainErrorMapper _errorMapper;

  static const tournamentPath = ApiContract.knockoutTournament;
  static const registerPath = ApiContract.knockoutRegistration;
  static const statusPath = ApiContract.knockoutStatus;
  static const activeDuelPath = ApiContract.knockoutActiveDuel;
  static const historyPath = ApiContract.knockoutHistory;
  static const recordsPath = ApiContract.knockoutRecords;
  static const hallOfFamePath = ApiContract.knockoutHallOfFame;
  static const runSubmissionPath = ApiContract.knockoutRunSubmission;

  @override
  Future<KnockoutTournament> fetchCurrentTournament() {
    return backendNotConnected(
      'BackendKnockoutRepository',
      'fetchCurrentTournament',
    );
  }

  @override
  Future<KnockoutPlayerEntry?> currentEntry({
    required String tournamentId,
    required String playerId,
  }) {
    return backendNotConnected('BackendKnockoutRepository', 'currentEntry');
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

    // The backend owns authenticated identity, current tournament selection,
    // registration eligibility, duplicate detection, and GP deduction. The
    // client sends an empty claim plus caller-owned idempotency.
    return _post(
      registerPath,
      body: const KnockoutRegistrationRequestDto().toJson(),
      headers: key.toHeader(),
      decode: (data) =>
          KnockoutRegistrationResponseDto.fromJson(data).toDomain(),
    );
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
    return backendNotConnected('BackendKnockoutRepository', 'fetchActiveDuel');
  }

  @override
  Future<KnockoutPlayerStatus> fetchPlayerStatus({
    required String tournamentId,
    required String playerId,
  }) {
    return backendNotConnected(
      'BackendKnockoutRepository',
      'fetchPlayerStatus',
    );
  }

  @override
  Future<bool> submitKnockoutRun(
    KnockoutRun run, {
    IdempotencyKey? idempotencyKey,
  }) {
    // Prepared only: knockout runs will be submitted as validation claims, not
    // trusted results. The backend must own active-duel eligibility, duplicate
    // detection, accepted scoring, and duel aggregate updates.
    return backendNotConnected(
      'BackendKnockoutRepository',
      'submitKnockoutRun',
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
    return backendNotConnected(
      'BackendKnockoutRepository',
      'fetchPlayerRecords',
    );
  }

  @override
  Future<List<KnockoutTournamentHistoryEntry>> fetchPlayerHistory(
    String playerId,
  ) {
    return backendNotConnected(
      'BackendKnockoutRepository',
      'fetchPlayerHistory',
    );
  }

  @override
  Future<List<KnockoutHallOfFameEntry>> fetchHallOfFame() {
    return backendNotConnected('BackendKnockoutRepository', 'fetchHallOfFame');
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
