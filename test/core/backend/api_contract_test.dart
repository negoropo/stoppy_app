import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_contract.dart';

void main() {
  group('ApiContract', () {
    test('builds versioned API prefix', () {
      expect(ApiContract.version, 'v1');
      expect(ApiContract.apiPrefix, '/api/v1');
    });

    test('identifies public auth endpoints', () {
      expect(
        ApiContract.isPublicAuthPath(ApiContract.authRegister),
        isTrue,
      );

      expect(
        ApiContract.isPublicAuthPath(ApiContract.authLogin),
        isTrue,
      );
    });

    test('normalizes whitespace and trailing slash', () {
      expect(
        ApiContract.isPublicAuthPath(
          '  ${ApiContract.authLogin}/  ',
        ),
        isTrue,
      );
    });

    test('does not classify protected endpoints as public', () {
      expect(
        ApiContract.isPublicAuthPath(ApiContract.playerProfile),
        isFalse,
      );

      expect(
        ApiContract.isPublicAuthPath(ApiContract.leagueSnapshot),
        isFalse,
      );

      expect(
        ApiContract.isPublicAuthPath(ApiContract.knockoutTournament),
        isFalse,
      );
    });

    test('does not classify similar auth paths as public', () {
      expect(
        ApiContract.isPublicAuthPath('/api/v1/auth/login-extra'),
        isFalse,
      );

      expect(
        ApiContract.isPublicAuthPath('/api/v1/auth/register/confirm'),
        isFalse,
      );
    });

    test('does not classify absolute URLs as public paths', () {
      expect(
        ApiContract.isPublicAuthPath(
          'https://api.stoppy.test${ApiContract.authLogin}',
        ),
        isFalse,
      );
    });
  });
}