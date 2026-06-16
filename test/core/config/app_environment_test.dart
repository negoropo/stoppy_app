import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/config/app_environment.dart';

void main() {
  group('AppEnvironment', () {
    test('defaults to mock repositories', () {
      const environment = AppEnvironment.mock();

      expect(environment.repositoryRuntime, RepositoryRuntime.mock);
      expect(environment.usesBackend, isFalse);
    });

    test('parses backend runtime name explicitly', () {
      expect(RepositoryRuntimeX.fromName('backend'), RepositoryRuntime.backend);
    });

    test('falls back to mock for unknown runtime names', () {
      expect(
        RepositoryRuntimeX.fromName('anything-else'),
        RepositoryRuntime.mock,
      );
    });
  });
}
