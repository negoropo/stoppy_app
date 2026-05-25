import '../../../auth/domain/models/player_profile.dart';
import '../models/knockout_player_entry.dart';
import '../models/knockout_registration_result.dart';
import '../models/knockout_duel_snapshot.dart';
import '../models/knockout_run.dart';
import '../models/knockout_tournament.dart';

abstract class KnockoutRepository {
  Future<KnockoutTournament> fetchCurrentTournament();

  Future<KnockoutPlayerEntry?> currentEntry({
    required String tournamentId,
    required String playerId,
  });

  Future<KnockoutRegistrationResult> registerPlayer({
    required KnockoutTournament tournament,
    required PlayerProfile playerProfile,
  });

  Future<KnockoutTournament> closeRegistration({required String tournamentId});

  Future<KnockoutTournament> startTournament({required String tournamentId});

  Future<KnockoutDuelSnapshot?> fetchActiveDuel({
    required String tournamentId,
    required String playerId,
  });

  Future<void> submitKnockoutRun(KnockoutRun run);

  Future<KnockoutTournament> settleCurrentRound({required String tournamentId});
}
