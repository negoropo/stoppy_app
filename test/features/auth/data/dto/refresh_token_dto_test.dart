import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/features/auth/data/dto/auth_session_dto.dart';
import 'package:stoppy_app/features/auth/data/dto/refresh_token_dto.dart';

void main() {
group('RefreshTokenRequestDto', () {
test('serializes a normalized refresh token', () {
const dto = RefreshTokenRequestDto(
refreshToken: ' refresh-token ',
);

expect(
dto.toJson(),
{
'refreshToken': 'refresh-token',
},
);
});

test('rejects a blank refresh token', () {
const dto = RefreshTokenRequestDto(
refreshToken: '   ',
);

expect(
dto.toJson,
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

group('RefreshTokenResponseDto.fromJson', () {
test('parses a valid refresh response', () {
final dto = RefreshTokenResponseDto.fromJson({
'session': {
'accessToken': ' new-access ',
'refreshToken': ' new-refresh ',
'expiresAt': '2030-01-01T00:00:00.000Z',
},
});

expect(dto.session.accessToken, 'new-access');
expect(dto.session.refreshToken, 'new-refresh');
expect(
dto.session.expiresAt,
DateTime.utc(2030, 1, 1),
);
expect(dto.session.expiresAt.isUtc, isTrue);
});

test('accepts an omitted rotated refresh token', () {
final dto = RefreshTokenResponseDto.fromJson({
'session': {
'accessToken': 'new-access',
'expiresAt': '2030-01-01T00:00:00.000Z',
},
});

expect(dto.session.accessToken, 'new-access');
expect(dto.session.refreshToken, isNull);
});

test('rejects a missing session object', () {
expect(
() => RefreshTokenResponseDto.fromJson(
const <String, Object?>{},
),
throwsA(isA<ApiException>()),
);
});

test('rejects a non-object session', () {
expect(
() => RefreshTokenResponseDto.fromJson({
'session': 'invalid-session',
}),
throwsA(isA<ApiException>()),
);
});

test('rejects a malformed response payload', () {
expect(
() => RefreshTokenResponseDto.fromJson(
const {
'session': {
'accessToken': '',
'expiresAt': 'invalid-date',
},
},
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

test('rejects a blank rotated refresh token', () {
expect(
() => RefreshTokenResponseDto.fromJson({
'session': {
'accessToken': 'new-access',
'refreshToken': '   ',
'expiresAt': '2030-01-01T00:00:00.000Z',
},
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
});

group('RefreshTokenResponseDto.toDomain', () {
test('preserves the previous refresh token when omitted', () {
final dto = RefreshTokenResponseDto(
session: AuthSessionDto(
accessToken: 'new-access',
expiresAt: DateTime.utc(2030, 1, 1),
),
);

final result = dto.toDomain(
previousRefreshToken: ' old-refresh ',
);

expect(result.accessToken, 'new-access');
expect(result.refreshToken, 'old-refresh');
expect(result.expiresAt, DateTime.utc(2030, 1, 1));
});

test('uses the rotated refresh token when returned', () {
final dto = RefreshTokenResponseDto(
session: AuthSessionDto(
accessToken: ' new-access ',
refreshToken: ' new-refresh ',
expiresAt: DateTime.utc(2030, 1, 1),
),
);

final result = dto.toDomain(
previousRefreshToken: 'old-refresh',
);

expect(result.accessToken, 'new-access');
expect(result.refreshToken, 'new-refresh');
expect(result.expiresAt, DateTime.utc(2030, 1, 1));
});

test('rejects a blank previous refresh token', () {
final dto = RefreshTokenResponseDto(
session: AuthSessionDto(
accessToken: 'new-access',
expiresAt: DateTime.utc(2030, 1, 1),
),
);

expect(
() => dto.toDomain(
previousRefreshToken: '   ',
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

test('rejects invalid manually constructed session tokens', () {
final blankAccessDto = RefreshTokenResponseDto(
session: AuthSessionDto(
accessToken: '   ',
expiresAt: DateTime.utc(2030, 1, 1),
),
);

final blankRefreshDto = RefreshTokenResponseDto(
session: AuthSessionDto(
accessToken: 'new-access',
refreshToken: '   ',
expiresAt: DateTime.utc(2030, 1, 1),
),
);

expect(
() => blankAccessDto.toDomain(
previousRefreshToken: 'old-refresh',
),
throwsA(isA<ApiException>()),
);

expect(
() => blankRefreshDto.toDomain(
previousRefreshToken: 'old-refresh',
),
throwsA(isA<ApiException>()),
);
});
});

group('RefreshTokenResponseDto.toJson', () {
test('serializes and deserializes a valid response', () {
final expiresAt = DateTime.utc(2030, 1, 1);

final dto = RefreshTokenResponseDto(
session: AuthSessionDto(
accessToken: ' new-access ',
refreshToken: ' new-refresh ',
expiresAt: expiresAt,
),
);

final json = dto.toJson();
final decoded = RefreshTokenResponseDto.fromJson(json);

expect(
json,
{
'session': {
'accessToken': 'new-access',
'refreshToken': 'new-refresh',
'expiresAt': '2030-01-01T00:00:00.000Z',
},
},
);

expect(decoded.session.accessToken, 'new-access');
expect(decoded.session.refreshToken, 'new-refresh');
expect(decoded.session.expiresAt, expiresAt);
});

test('omits the refresh token when unavailable', () {
final dto = RefreshTokenResponseDto(
session: AuthSessionDto(
accessToken: 'new-access',
expiresAt: DateTime.utc(2030, 1, 1),
),
);

final json = dto.toJson();
final session = json['session']! as Map<String, Object?>;

expect(session['accessToken'], 'new-access');
expect(session.containsKey('refreshToken'), isFalse);
expect(
session['expiresAt'],
'2030-01-01T00:00:00.000Z',
);
});
});
}