import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/auth_session.dart';
import 'package:stoppy_app/core/backend/domain_mapper.dart';
import 'package:stoppy_app/core/backend/json_reader.dart';

class AuthSessionDto {
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

    final accessToken = reader.requiredString('accessToken').trim();
    final refreshToken = reader.optionalString('refreshToken')?.trim();

    if (accessToken.isEmpty) {
      throw const ApiException(
        ApiError(
          code: ApiErrorCode.malformedPayload,
          message: 'Authentication session access token must not be empty.',
        ),
      );
    }

    if (refreshToken != null && refreshToken.isEmpty) {
      throw const ApiException(
        ApiError(
          code: ApiErrorCode.malformedPayload,
          message:
          'Authentication session refresh token must not be empty when provided.',
        ),
      );
    }

    return AuthSessionDto(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: reader.requiredDateTime('expiresAt'),
    );
  }

  factory AuthSessionDto.fromDomain(AuthSession session) {
    return AuthSessionDto(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      expiresAt: session.expiresAt,
    );
  }

  AuthSession toDomain() {
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'accessToken': accessToken,
      if (refreshToken != null) 'refreshToken': refreshToken,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }
}

class AuthSessionMapper extends DomainMapper<AuthSession, AuthSessionDto> {
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