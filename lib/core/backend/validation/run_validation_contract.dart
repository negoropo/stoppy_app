import '../json_reader.dart';

enum CompetitiveRunType { league, knockout }

class RunValidationClaimDto {
  const RunValidationClaimDto({
    required this.runId,
    required this.runType,
    required this.finalPrecisionPoints,
    required this.levelReached,
    required this.precisionPointTier,
    required this.runStartedAt,
    required this.runEndedAt,
  });

  final String runId;
  final CompetitiveRunType runType;
  final int finalPrecisionPoints;
  final int levelReached;
  final int precisionPointTier;
  final DateTime runStartedAt;
  final DateTime runEndedAt;

  factory RunValidationClaimDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'RunValidationClaimDto',
    );

    final runStartedAt = reader.requiredDateTime('runStartedAt');
    final runEndedAt = reader.requiredDateTime('runEndedAt');

    if (runEndedAt.isBefore(runStartedAt)) {
      throw const FormatException(
        'RunValidationClaimDto.runEndedAt must not be before runStartedAt.',
      );
    }

    return RunValidationClaimDto(
      runId: reader.requiredString('runId'),
      runType: _runTypeFromName(reader.requiredString('runType')),
      finalPrecisionPoints: reader.requiredNonNegativeInt(
        'finalPrecisionPoints',
      ),
      levelReached: reader.requiredPositiveInt('levelReached'),
      precisionPointTier: reader.requiredPositiveInt('precisionPointTier'),
      runStartedAt: runStartedAt,
      runEndedAt: runEndedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'runId': runId,
      'runType': runType.name,
      'finalPrecisionPoints': finalPrecisionPoints,
      'levelReached': levelReached,
      'precisionPointTier': precisionPointTier,
      'runStartedAt': runStartedAt.toIso8601String(),
      'runEndedAt': runEndedAt.toIso8601String(),
    };
  }
}

class RunValidationResultDto {
  const RunValidationResultDto({
    required this.accepted,
    this.serverFinalPrecisionPoints,
    this.rejectionCode,
  });

  final bool accepted;
  final int? serverFinalPrecisionPoints;
  final String? rejectionCode;

  factory RunValidationResultDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'RunValidationResultDto',
    );

    final accepted = reader.requiredBool('accepted');
    final serverFinalPrecisionPoints = reader.optionalNullableInt(
      'serverFinalPrecisionPoints',
    );
    final rejectionCode = reader.optionalString('rejectionCode');

    if (accepted && rejectionCode != null) {
      throw const FormatException(
        'Accepted validation result cannot contain rejectionCode.',
      );
    }

    if (!accepted && rejectionCode == null) {
      throw const FormatException(
        'Rejected validation result must contain rejectionCode.',
      );
    }

    return RunValidationResultDto(
      accepted: accepted,
      serverFinalPrecisionPoints: serverFinalPrecisionPoints,
      rejectionCode: rejectionCode,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'accepted': accepted,
      if (serverFinalPrecisionPoints != null)
        'serverFinalPrecisionPoints': serverFinalPrecisionPoints,
      if (rejectionCode != null) 'rejectionCode': rejectionCode,
    };
  }
}

CompetitiveRunType _runTypeFromName(String value) {
  for (final runType in CompetitiveRunType.values) {
    if (runType.name == value) {
      return runType;
    }
  }
  throw FormatException('Unknown competitive run type: $value');
}