import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_contract.dart';

void main() {
  group('ApiContract.isPublicAuthPath', () {
    test('recognizes every public authentication path', () {
      expect(ApiContract.isPublicAuthPath(ApiContract.authRegister), isTrue);
      expect(ApiContract.isPublicAuthPath(ApiContract.authLogin), isTrue);
      expect(ApiContract.isPublicAuthPath(ApiContract.authRefresh), isTrue);
    });

    test('normalizes surrounding whitespace and trailing slashes', () {
      expect(
        ApiContract.isPublicAuthPath('  ${ApiContract.authRegister}/  '),
        isTrue,
      );

      expect(
        ApiContract.isPublicAuthPath('  ${ApiContract.authLogin}///  '),
        isTrue,
      );

      expect(
        ApiContract.isPublicAuthPath('  ${ApiContract.authRefresh}//  '),
        isTrue,
      );
    });

    test('does not classify protected endpoints as public', () {
      expect(ApiContract.isPublicAuthPath(ApiContract.playerProfile), isFalse);
      expect(ApiContract.isPublicAuthPath(ApiContract.leagueSnapshot), isFalse);
      expect(ApiContract.isPublicAuthPath(ApiContract.knockoutStatus), isFalse);
    });

    test('does not accept absolute authentication URLs', () {
      expect(
        ApiContract.isPublicAuthPath(
          'https://example.com${ApiContract.authLogin}',
        ),
        isFalse,
      );

      expect(
        ApiContract.isPublicAuthPath(
          'http://example.com${ApiContract.authRegister}',
        ),
        isFalse,
      );
    });

    test('does not accept paths containing an authority', () {
      expect(
        ApiContract.isPublicAuthPath('//example.com${ApiContract.authLogin}'),
        isFalse,
      );
    });

    test(
      'does not classify paths with query parameters or fragments as public',
      () {
        expect(
          ApiContract.isPublicAuthPath('${ApiContract.authLogin}?source=test'),
          isFalse,
        );

        expect(
          ApiContract.isPublicAuthPath('${ApiContract.authRefresh}#token'),
          isFalse,
        );

        expect(
          ApiContract.isPublicAuthPath(
            '${ApiContract.authRegister}?source=test#registration',
          ),
          isFalse,
        );
      },
    );

    test('does not classify auth-like sibling paths as public', () {
      expect(
        ApiContract.isPublicAuthPath('${ApiContract.authLogin}/extra'),
        isFalse,
      );
      expect(
        ApiContract.isPublicAuthPath('${ApiContract.authRefresh}-legacy'),
        isFalse,
      );
      expect(
        ApiContract.isPublicAuthPath('${ApiContract.authRegister}s'),
        isFalse,
      );
    });

    test('does not accept relative paths without a leading slash', () {
      expect(
        ApiContract.isPublicAuthPath(ApiContract.authLogin.substring(1)),
        isFalse,
      );
      expect(
        ApiContract.isPublicAuthPath(ApiContract.authRegister.substring(1)),
        isFalse,
      );
      expect(
        ApiContract.isPublicAuthPath(ApiContract.authRefresh.substring(1)),
        isFalse,
      );
    });

    test('uses exact case-sensitive endpoint matching', () {
      expect(
        ApiContract.isPublicAuthPath(ApiContract.authLogin.toUpperCase()),
        isFalse,
      );

      expect(ApiContract.isPublicAuthPath('/api/v1/Auth/login'), isFalse);
    });

    test('returns false for blank paths', () {
      expect(ApiContract.isPublicAuthPath(''), isFalse);
      expect(ApiContract.isPublicAuthPath('   '), isFalse);
    });
  });
}
