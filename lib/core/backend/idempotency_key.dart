import 'api_contract.dart';

final class IdempotencyKey {
  IdempotencyKey(String value) : value = _normalize(value);

  static const int maxLength = 128;

  // The character set is intentionally URL/header friendly. Keeping keys
  // printable and compact makes them safe to persist and compare server-side
  // without leaking request payload details into logs or diagnostics.
  static final RegExp _allowedCharacters = RegExp(r'^[A-Za-z0-9._:-]+$');

  final String value;

  Map<String, String> toHeader() {
    return {ApiContract.idempotencyKeyHeader: value};
  }

  static String _normalize(String rawValue) {
    final normalized = rawValue.trim();

    if (normalized.isEmpty) {
      throw const FormatException('Idempotency key must not be blank.');
    }

    if (normalized.length > maxLength) {
      throw FormatException(
        'Idempotency key must not exceed $maxLength characters.',
      );
    }

    if (!_allowedCharacters.hasMatch(normalized)) {
      throw const FormatException(
        'Idempotency key contains invalid characters.',
      );
    }

    return normalized;
  }

  @override
  bool operator ==(Object other) {
    return other is IdempotencyKey && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'IdempotencyKey(redacted)';
}
