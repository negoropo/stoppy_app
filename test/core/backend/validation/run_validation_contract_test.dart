import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/validation/run_validation_contract.dart';

void main() {
  test('RunValidationClaimDto serializes competitive verification fields', () {
    final claim = RunValidationClaimDto(
      runId: 'run-1',
      runType: CompetitiveRunType.knockout,
      finalPrecisionPoints: 12000,
      levelReached: 15,
      precisionPointTier: 7,
      runStartedAt: DateTime.utc(2026, 6, 21, 10),
      runEndedAt: DateTime.utc(2026, 6, 21, 10, 10),
    );

    final json = claim.toJson();

    expect(json, {
      'runId': 'run-1',
      'runType': 'knockout',
      'finalPrecisionPoints': 12000,
      'levelReached': 15,
      'precisionPointTier': 7,
      'runStartedAt': '2026-06-21T10:00:00.000Z',
      'runEndedAt': '2026-06-21T10:10:00.000Z',
    });
    expect(
      RunValidationClaimDto.fromJson(json).runType,
      CompetitiveRunType.knockout,
    );
  });

  test('RunValidationResultDto preserves accepted zero-score responses', () {
    final result = RunValidationResultDto.fromJson({
      'accepted': true,
      'serverFinalPrecisionPoints': 0,
    });

    expect(result.serverFinalPrecisionPoints, 0);
  });
}
