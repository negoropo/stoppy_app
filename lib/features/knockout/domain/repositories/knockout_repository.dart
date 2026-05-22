import '../../../auth/domain/models/player_profile.dart';
import '../models/knockout_player_entry.dart';
import '../models/knockout_registration_result.dart';
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

  Future<KnockoutTournament> closeRegistration({
    required String tournamentId,
  });

  Future<KnockoutTournament> startTournament({
    required String tournamentId,
  });
}
