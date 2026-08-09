import 'package:stoppy_app/core/backend/json_reader.dart';
import 'package:stoppy_app/core/backend/validation/run_validation_contract.dart';
import 'package:stoppy_app/features/auth/data/dto/player_profile_dto.dart';

import '../../domain/models/league_season_id.dart';
import 'league_persistence_dtos.dart';
import 'weekly_league_run_dto.dart';

enum LeagueMutationStatus { accepted, rejected, idempotentReplay }

enum LeagueEntryRejectionCode {
  alreadyActive,
  entryWindowClosed,
  insufficientGp,
  noReservedSlot,
  outsideLeague,
  settlementInProgress,
  stalePlayerState,
}

enum LeagueRunSubmissionRejectionCode {
  noActiveEntry,
  outsideLeague,
  seasonMismatch,
  alreadySubmitted,
  invalidRun,
  validationFailed,
  timestampInvalid,
  durationInvalid,
  settlementInProgress,
  stalePlayerState,
}

enum LeagueRunSubmissionMode { league }

final class LeagueEntryRequestDto {
  const LeagueEntryRequestDto();

  factory LeagueEntryRequestDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'LeagueEntryRequestDto',
    );
    if (reader.toMap().isNotEmpty) {
      throw const FormatException('League entry request body must be empty.');
    }
    return const LeagueEntryRequestDto();
  }

  Map<String, Object?> toJson() {
    return const <String, Object?>{};
  }
}

final class LeagueEntryResponseDto {
  const LeagueEntryResponseDto({
    required this.status,
    this.seasonId,
    this.entry,
    this.currentDivision,
    this.remainingGamePoints,
    this.playerProfile,
    this.rejectionCode,
  });

  final LeagueMutationStatus status;
  final String? seasonId;
  final LeaguePlayerEntryDto? entry;
  final int? currentDivision;
  final int? remainingGamePoints;
  final PlayerProfileDto? playerProfile;
  final LeagueEntryRejectionCode? rejectionCode;

  factory LeagueEntryResponseDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'LeagueEntryResponseDto',
    );
    final data = reader.toMap();

    return LeagueEntryResponseDto(
      status: _mutationStatusFromName(reader.requiredString('status')),
      seasonId: reader.optionalString('seasonId'),
      entry: _optionalEntry(data['entry']),
      currentDivision: reader.optionalPositiveInt('currentDivision'),
      remainingGamePoints: _optionalNonNegativeInt(
        reader,
        'remainingGamePoints',
      ),
      playerProfile: _optionalPlayerProfile(data['playerProfile']),
      rejectionCode: _optionalLeagueEntryRejectionCode(
        reader.optionalString('rejectionCode'),
      ),
    )._validated();
  }

  LeagueSeasonId? get parsedSeasonId {
    final value = seasonId;
    return value == null
        ? null
        : LeagueSeasonId(weekStartDate: _seasonDate(value));
  }

  bool get accepted => status != LeagueMutationStatus.rejected;

  LeagueEntryResponseDto _validated() {
    final hasAuthoritativeEntry =
        seasonId != null && entry != null && currentDivision != null;
    final hasRemainingGp =
        remainingGamePoints != null && remainingGamePoints! >= 0;

    if (accepted) {
      if (!hasAuthoritativeEntry || !hasRemainingGp || rejectionCode != null) {
        throw const FormatException(
          'Accepted League entry response must contain authoritative entry state.',
        );
      }
      parsedSeasonId;
    } else {
      if (rejectionCode == null ||
          entry != null ||
          currentDivision != null ||
          playerProfile != null ||
          hasRemainingGp) {
        throw const FormatException(
          'Rejected League entry response contains contradictory state.',
        );
      }
      if (seasonId != null) {
        parsedSeasonId;
      }
    }

    return this;
  }

  Map<String, Object?> toJson() {
    _validated();
    return {
      'status': status.name,
      if (seasonId != null) 'seasonId': seasonId,
      if (entry != null) 'entry': entry!.toJson(),
      if (currentDivision != null) 'currentDivision': currentDivision,
      if (remainingGamePoints != null)
        'remainingGamePoints': remainingGamePoints,
      if (playerProfile != null) 'playerProfile': playerProfile!.toJson(),
      if (rejectionCode != null) 'rejectionCode': rejectionCode!.name,
    };
  }
}

final class LeagueRunSubmissionRequestDto {
  const LeagueRunSubmissionRequestDto({
    required this.runId,
    required this.seasonId,
    required this.runStartedAt,
    required this.runCompletedAt,
    required this.claimedFinalPrecisionPoints,
    required this.runMode,
    this.validationClaim,
  });

  static const Duration maxRunDuration = Duration(hours: 1);

  final String runId;
  final String seasonId;
  final DateTime runStartedAt;
  final DateTime runCompletedAt;
  final int claimedFinalPrecisionPoints;
  final LeagueRunSubmissionMode runMode;
  final RunValidationClaimDto? validationClaim;

  factory LeagueRunSubmissionRequestDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'LeagueRunSubmissionRequestDto',
    );
    final data = reader.toMap();
    final runStartedAt = reader.requiredDateTime('runStartedAt');
    final runCompletedAt = reader.requiredDateTime('runCompletedAt');

    return LeagueRunSubmissionRequestDto(
      runId: reader.requiredString('runId').trim(),
      seasonId: reader.requiredString('seasonId').trim(),
      runStartedAt: runStartedAt,
      runCompletedAt: runCompletedAt,
      claimedFinalPrecisionPoints: reader.requiredNonNegativeInt(
        'claimedFinalPrecisionPoints',
      ),
      runMode: _runSubmissionModeFromName(reader.requiredString('runMode')),
      validationClaim: _optionalRunValidationClaim(data['validationClaim']),
    )._validated();
  }

  LeagueSeasonId get parsedSeasonId {
    return LeagueSeasonId(weekStartDate: _seasonDate(seasonId));
  }

  LeagueRunSubmissionRequestDto _validated() {
    parsedSeasonId;

    if (runId.trim().isEmpty) {
      throw const FormatException('League run ID must not be blank.');
    }

    if (seasonId.trim().isEmpty) {
      throw const FormatException('League season ID must not be blank.');
    }

    if (claimedFinalPrecisionPoints < 0) {
      throw const FormatException(
        'Claimed final Precision Points must not be negative.',
      );
    }

    if (runCompletedAt.isBefore(runStartedAt)) {
      throw const FormatException(
        'League run completion time must not be before start time.',
      );
    }

    if (runCompletedAt.difference(runStartedAt) > maxRunDuration) {
      throw const FormatException('League run duration exceeds the maximum.');
    }

    final claim = validationClaim;
    if (claim != null) {
      if (claim.runType != CompetitiveRunType.league ||
          claim.runId != runId ||
          claim.finalPrecisionPoints != claimedFinalPrecisionPoints ||
          claim.runStartedAt != runStartedAt ||
          claim.runEndedAt != runCompletedAt) {
        throw const FormatException(
          'League run validation claim does not match submission request.',
        );
      }
    }

    return this;
  }

  Map<String, Object?> toJson() {
    _validated();
    return {
      'runId': runId,
      'seasonId': seasonId,
      'runStartedAt': runStartedAt.toIso8601String(),
      'runCompletedAt': runCompletedAt.toIso8601String(),
      'claimedFinalPrecisionPoints': claimedFinalPrecisionPoints,
      'runMode': runMode.name,
      if (validationClaim != null) 'validationClaim': validationClaim!.toJson(),
    };
  }
}

final class LeagueRunSubmissionResponseDto {
  const LeagueRunSubmissionResponseDto({
    required this.status,
    required this.newlyPersisted,
    this.acceptedRun,
    this.playerRecords,
    this.playerProfile,
    this.validationResult,
    this.rejectionCode,
  });

  final LeagueMutationStatus status;
  final bool newlyPersisted;
  final WeeklyLeagueRunDto? acceptedRun;
  final PlayerLeagueRecordsDto? playerRecords;
  final PlayerProfileDto? playerProfile;
  final RunValidationResultDto? validationResult;
  final LeagueRunSubmissionRejectionCode? rejectionCode;

  factory LeagueRunSubmissionResponseDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'LeagueRunSubmissionResponseDto',
    );
    final data = reader.toMap();

    return LeagueRunSubmissionResponseDto(
      status: _mutationStatusFromName(reader.requiredString('status')),
      newlyPersisted: reader.requiredBool('newlyPersisted'),
      acceptedRun: _optionalWeeklyRun(data['acceptedRun']),
      playerRecords: _optionalPlayerRecords(data['playerRecords']),
      playerProfile: _optionalPlayerProfile(data['playerProfile']),
      validationResult: _optionalValidationResult(data['validationResult']),
      rejectionCode: _optionalLeagueRunRejectionCode(
        reader.optionalString('rejectionCode'),
      ),
    )._validated();
  }

  bool get accepted => status != LeagueMutationStatus.rejected;

  LeagueRunSubmissionResponseDto _validated() {
    if (accepted) {
      if (acceptedRun == null ||
          rejectionCode != null ||
          (status == LeagueMutationStatus.accepted && !newlyPersisted) ||
          (status == LeagueMutationStatus.idempotentReplay && newlyPersisted)) {
        throw const FormatException(
          'Accepted League run response contains contradictory state.',
        );
      }

      final result = validationResult;
      if (result != null && !result.accepted) {
        throw const FormatException(
          'Accepted League run response cannot contain rejected validation.',
        );
      }
    } else {
      if (newlyPersisted || acceptedRun != null || rejectionCode == null) {
        throw const FormatException(
          'Rejected League run response contains contradictory state.',
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
      if (playerRecords != null) 'playerRecords': playerRecords!.toJson(),
      if (playerProfile != null) 'playerProfile': playerProfile!.toJson(),
      if (validationResult != null)
        'validationResult': validationResult!.toJson(),
      if (rejectionCode != null) 'rejectionCode': rejectionCode!.name,
    };
  }
}

LeagueMutationStatus _mutationStatusFromName(String value) {
  for (final status in LeagueMutationStatus.values) {
    if (status.name == value) {
      return status;
    }
  }
  throw FormatException('Unknown League mutation status: $value.');
}

LeagueEntryRejectionCode? _optionalLeagueEntryRejectionCode(String? value) {
  if (value == null) {
    return null;
  }
  for (final code in LeagueEntryRejectionCode.values) {
    if (code.name == value) {
      return code;
    }
  }
  throw FormatException('Unknown League entry rejection code: $value.');
}

LeagueRunSubmissionRejectionCode? _optionalLeagueRunRejectionCode(
  String? value,
) {
  if (value == null) {
    return null;
  }
  for (final code in LeagueRunSubmissionRejectionCode.values) {
    if (code.name == value) {
      return code;
    }
  }
  throw FormatException('Unknown League run rejection code: $value.');
}

LeagueRunSubmissionMode _runSubmissionModeFromName(String value) {
  for (final mode in LeagueRunSubmissionMode.values) {
    if (mode.name == value) {
      return mode;
    }
  }
  throw FormatException('Unknown League run submission mode: $value.');
}

DateTime _seasonDate(String value) {
  final normalized = value.trim();
  final parsed = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)
      ? DateTime.tryParse(normalized)
      : null;
  if (parsed == null) {
    throw FormatException('Invalid League season identifier: $value.');
  }
  final canonicalSeasonId = LeagueSeasonId.fromDate(parsed).value;
  if (canonicalSeasonId != normalized) {
    throw FormatException('Invalid League season identifier: $value.');
  }
  return parsed;
}

LeaguePlayerEntryDto? _optionalEntry(Object? value) {
  return value == null ? null : LeaguePlayerEntryDto.fromJson(value);
}

PlayerProfileDto? _optionalPlayerProfile(Object? value) {
  return value == null ? null : PlayerProfileDto.fromJson(value);
}

WeeklyLeagueRunDto? _optionalWeeklyRun(Object? value) {
  return value == null ? null : WeeklyLeagueRunDto.fromJson(value);
}

PlayerLeagueRecordsDto? _optionalPlayerRecords(Object? value) {
  return value == null ? null : PlayerLeagueRecordsDto.fromJson(value);
}

RunValidationClaimDto? _optionalRunValidationClaim(Object? value) {
  return value == null ? null : RunValidationClaimDto.fromJson(value);
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
