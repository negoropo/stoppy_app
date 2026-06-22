import 'package:stoppy_app/core/backend/api_contract.dart';
import 'package:stoppy_app/core/backend/backend_api_client.dart';
import 'package:stoppy_app/core/backend/backend_repository_not_configured.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
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

final class BackendKnockoutRepository implements KnockoutRepository {
  const BackendKnockoutRepository({
    required this.apiClient,
  });

  final BackendApiClient apiClient;

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
    return backendNotConnected(
      'BackendKnockoutRepository',
      'currentEntry',
    );
  }

  @override
  Future<KnockoutRegistrationResult> registerPlayer({
    required KnockoutTournament tournament,
    required PlayerProfile playerProfile,
  }) {
    return backendNotConnected(
      'BackendKnockoutRepository',
      'registerPlayer',
    );
  }

  @override
  Future<KnockoutTournament> closeRegistration({
    required String tournamentId,
  }) {
    return backendNotConnected(
      'BackendKnockoutRepository',
      'closeRegistration',
    );
  }

  @override
  Future<KnockoutTournament> startTournament({
    required String tournamentId,
  }) {
    return backendNotConnected(
      'BackendKnockoutRepository',
      'startTournament',
    );
  }

  @override
  Future<KnockoutDuelSnapshot?> fetchActiveDuel({
    required String tournamentId,
    required String playerId,
  }) {
    return backendNotConnected(
      'BackendKnockoutRepository',
      'fetchActiveDuel',
    );
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
  Future<bool> submitKnockoutRun(KnockoutRun run) {
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
  Future<KnockoutPlayerRecords> fetchPlayerRecords(
      String playerId,
      ) {
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
    return backendNotConnected(
      'BackendKnockoutRepository',
      'fetchHallOfFame',
    );
  }
}