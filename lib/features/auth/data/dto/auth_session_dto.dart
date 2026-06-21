import 'package:stoppy_app/core/backend/auth_session.dart';
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
    final reader = JsonReader.fromObject(json, context: 'AuthSessionDto');
    return AuthSessionDto(
      accessToken: reader.requiredString('accessToken'),
      refreshToken: reader.optionalString('refreshToken'),
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
      'refreshToken': refreshToken,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }
}
