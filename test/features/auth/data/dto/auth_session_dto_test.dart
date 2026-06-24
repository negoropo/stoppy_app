import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/auth_session.dart';
import 'package:stoppy_app/features/auth/data/dto/auth_session_dto.dart';

void main() {
group('AuthSessionDto.fromJson', () {
test('parses and normalizes a valid session payload', () {
final dto = AuthSessionDto.fromJson({
'accessToken': ' access-token ',
'refreshToken': ' refresh-token ',
'expiresAt': '2026-06-24T14:00:00+02:00',
});

expect(dto.accessToken, 'access-token');
expect(dto.refreshToken, 'refresh-token');
expect(dto.expiresAt, DateTime.utc(2026, 6, 24, 12));
expect(dto.expiresAt.isUtc, isTrue);
});

test('accepts an omitted refresh token', () {
final dto = AuthSessionDto.fromJson({
'accessToken': 'access-token',
'expiresAt': '2026-06-24T12:00:00.000Z',
});

expect(dto.accessToken, 'access-token');
expect(dto.refreshToken, isNull);
expect(dto.expiresAt, DateTime.utc(2026, 6, 24, 12));
});

test('rejects a blank access token', () {
expect(
() => AuthSessionDto.fromJson({
'accessToken': '   ',
'expiresAt': '2026-06-24T12:00:00.000Z',
}),
throwsA(
isA<ApiException>().having(
(exception) => exception.error.code,
'error code',
ApiErrorCode.malformedPayload,
),
),
);
});

test('rejects a blank refresh token', () {
expect(
() => AuthSessionDto.fromJson({
'accessToken': 'access-token',
'refreshToken': '   ',
'expiresAt': '2026-06-24T12:00:00.000Z',
}),
throwsA(
isA<ApiException>().having(
(exception) => exception.error.code,
'error code',
ApiErrorCode.malformedPayload,
),
),
);
});

test('rejects an invalid expiration value', () {
expect(
() => AuthSessionDto.fromJson({
'accessToken': 'access-token',
'expiresAt': 'not-a-date',
}),
throwsA(isA<ApiException>()),
);
});

test('rejects a missing expiration value', () {
expect(
() => AuthSessionDto.fromJson({
'accessToken': 'access-token',
}),
throwsA(isA<ApiException>()),
);
});
});

group('AuthSessionDto.fromDomain', () {
test('normalizes tokens and expiration from the domain model', () {
final dto = AuthSessionDto.fromDomain(
AuthSession(
accessToken: ' access-token ',
refreshToken: ' refresh-token ',
expiresAt: DateTime.parse('2026-06-24T14:00:00+02:00'),
),
);

expect(dto.accessToken, 'access-token');
expect(dto.refreshToken, 'refresh-token');
expect(dto.expiresAt, DateTime.utc(2026, 6, 24, 12));
expect(dto.expiresAt.isUtc, isTrue);
});

test('rejects a domain session with a blank access token', () {
expect(
() => AuthSessionDto.fromDomain(
AuthSession(
accessToken: '   ',
expiresAt: DateTime.utc(2026, 6, 24, 12),
),
),
throwsA(
isA<ApiException>().having(
(exception) => exception.error.code,
'error code',
ApiErrorCode.malformedPayload,
),
),
);
});

test('rejects a domain session with a blank refresh token', () {
expect(
() => AuthSessionDto.fromDomain(
AuthSession(
accessToken: 'access-token',
refreshToken: '   ',
expiresAt: DateTime.utc(2026, 6, 24, 12),
),
),
throwsA(
isA<ApiException>().having(
(exception) => exception.error.code,
'error code',
ApiErrorCode.malformedPayload,
),
),
);
});
});

group('AuthSessionDto.toDomain', () {
test('creates a normalized domain session', () {
final dto = AuthSessionDto(
accessToken: ' access-token ',
refreshToken: ' refresh-token ',
expiresAt: DateTime.parse('2026-06-24T14:00:00+02:00'),
);

final session = dto.toDomain();

expect(session.accessToken, 'access-token');
expect(session.refreshToken, 'refresh-token');
expect(session.expiresAt, DateTime.utc(2026, 6, 24, 12));
expect(session.expiresAt.isUtc, isTrue);
});

test('preserves an omitted refresh token', () {
final dto = AuthSessionDto(
accessToken: 'access-token',
expiresAt: DateTime.utc(2026, 6, 24, 12),
);

final session = dto.toDomain();

expect(session.accessToken, 'access-token');
expect(session.refreshToken, isNull);
});

test('rejects a manually constructed DTO with a blank access token', () {
final dto = AuthSessionDto(
accessToken: '   ',
expiresAt: DateTime.utc(2026, 6, 24, 12),
);

expect(
dto.toDomain,
throwsA(
isA<ApiException>().having(
(exception) => exception.error.code,
'error code',
ApiErrorCode.malformedPayload,
),
),
);
});

test('rejects a manually constructed DTO with a blank refresh token', () {
final dto = AuthSessionDto(
accessToken: 'access-token',
refreshToken: '   ',
expiresAt: DateTime.utc(2026, 6, 24, 12),
);

expect(
dto.toDomain,
throwsA(
isA<ApiException>().having(
(exception) => exception.error.code,
'error code',
ApiErrorCode.malformedPayload,
),
),
);
});
});

group('AuthSessionDto.toJson', () {
test('serializes a normalized session payload', () {
final dto = AuthSessionDto(
accessToken: ' access-token ',
refreshToken: ' refresh-token ',
expiresAt: DateTime.parse('2026-06-24T14:00:00+02:00'),
);

expect(
dto.toJson(),
{
'accessToken': 'access-token',
'refreshToken': 'refresh-token',
'expiresAt': '2026-06-24T12:00:00.000Z',
},
);
});

test('omits refresh token when unavailable', () {
final dto = AuthSessionDto(
accessToken: 'access-token',
expiresAt: DateTime.utc(2026, 6, 24, 12),
);

final json = dto.toJson();

expect(json['accessToken'], 'access-token');
expect(json.containsKey('refreshToken'), isFalse);
expect(json['expiresAt'], '2026-06-24T12:00:00.000Z');
});

test('rejects a manually constructed DTO with invalid tokens', () {
final blankAccessTokenDto = AuthSessionDto(
accessToken: '   ',
expiresAt: DateTime.utc(2026, 6, 24, 12),
);

final blankRefreshTokenDto = AuthSessionDto(
accessToken: 'access-token',
refreshToken: '   ',
expiresAt: DateTime.utc(2026, 6, 24, 12),
);

expect(
blankAccessTokenDto.toJson,
throwsA(isA<ApiException>()),
);

expect(
blankRefreshTokenDto.toJson,
throwsA(isA<ApiException>()),
);
});
});

group('AuthSessionMapper', () {
test('maps between domain and DTO', () {
const mapper = AuthSessionMapper();

final domain = AuthSession(
accessToken: ' access-token ',
refreshToken: ' refresh-token ',
expiresAt: DateTime.parse('2026-06-24T14:00:00+02:00'),
);

final dto = mapper.toDto(domain);
final restored = mapper.toDomain(dto);

expect(dto.accessToken, 'access-token');
expect(dto.refreshToken, 'refresh-token');
expect(restored.accessToken, 'access-token');
expect(restored.refreshToken, 'refresh-token');
expect(restored.expiresAt, DateTime.utc(2026, 6, 24, 12));
});
});
}