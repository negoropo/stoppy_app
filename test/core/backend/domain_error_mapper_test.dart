import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/domain_error_mapper.dart';
import 'package:stoppy_app/features/auth/domain/repositories/auth_repository.dart';

void main() {
  group('DomainErrorMapper', () {
    const mapper = DomainErrorMapper();

    test('maps validation errors to auth exceptions with API message', () {
      final exception = mapper.toAuthException(
        const ApiError(
          code: ApiErrorCode.validationFailed,
          message: 'Username is already taken.',
        ),
      );

      expect(exception, isA<AuthException>());
      expect(exception.message, 'Username is already taken.');
    });

    test('maps API errors to generic repository domain exceptions', () {
      final exception = mapper.toRepositoryException(
        const ApiError(code: ApiErrorCode.forbidden, message: 'Forbidden.'),
      );

      expect(exception.code, ApiErrorCode.forbidden);
      expect(exception.message, 'You do not have permission to do that.');
    });
  });
}
