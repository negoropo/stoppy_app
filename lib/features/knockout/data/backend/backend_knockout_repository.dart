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

class BackendKnockoutRepository implements KnockoutRepository {
  const BackendKnockoutRepository({this.apiClient});

  final BackendApiClient? apiClient;

  static const tournamentPath = '/knockout/tournament';
  static const registerPath = '/knockout/register';
  static const statusPath = '/knockout/status';
  static const activeDuelPath = '/knockout/active-duel';
  static const historyPath = '/knockout/history';
  static const recordsPath = '/knockout/records';
  static const hallOfFamePath = '/knockout/hall-of-fame';
  static const closeRegistrationPath = '/internal/knockout/close-registration';
  static const startTournamentPath = '/internal/knockout/start';
  static const settleRoundPath = '/internal/knockout/settle-current-round';
  static const knockoutRunPath = '/runs/knockout';

  BackendApiClient get _client {
    final client = apiClient;
    if (client == null) {
      return backendNotConnected('BackendKnockoutRepository', 'apiClient');
    }
    return client;
  }

  @override
  Future<KnockoutTournament> fetchCurrentTournament() {
    final _ = _client;
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
    final _ = _client;
    return backendNotConnected('BackendKnockoutRepository', 'currentEntry');
  }

  @override
  Future<KnockoutRegistrationResult> registerPlayer({
    required KnockoutTournament tournament,
    required PlayerProfile playerProfile,
  }) {
    final _ = _client;
    return backendNotConnected('BackendKnockoutRepository', 'registerPlayer');
  }

  @override
  Future<KnockoutTournament> closeRegistration({required String tournamentId}) {
    final _ = _client;
    return backendNotConnected(
      'BackendKnockoutRepository',
      'closeRegistration',
    );
  }

  @override
  Future<KnockoutTournament> startTournament({required String tournamentId}) {
    final _ = _client;
    return backendNotConnected('BackendKnockoutRepository', 'startTournament');
  }

  @override
  Future<KnockoutDuelSnapshot?> fetchActiveDuel({
    required String tournamentId,
    required String playerId,
  }) {
    final _ = _client;
    return backendNotConnected('BackendKnockoutRepository', 'fetchActiveDuel');
  }

  @override
  Future<KnockoutPlayerStatus> fetchPlayerStatus({
    required String tournamentId,
    required String playerId,
  }) {
    final _ = _client;
    return backendNotConnected(
      'BackendKnockoutRepository',
      'fetchPlayerStatus',
    );
  }

  @override
  Future<bool> submitKnockoutRun(KnockoutRun run) {
    final _ = _client;
    return backendNotConnected(
      'BackendKnockoutRepository',
      'submitKnockoutRun',
    );
  }

  @override
  Future<KnockoutTournament> settleCurrentRound({
    required String tournamentId,
  }) {
    final _ = _client;
    return backendNotConnected(
      'BackendKnockoutRepository',
      'settleCurrentRound',
    );
  }

  @override
  Future<KnockoutPlayerRecords> fetchPlayerRecords(String playerId) {
    final _ = _client;
    return backendNotConnected(
      'BackendKnockoutRepository',
      'fetchPlayerRecords',
    );
  }

  @override
  Future<List<KnockoutTournamentHistoryEntry>> fetchPlayerHistory(
      String playerId,
      ) {
    final _ = _client;
    return backendNotConnected(
      'BackendKnockoutRepository',
      'fetchPlayerHistory',
    );
  }

  @override
  Future<List<KnockoutHallOfFameEntry>> fetchHallOfFame() {
    final _ = _client;
    return backendNotConnected('BackendKnockoutRepository', 'fetchHallOfFame');
  }
}