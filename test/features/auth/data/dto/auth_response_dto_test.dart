import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/features/auth/data/dto/auth_response_dto.dart';

void main() {
group('AuthResponseDto.fromJson', () {
test('parses a valid authentication response', () {
final dto = AuthResponseDto.fromJson(
_validAuthPayload(),
);

expect(dto.playerProfile.id, 'player-1');
expect(dto.playerProfile.username, 'Tester');

expect(dto.session.accessToken, 'access-token');
expect(dto.session.refreshToken, 'refresh-token');
expect(
dto.session.expiresAt,
DateTime.utc(2026, 6, 24, 12),
);
expect(dto.session.expiresAt.isUtc, isTrue);
});

test('normalizes session tokens', () {
final payload = _validAuthPayload();

payload['session'] = {
'accessToken': ' access-token ',
'refreshToken': ' refresh-token ',
'expiresAt': '2026-06-24T12:00:00.000Z',
};

final dto = AuthResponseDto.fromJson(payload);

expect(dto.session.accessToken, 'access-token');
expect(dto.session.refreshToken, 'refresh-token');
});

test('accepts a session without a refresh token', () {
final payload = _validAuthPayload();

payload['session'] = {
'accessToken': 'access-token',
'expiresAt': '2026-06-24T12:00:00.000Z',
};

final dto = AuthResponseDto.fromJson(payload);

expect(dto.session.accessToken, 'access-token');
expect(dto.session.refreshToken, isNull);
});

test('rejects a missing player profile', () {
final payload = _validAuthPayload()
..remove('playerProfile');

expect(
() => AuthResponseDto.fromJson(payload),
throwsA(isA<ApiException>()),
);
});

test('rejects a missing session', () {
final payload = _validAuthPayload()
..remove('session');

expect(
() => AuthResponseDto.fromJson(payload),
throwsA(isA<ApiException>()),
);
});

test('rejects a non-object player profile', () {
final payload = _validAuthPayload();

payload['playerProfile'] = 'invalid-profile';

expect(
() => AuthResponseDto.fromJson(payload),
throwsA(isA<ApiException>()),
);
});

test('rejects a non-object session', () {
final payload = _validAuthPayload();

payload['session'] = 'invalid-session';

expect(
() => AuthResponseDto.fromJson(payload),
throwsA(isA<ApiException>()),
);
});

test('rejects a malformed player profile', () {
final payload = _validAuthPayload();

payload['playerProfile'] = {
'id': 'player-1',
};

expect(
() => AuthResponseDto.fromJson(payload),
throwsA(isA<ApiException>()),
);
});

test('rejects a session with a blank access token', () {
final payload = _validAuthPayload();

payload['session'] = {
'accessToken': '   ',
'refreshToken': 'refresh-token',
'expiresAt': '2026-06-24T12:00:00.000Z',
};

expect(
() => AuthResponseDto.fromJson(payload),
throwsA(
isA<ApiException>().having(
(exception) => exception.error.code,
'error code',
ApiErrorCode.malformedPayload,
),
),
);
});

test('rejects a session with a blank refresh token', () {
final payload = _validAuthPayload();

payload['session'] = {
'accessToken': 'access-token',
'refreshToken': '   ',
'expiresAt': '2026-06-24T12:00:00.000Z',
};

expect(
() => AuthResponseDto.fromJson(payload),
throwsA(
isA<ApiException>().having(
(exception) => exception.error.code,
'error code',
ApiErrorCode.malformedPayload,
),
),
);
});

test('rejects a session with an invalid expiration', () {
final payload = _validAuthPayload();

payload['session'] = {
'accessToken': 'access-token',
'refreshToken': 'refresh-token',
'expiresAt': 'invalid-date',
};

expect(
() => AuthResponseDto.fromJson(payload),
throwsA(isA<ApiException>()),
);
});

test('rejects a non-object authentication response', () {
expect(
() => AuthResponseDto.fromJson('invalid-response'),
throwsA(isA<ApiException>()),
);
});
});

group('AuthResponseDto.toJson', () {
test('serializes a complete authentication response', () {
final dto = AuthResponseDto.fromJson(
_validAuthPayload(),
);

final json = dto.toJson();

expect(json.keys, containsAll(<String>[
'playerProfile',
'session',
]));

expect(json['playerProfile'], isA<Map<String, Object?>>());
expect(json['session'], isA<Map<String, Object?>>());

final playerProfile =
json['playerProfile']! as Map<String, Object?>;
final session = json['session']! as Map<String, Object?>;

expect(playerProfile['id'], 'player-1');
expect(playerProfile['username'], 'Tester');

expect(session['accessToken'], 'access-token');
expect(session['refreshToken'], 'refresh-token');
expect(
session['expiresAt'],
'2026-06-24T12:00:00.000Z',
);
});

test('omits refresh token when unavailable', () {
final payload = _validAuthPayload();

payload['session'] = {
'accessToken': 'access-token',
'expiresAt': '2026-06-24T12:00:00.000Z',
};

final dto = AuthResponseDto.fromJson(payload);
final json = dto.toJson();

final session = json['session']! as Map<String, Object?>;

expect(session['accessToken'], 'access-token');
expect(session.containsKey('refreshToken'), isFalse);
});
});

group('AuthResponseDto round trip', () {
test('preserves profile and session data through JSON', () {
final original = AuthResponseDto.fromJson(
_validAuthPayload(),
);

final restored = AuthResponseDto.fromJson(
original.toJson(),
);

expect(
restored.playerProfile.id,
original.playerProfile.id,
);
expect(
restored.playerProfile.username,
original.playerProfile.username,
);
expect(
restored.session.accessToken,
original.session.accessToken,
);
expect(
restored.session.refreshToken,
original.session.refreshToken,
);
expect(
restored.session.expiresAt,
original.session.expiresAt,
);
});
});
}

Map<String, Object?> _validAuthPayload() {
return {
'playerProfile': {
'id': 'player-1',
'username': 'Tester',
'createdAt': '2026-06-20T12:00:00.000Z',
'gamePoints': 5,
'adsRemoved': false,
'hasWeeklyLeagueEntry': false,
'reservedLeagueSlot': false,
},
'session': {
'accessToken': 'access-token',
'refreshToken': 'refresh-token',
'expiresAt': '2026-06-24T12:00:00.000Z',
},
};
}