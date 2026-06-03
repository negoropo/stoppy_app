import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/features/auth/data/backend/backend_auth_repository.dart';

void main() {
  test(
    'BackendAuthRepository is an explicit future-backend skeleton',
    () async {
    const repository = BackendAuthRepository();

    expect(
      () => repository.login(username: 'Tester', password: 'password'),
      throwsA(
        isA<ApiException>().having(
            (exception) => exception.error.code,
            'code',
            ApiErrorCode.notImplemented,
          ),
        ),
      );
    },
  );
}
