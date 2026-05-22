import 'knockout_player_entry.dart';
import 'knockout_tournament.dart';

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
    this.playerEntry,
    this.failureReason,
    this.message,
  }) : assert(
  isSuccess
      ? playerEntry != null
      : failureReason != null,
  );

  factory KnockoutRegistrationResult.success({
    required KnockoutTournament tournament,
    required KnockoutPlayerEntry playerEntry,
  }) {
    return KnockoutRegistrationResult._(
      isSuccess: true,
      tournament: tournament,
      playerEntry: playerEntry,
      message: 'Knockout registration confirmed.',
    );
  }

  factory KnockoutRegistrationResult.failure({
    required KnockoutTournament tournament,
    required KnockoutRegistrationFailureReason failureReason,
    required String message,
  }) {
    return KnockoutRegistrationResult._(
      isSuccess: false,
      tournament: tournament,
      failureReason: failureReason,
      message: message,
    );
  }

  final bool isSuccess;

  final KnockoutTournament tournament;

  final KnockoutPlayerEntry? playerEntry;

  final KnockoutRegistrationFailureReason? failureReason;

  final String? message;

  bool get isFailure {
    return !isSuccess;
  }
}