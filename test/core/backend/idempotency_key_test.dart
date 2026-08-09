import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_contract.dart';
import 'package:stoppy_app/core/backend/idempotency_key.dart';

void main() {
  group('IdempotencyKey', () {
    test('accepts valid keys and serializes to the backend header', () {
      final key = IdempotencyKey('league-entry:player-1.2026-06-15');

      expect(key.value, 'league-entry:player-1.2026-06-15');
      expect(key.toHeader(), {
        ApiContract.idempotencyKeyHeader: 'league-entry:player-1.2026-06-15',
      });
    });

    test('normalizes leading and trailing whitespace', () {
      expect(IdempotencyKey('  retry-key-1  ').value, 'retry-key-1');
    });

    test('rejects blank keys', () {
      expect(() => IdempotencyKey('   '), throwsA(isA<FormatException>()));
    });

    test('rejects overlong keys', () {
      final overlongKey = 'a' * (IdempotencyKey.maxLength + 1);

      expect(
        () => IdempotencyKey(overlongKey),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects invalid characters', () {
      expect(
        () => IdempotencyKey('league entry 1'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => IdempotencyKey('league/entry/1'),
        throwsA(isA<FormatException>()),
      );
    });

    test('does not expose the key through toString', () {
      final key = IdempotencyKey('sensitive-retry-key');

      expect(key.toString(), isNot(contains('sensitive-retry-key')));
    });
  });
}
