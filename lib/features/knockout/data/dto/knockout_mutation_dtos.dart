import 'package:stoppy_app/core/backend/json_reader.dart';
import 'package:stoppy_app/core/backend/validation/run_validation_contract.dart';
import 'package:stoppy_app/features/auth/data/dto/player_profile_dto.dart';

import '../../domain/models/knockout_registration_result.dart';
import 'knockout_persistence_dtos.dart';
import 'knockout_run_dto.dart';

enum KnockoutMutationStatus { accepted, rejected, idempotentReplay }

enum KnockoutRegistrationRejectionCode {
  duplicateRegistration,
  insufficientGp,
  registrationClosed,
  tournamentAlreadyStarted,
  tournamentUnavailable,
  settlementInProgress,
  stalePlayerState,
}

enum KnockoutRunSubmissionRejectionCode {
  noActiveDuel,
  tournamentUnavailable,
  roundMismatch,
  matchMismatch,
  alreadySubmitted,
  invalidRun,
  validationFailed,
  timestampInvalid,
  durationInvalid,
  settlementInProgress,
  stalePlayerState,
}

enum KnockoutRunSubmissionMode { knockout }

final class KnockoutRegistrationRequestDto {
  const KnockoutRegistrationRequestDto();

  factory KnockoutRegistrationRequestDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'KnockoutRegistrationRequestDto',
    );
    if (reader.toMap().isNotEmpty) {
      throw const FormatException(
        'Knockout registration request body must be empty.',
      );
    }
    return const KnockoutRegistrationRequestDto();
  }

  Map<String, Object?> toJson() {
    return const <String, Object?>{};
  }
}

final class KnockoutRegistrationResponseDto {
  const KnockoutRegistrationResponseDto({
    required this.status,
    required this.newlyPersisted,
    required this.tournament,
    this.playerEntry,
    this.remainingGamePoints,
    this.playerProfile,
    this.rejectionCode,
  });

  final KnockoutMutationStatus status;
  final bool newlyPersisted;
  final KnockoutTournamentDto tournament;
  final KnockoutPlayerEntryDto? playerEntry;
  final int? remainingGamePoints;
  final PlayerProfileDto? playerProfile;
  final KnockoutRegistrationRejectionCode? rejectionCode;

  factory KnockoutRegistrationResponseDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'KnockoutRegistrationResponseDto',
    );
    final data = reader.toMap();

    return KnockoutRegistrationResponseDto(
      status: _mutationStatusFromName(reader.requiredString('status')),
      newlyPersisted: reader.requiredBool('newlyPersisted'),
      tournament: KnockoutTournamentDto.fromJson(data['tournament']),
      playerEntry: _optionalEntry(data['playerEntry']),
      remainingGamePoints: _optionalNonNegativeInt(
        reader,
        'remainingGamePoints',
      ),
      playerProfile: _optionalPlayerProfile(data['playerProfile']),
      rejectionCode: _optionalRegistrationRejectionCode(
        reader.optionalString('rejectionCode'),
      ),
    )._validated();
  }

  bool get accepted => status != KnockoutMutationStatus.rejected;

  KnockoutRegistrationResponseDto _validated() {
    if (accepted) {
      if (playerEntry == null ||
          remainingGamePoints == null ||
          rejectionCode != null ||
          (status == KnockoutMutationStatus.accepted && !newlyPersisted) ||
          (status == KnockoutMutationStatus.idempotentReplay &&
              newlyPersisted)) {
        throw const FormatException(
          'Accepted Knockout registration response contains contradictory state.',
        );
      }

      if (playerEntry!.tournamentId != tournament.id) {
        throw const FormatException(
          'Accepted Knockout registration entry must belong to the returned tournament.',
        );
      }

      final profile = playerProfile;
      if (profile != null && profile.gamePoints != remainingGamePoints) {
        throw const FormatException(
          'Accepted Knockout registration profile GP must match remaining GP.',
        );
      }
    } else {
      if (newlyPersisted ||
          playerEntry != null ||
          remainingGamePoints != null ||
          playerProfile != null ||
          rejectionCode == null) {
        throw const FormatException(
          'Rejected Knockout registration response contains contradictory state.',
        );
      }
    }

    return this;
  }

  KnockoutRegistrationResult toDomain() {
    _validated();
    final domainTournament = tournament.toDomain();
    if (accepted) {
      return KnockoutRegistrationResult.success(
        tournament: domainTournament,
        playerEntry: playerEntry!.toDomain(),
      );
    }

    return KnockoutRegistrationResult.failure(
      tournament: domainTournament,
      failureReason: _domainRegistrationFailureReason(rejectionCode!),
      message: _registrationRejectionMessage(rejectionCode!),
    );
  }

  Map<String, Object?> toJson() {
    _validated();
    return {
      'status': status.name,
      'newlyPersisted': newlyPersisted,
      'tournament': tournament.toJson(),
      if (playerEntry != null) 'playerEntry': playerEntry!.toJson(),
      if (remainingGamePoints != null)
        'remainingGamePoints': remainingGamePoints,
      if (playerProfile != null) 'playerProfile': playerProfile!.toJson(),
      if (rejectionCode != null) 'rejectionCode': rejectionCode!.name,
    };
  }
}

final class KnockoutRunSubmissionRequestDto {
  const KnockoutRunSubmissionRequestDto({
    required this.runId,
    required this.tournamentId,
    required this.roundNumber,
    required this.matchId,
    required this.runStartedAt,
    required this.runCompletedAt,
    required this.claimedFinalPrecisionPoints,
    required this.runMode,
    this.validationClaim,
  });

  static const Duration maxRunDuration = Duration(hours: 1);

  final String runId;
  final String tournamentId;
  final int roundNumber;
  final String matchId;
  final DateTime runStartedAt;
  final DateTime runCompletedAt;
  final int claimedFinalPrecisionPoints;
  final KnockoutRunSubmissionMode runMode;
  final RunValidationClaimDto? validationClaim;

  factory KnockoutRunSubmissionRequestDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'KnockoutRunSubmissionRequestDto',
    );
    final data = reader.toMap();
    final runStartedAt = reader.requiredDateTime('runStartedAt');
    final runCompletedAt = reader.requiredDateTime('runCompletedAt');

    return KnockoutRunSubmissionRequestDto(
      runId: reader.requiredString('runId').trim(),
      tournamentId: reader.requiredString('tournamentId').trim(),
      roundNumber: reader.requiredPositiveInt('roundNumber'),
      matchId: reader.requiredString('matchId').trim(),
      runStartedAt: runStartedAt,
      runCompletedAt: runCompletedAt,
      claimedFinalPrecisionPoints: reader.requiredNonNegativeInt(
        'claimedFinalPrecisionPoints',
      ),
      runMode: _runSubmissionModeFromName(reader.requiredString('runMode')),
      validationClaim: _optionalRunValidationClaim(data['validationClaim']),
    )._validated();
  }

  KnockoutRunSubmissionRequestDto _validated() {
    if (runId.isEmpty) {
      throw const FormatException('Knockout run ID must not be blank.');
    }

    if (tournamentId.isEmpty) {
      throw const FormatException('Knockout tournament ID must not be blank.');
    }

    if (matchId.isEmpty) {
      throw const FormatException('Knockout match ID must not be blank.');
    }

    if (claimedFinalPrecisionPoints < 0) {
      throw const FormatException(
        'Claimed final Precision Points must not be negative.',
      );
    }

    if (runCompletedAt.isBefore(runStartedAt)) {
      throw const FormatException(
        'Knockout run completion time must not be before start time.',
      );
    }

    if (runCompletedAt.difference(runStartedAt) > maxRunDuration) {
      throw const FormatException('Knockout run duration exceeds the maximum.');
    }

    final claim = validationClaim;
    if (claim != null) {
      if (claim.runType != CompetitiveRunType.knockout ||
          claim.runId != runId ||
          claim.finalPrecisionPoints != claimedFinalPrecisionPoints ||
          claim.runStartedAt != runStartedAt ||
          claim.runEndedAt != runCompletedAt) {
        throw const FormatException(
          'Knockout run validation claim does not match submission request.',
        );
      }
    }

    return this;
  }

  Map<String, Object?> toJson() {
    _validated();
    return {
      'runId': runId,
      'tournamentId': tournamentId,
      'roundNumber': roundNumber,
      'matchId': matchId,
      'runStartedAt': runStartedAt.toIso8601String(),
      'runCompletedAt': runCompletedAt.toIso8601String(),
      'claimedFinalPrecisionPoints': claimedFinalPrecisionPoints,
      'runMode': runMode.name,
      if (validationClaim != null) 'validationClaim': validationClaim!.toJson(),
    };
  }
}

final class KnockoutRunSubmissionResponseDto {
  const KnockoutRunSubmissionResponseDto({
    required this.status,
    required this.newlyPersisted,
    this.acceptedRun,
    this.playerProfile,
    this.validationResult,
    this.rejectionCode,
  });

  final KnockoutMutationStatus status;
  final bool newlyPersisted;
  final KnockoutRunDto? acceptedRun;
  final PlayerProfileDto? playerProfile;
  final RunValidationResultDto? validationResult;
  final KnockoutRunSubmissionRejectionCode? rejectionCode;

  factory KnockoutRunSubmissionResponseDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'KnockoutRunSubmissionResponseDto',
    );
    final data = reader.toMap();

    return KnockoutRunSubmissionResponseDto(
      status: _mutationStatusFromName(reader.requiredString('status')),
      newlyPersisted: reader.requiredBool('newlyPersisted'),
      acceptedRun: _optionalRun(data['acceptedRun']),
      playerProfile: _optionalPlayerProfile(data['playerProfile']),
      validationResult: _optionalValidationResult(data['validationResult']),
      rejectionCode: _optionalRunRejectionCode(
        reader.optionalString('rejectionCode'),
      ),
    )._validated();
  }

  bool get accepted => status != KnockoutMutationStatus.rejected;

  KnockoutRunSubmissionResponseDto _validated() {
    if (accepted) {
      if (acceptedRun == null ||
          rejectionCode != null ||
          (status == KnockoutMutationStatus.accepted && !newlyPersisted) ||
          (status == KnockoutMutationStatus.idempotentReplay &&
              newlyPersisted)) {
        throw const FormatException(
          'Accepted Knockout run response contains contradictory state.',
        );
      }

      final result = validationResult;
      if (result != null && !result.accepted) {
        throw const FormatException(
          'Accepted Knockout run response cannot contain rejected validation.',
        );
      }

      if (result?.serverFinalPrecisionPoints != null &&
          result!.serverFinalPrecisionPoints != acceptedRun!.score) {
        throw const FormatException(
          'Accepted Knockout run score must match server validation result.',
        );
      }
    } else {
      if (newlyPersisted || acceptedRun != null || rejectionCode == null) {
        throw const FormatException(
          'Rejected Knockout run response contains contradictory state.',
        );
      }

      final result = validationResult;
      if (result != null && result.accepted) {
        throw const FormatException(
          'Rejected Knockout run response cannot contain accepted validation.',
        );
      }
    }

    return this;
  }

  Map<String, Object?> toJson() {
    _validated();
    return {
      'status': status.name,
      'newlyPersisted': newlyPersisted,
      if (acceptedRun != null) 'acceptedRun': acceptedRun!.toJson(),
      if (playerProfile != null) 'playerProfile': playerProfile!.toJson(),
      if (validationResult != null)
        'validationResult': validationResult!.toJson(),
      if (rejectionCode != null) 'rejectionCode': rejectionCode!.name,
    };
  }
}

KnockoutMutationStatus _mutationStatusFromName(String value) {
  for (final status in KnockoutMutationStatus.values) {
    if (status.name == value) {
      return status;
    }
  }
  throw FormatException('Unknown Knockout mutation status: $value.');
}

KnockoutRegistrationRejectionCode? _optionalRegistrationRejectionCode(
  String? value,
) {
  if (value == null) {
    return null;
  }
  for (final code in KnockoutRegistrationRejectionCode.values) {
    if (code.name == value) {
      return code;
    }
  }
  throw FormatException(
    'Unknown Knockout registration rejection code: $value.',
  );
}

KnockoutRunSubmissionRejectionCode? _optionalRunRejectionCode(String? value) {
  if (value == null) {
    return null;
  }
  for (final code in KnockoutRunSubmissionRejectionCode.values) {
    if (code.name == value) {
      return code;
    }
  }
  throw FormatException('Unknown Knockout run rejection code: $value.');
}

KnockoutRunSubmissionMode _runSubmissionModeFromName(String value) {
  for (final mode in KnockoutRunSubmissionMode.values) {
    if (mode.name == value) {
      return mode;
    }
  }
  throw FormatException('Unknown Knockout run submission mode: $value.');
}

KnockoutRegistrationFailureReason _domainRegistrationFailureReason(
  KnockoutRegistrationRejectionCode code,
) {
  return switch (code) {
    KnockoutRegistrationRejectionCode.duplicateRegistration =>
      KnockoutRegistrationFailureReason.duplicateRegistration,
    KnockoutRegistrationRejectionCode.insufficientGp =>
      KnockoutRegistrationFailureReason.insufficientGamePoints,
    KnockoutRegistrationRejectionCode.registrationClosed ||
    KnockoutRegistrationRejectionCode.tournamentUnavailable ||
    KnockoutRegistrationRejectionCode.settlementInProgress ||
    KnockoutRegistrationRejectionCode.stalePlayerState =>
      KnockoutRegistrationFailureReason.registrationClosed,
    KnockoutRegistrationRejectionCode.tournamentAlreadyStarted =>
      KnockoutRegistrationFailureReason.tournamentAlreadyStarted,
  };
}

String _registrationRejectionMessage(KnockoutRegistrationRejectionCode code) {
  return switch (code) {
    KnockoutRegistrationRejectionCode.duplicateRegistration =>
      'You are already registered for this Knockout.',
    KnockoutRegistrationRejectionCode.insufficientGp =>
      'You need 25 GP to register.',
    KnockoutRegistrationRejectionCode.tournamentAlreadyStarted =>
      'This Knockout has already started.',
    KnockoutRegistrationRejectionCode.registrationClosed ||
    KnockoutRegistrationRejectionCode.tournamentUnavailable ||
    KnockoutRegistrationRejectionCode.settlementInProgress ||
    KnockoutRegistrationRejectionCode.stalePlayerState =>
      'Knockout registration is currently closed.',
  };
}

KnockoutPlayerEntryDto? _optionalEntry(Object? value) {
  return value == null ? null : KnockoutPlayerEntryDto.fromJson(value);
}

PlayerProfileDto? _optionalPlayerProfile(Object? value) {
  return value == null ? null : PlayerProfileDto.fromJson(value);
}

RunValidationClaimDto? _optionalRunValidationClaim(Object? value) {
  return value == null ? null : RunValidationClaimDto.fromJson(value);
}

KnockoutRunDto? _optionalRun(Object? value) {
  return value == null ? null : KnockoutRunDto.fromJson(value);
}

RunValidationResultDto? _optionalValidationResult(Object? value) {
  return value == null ? null : RunValidationResultDto.fromJson(value);
}

int? _optionalNonNegativeInt(JsonReader reader, String key) {
  final value = reader.toMap()[key];
  if (value == null) {
    return null;
  }
  if (value is int && value >= 0) {
    return value;
  }
  throw FormatException('$key must be a non-negative integer or null.');
}
