import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/features/auth/data/dto/auth_request_dto.dart';
import 'package:stoppy_app/features/auth/data/dto/auth_response_dto.dart';
import 'package:stoppy_app/features/auth/data/dto/auth_session_dto.dart';
import 'package:stoppy_app/features/auth/data/dto/player_profile_dto.dart';

void main() {
  test('auth request DTO round-trips explicit credentials schema', () {
    const request = AuthRequestDto(username: 'Tester', password: 'secret');

    expect(
      AuthRequestDto.fromJson(request.toJson()).toJson(),
      request.toJson(),
    );
  });

  test('auth response DTO serializes profile and JWT session', () {
    final profile = PlayerProfileDto.fromJson({
      'id': 'player-1',
      'username': 'Tester',
      'createdAt': '2026-06-21T10:00:00.000Z',
      'gamePoints': 5,
      'adsRemoved': false,
      'hasWeeklyLeagueEntry': false,
      'reservedLeagueSlot': false,
    });
    final response = AuthResponseDto(
      playerProfile: profile,
      session: AuthSessionDto(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.utc(2026, 6, 21, 11),
      ),
    );

    final decoded = AuthResponseDto.fromJson(response.toJson());

    expect(decoded.playerProfile.id, 'player-1');
    expect(decoded.session.accessToken, 'access-token');
    expect(decoded.session.toDomain().refreshToken, 'refresh-token');
  });

  test('auth session DTO rejects malformed JWT payloads', () {
    expect(
      () => AuthSessionDto.fromJson({
        'accessToken': '',
        'expiresAt': 'not-a-date',
      }),
      throwsA(
        isA<ApiException>().having(
          (exception) => exception.error.code,
          'code',
          ApiErrorCode.malformedPayload,
        ),
      ),
    );
  });
}
