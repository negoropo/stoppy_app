import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/api_response.dart';

void main() {
  group('ApiResponse', () {
    test('serializes success response', () {
      const response = ApiResponse.success({'value': 7});

      expect(response.toJson((data) => data), {
        'success': true,
        'data': {'value': 7},
      });
    });

    test('deserializes standardized API error', () {
      final response = ApiResponse<Map<String, Object?>>.fromJson({
        'success': false,
        'error': {
          'code': 'validationFailed',
          'message': 'Invalid input.',
          'details': {'field': 'username'},
        },
      }, (json) => (json as Map).cast<String, Object?>());

      expect(response.isSuccess, isFalse);
      expect(response.error?.code, ApiErrorCode.validationFailed);
      expect(response.error?.message, 'Invalid input.');
      expect(response.error?.details['field'], 'username');
    });

    test('returns malformed payload failure for invalid envelopes', () {
      final response = ApiResponse<Map<String, Object?>>.fromJson({
        'success': 'yes',
      }, (json) => json! as Map<String, Object?>);

      expect(response.isSuccess, isFalse);
      expect(response.error?.code, ApiErrorCode.malformedPayload);
    });

    test('converts decoder API exceptions into failure envelopes', () {
      final response = ApiResponse<String>.fromJson(
        {'success': true, 'data': {}},
        (_) => throw const ApiException(
          ApiError(
            code: ApiErrorCode.malformedPayload,
            message: 'Missing token.',
          ),
        ),
      );

      expect(response.isSuccess, isFalse);
      expect(response.error?.message, 'Missing token.');
    });
  });
}
