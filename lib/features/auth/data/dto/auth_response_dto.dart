import 'package:stoppy_app/core/backend/json_reader.dart';

import 'auth_session_dto.dart';
import 'player_profile_dto.dart';

class AuthResponseDto {
  const AuthResponseDto({required this.playerProfile, required this.session});

  final PlayerProfileDto playerProfile;
  final AuthSessionDto session;

  factory AuthResponseDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(json, context: 'AuthResponseDto');
    return AuthResponseDto(
      playerProfile: PlayerProfileDto.fromJson(
        reader.requiredObject('playerProfile').toMap(),
      ),
      session: AuthSessionDto.fromJson(
        reader.requiredObject('session').toMap(),
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'playerProfile': playerProfile.toJson(),
      'session': session.toJson(),
    };
  }
}
