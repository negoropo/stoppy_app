import 'package:stoppy_app/core/backend/json_reader.dart';

class AuthRequestDto {
  const AuthRequestDto({
    required this.username,
    required this.password,
  });

  final String username;
  final String password;

  factory AuthRequestDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'AuthRequestDto',
    );

    return AuthRequestDto(
      username: reader.requiredString('username').trim(),
      password: reader.requiredString('password'),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'username': username.trim(),
      'password': password,
    };
  }
}