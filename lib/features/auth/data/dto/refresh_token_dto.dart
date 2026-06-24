import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/auth_session.dart';
import 'package:stoppy_app/core/backend/json_reader.dart';

import 'auth_session_dto.dart';

/// Request payload used to exchange a refresh credential for a new session.
final class RefreshTokenRequestDto {
const RefreshTokenRequestDto({
required this.refreshToken,
});

final String refreshToken;

Map<String, Object?> toJson() {
return {
'refreshToken': _validatedToken(
refreshToken,
fieldName: 'Refresh token',
),
};
}

static String _validatedToken(
String value, {
required String fieldName,
}) {
final normalized = value.trim();

if (normalized.isEmpty) {
throw ApiException(
ApiError(
code: ApiErrorCode.malformedPayload,
message: '$fieldName must not be blank.',
),
);
}

return normalized;
}
}

/// Response payload returned after a successful refresh operation.
///
/// The backend may omit a rotated refresh token. When that happens, the
/// previously valid refresh credential remains authoritative.
final class RefreshTokenResponseDto {
const RefreshTokenResponseDto({
required this.session,
});

final AuthSessionDto session;

factory RefreshTokenResponseDto.fromJson(Object? json) {
final reader = JsonReader.fromObject(
json,
context: 'RefreshTokenResponseDto',
);

return RefreshTokenResponseDto(
session: AuthSessionDto.fromJson(
reader.requiredObject('session').toMap(),
),
);
}

Map<String, Object?> toJson() {
return {
'session': session.toJson(),
};
}

AuthSession toDomain({
required String previousRefreshToken,
}) {
final previousToken = previousRefreshToken.trim();

if (previousToken.isEmpty) {
throw const ApiException(
ApiError(
code: ApiErrorCode.malformedPayload,
message: 'Previous refresh token must not be blank.',
),
);
}

final decodedSession = session.toDomain();
final rotatedRefreshToken = decodedSession.refreshToken?.trim();

// An omitted token means that the backend did not rotate the refresh
// credential. A present but blank token must already have been rejected by
// AuthSessionDto and is also defended against here.
if (rotatedRefreshToken != null && rotatedRefreshToken.isEmpty) {
throw const ApiException(
ApiError(
code: ApiErrorCode.malformedPayload,
message: 'Refresh response contained an invalid refresh token.',
),
);
}

return decodedSession.copyWith(
refreshToken: rotatedRefreshToken ?? previousToken,
);
}
}