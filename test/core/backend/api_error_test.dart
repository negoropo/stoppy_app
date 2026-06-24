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

    test('decodes camelCase and snake_case error codes', () {
      expect(
        ApiError.fromJson({
          'code': 'validationFailed',
          'message': 'Invalid.',
        }).code,
        ApiErrorCode.validationFailed,
      );

      expect(
        ApiError.fromJson({
          'code': 'validation_failed',
          'message': 'Invalid.',
        }).code,
        ApiErrorCode.validationFailed,
      );
    });

    test('maps unknown error codes to unknown', () {
      final error = ApiError.fromJson({
        'code': 'future_backend_error',
        'message': 'Future error.',
      });

      expect(error.code, ApiErrorCode.unknown);
      expect(error.message, 'Future error.');
    });

    test('uses a fallback for missing or empty messages', () {
      expect(
        ApiError.fromJson({'code': 'serverError'}).message,
        'Unknown API error.',
      );

      expect(
        ApiError.fromJson({'code': 'serverError', 'message': '   '}).message,
        'Unknown API error.',
      );
    });

    test('ignores invalid details payloads', () {
      final error = ApiError.fromJson({
        'code': 'validationFailed',
        'message': 'Invalid.',
        'details': ['invalid'],
      });

      expect(error.details, isEmpty);
    });

    test('serializes non-empty details', () {
      const error = ApiError(
        code: ApiErrorCode.validationFailed,
        message: 'Invalid.',
        details: {'field': 'username'},
      );

      expect(error.toJson(), {
        'code': 'validationFailed',
        'message': 'Invalid.',
        'details': {'field': 'username'},
      });
    });
  });
}
