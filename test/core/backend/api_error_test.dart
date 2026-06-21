import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_error.dart';

void main() {
  group('ApiError', () {
    test('accepts snake case error code payloads', () {
      final error = ApiError.fromJson({
        'code': 'validation_failed',
        'message': 'Invalid value.',
        'details': {'field': 'username'},
      });

      expect(error.code, ApiErrorCode.validationFailed);
      expect(error.details['field'], 'username');
    });

    test('uses malformed payload error for non-object payloads', () {
      final error = ApiError.fromJson('not-an-object');

      expect(error.code, ApiErrorCode.malformedPayload);
    });

    test('ignores non-string detail keys safely', () {
      final error = ApiError.fromJson({
        'code': 'conflict',
        'message': 'Duplicate submission.',
        'details': {1: 'ignored', 'runId': 'run-1'},
      });

      expect(error.details, {'runId': 'run-1'});
    });
  });
}
