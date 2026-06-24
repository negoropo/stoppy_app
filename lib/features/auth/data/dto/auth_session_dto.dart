import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/auth_session.dart';
import 'package:stoppy_app/core/backend/domain_mapper.dart';
import 'package:stoppy_app/core/backend/json_reader.dart';

final class AuthSessionDto {
const AuthSessionDto({
required this.accessToken,
this.refreshToken,
required this.expiresAt,
});

final String accessToken;
final String? refreshToken;
final DateTime expiresAt;

factory AuthSessionDto.fromJson(Object? json) {
final reader = JsonReader.fromObject(
json,
context: 'AuthSessionDto',
);

return AuthSessionDto(
accessToken: _requiredAccessToken(
reader.requiredString('accessToken'),
),
refreshToken: _optionalRefreshToken(
reader.optionalString('refreshToken'),
),
expiresAt: reader.requiredDateTime('expiresAt').toUtc(),
);
}

factory AuthSessionDto.fromDomain(AuthSession session) {
return AuthSessionDto(
accessToken: _requiredAccessToken(session.accessToken),
refreshToken: _optionalRefreshToken(session.refreshToken),
expiresAt: session.expiresAt.toUtc(),
);
}

AuthSession toDomain() {
return AuthSession(
accessToken: _requiredAccessToken(accessToken),
refreshToken: _optionalRefreshToken(refreshToken),
expiresAt: expiresAt.toUtc(),
);
}

Map<String, Object?> toJson() {
final normalizedAccessToken = _requiredAccessToken(accessToken);
final normalizedRefreshToken = _optionalRefreshToken(refreshToken);

return {
'accessToken': normalizedAccessToken,
'refreshToken': ?normalizedRefreshToken,
'expiresAt': expiresAt.toUtc().toIso8601String(),
};
}

static String _requiredAccessToken(String value) {
final normalized = value.trim();

if (normalized.isEmpty) {
throw const ApiException(
ApiError(
code: ApiErrorCode.malformedPayload,
message:
'Authentication session access token must not be empty.',
),
);
}

return normalized;
}

static String? _optionalRefreshToken(String? value) {
if (value == null) {
return null;
}

final normalized = value.trim();

if (normalized.isEmpty) {
throw const ApiException(
ApiError(
code: ApiErrorCode.malformedPayload,
message:
'Authentication session refresh token must not be empty '
'when provided.',
),
);
}

return normalized;
}
}

final class AuthSessionMapper
extends DomainMapper<AuthSession, AuthSessionDto> {
const AuthSessionMapper();

@override
AuthSessionDto toDto(AuthSession domain) {
return AuthSessionDto.fromDomain(domain);
}

@override
AuthSession toDomain(AuthSessionDto dto) {
return dto.toDomain();
}
}