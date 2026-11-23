import 'knockout_player_entry.dart';
import 'knockout_tournament.dart';
import '../../../auth/domain/models/player_profile.dart';

enum KnockoutRegistrationFailureReason {
  duplicateRegistration,
  insufficientGamePoints,
  registrationClosed,
  tournamentAlreadyStarted,
}

class KnockoutRegistrationResult {
  const KnockoutRegistrationResult._({
    required this.isSuccess,
    required this.tournament,
    required this.tournamentId,
    this.playerEntry,
    this.historicalRemainingGamePoints,
    this.playerProfile,
    this.failureReason,
    this.message,
  }) : assert(isSuccess ? playerEntry != null : failureReason != null);

  factory KnockoutRegistrationResult.success({
    required KnockoutTournament tournament,
    required KnockoutPlayerEntry playerEntry,
    int? historicalRemainingGamePoints,
    PlayerProfile? playerProfile,
  }) {
    return KnockoutRegistrationResult._(
      isSuccess: true,
      tournament: tournament,
      tournamentId: tournament.id,
      playerEntry: playerEntry,
      historicalRemainingGamePoints: historicalRemainingGamePoints,
      playerProfile: playerProfile,
      message: 'Knockout registration confirmed.',
    );
  }

  factory KnockoutRegistrationResult.failure({
    KnockoutTournament? tournament,
    String? tournamentId,
    required KnockoutRegistrationFailureReason failureReason,
    required String message,
  }) {
    return KnockoutRegistrationResult._(
      isSuccess: false,
      tournament: tournament,
      tournamentId: tournamentId ?? tournament!.id,
      failureReason: failureReason,
      message: message,
    );
  }

  final bool isSuccess;

  final KnockoutTournament? tournament;
  final String tournamentId;

  final KnockoutPlayerEntry? playerEntry;

  final int? historicalRemainingGamePoints;

  final PlayerProfile? playerProfile;

  final KnockoutRegistrationFailureReason? failureReason;

  final String? message;

  bool get isFailure {
    return !isSuccess;
  }
}
