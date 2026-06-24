import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/features/auth/data/dto/auth_request_dto.dart';
import 'package:stoppy_app/features/auth/data/dto/auth_response_dto.dart';
import 'package:stoppy_app/features/auth/data/dto/auth_session_dto.dart';
import 'package:stoppy_app/features/auth/data/dto/player_profile_dto.dart';

void main() {
  group('AuthRequestDto', () {
    test('round-trips the explicit credentials schema', () {
      const request = AuthRequestDto(username: 'Tester', password: 'secret');

      expect(
        AuthRequestDto.fromJson(request.toJson()).toJson(),
        request.toJson(),
      );
    });

    test('normalizes username without altering password', () {
      final request = AuthRequestDto.fromJson({
        'username': '  Tester  ',
        'password': '  secret  ',
      });

      expect(request.username, 'Tester');
      expect(request.password, '  secret  ');

      expect(request.toJson(), {
        'username': 'Tester',
        'password': '  secret  ',
      });
    });

    test('rejects empty username or password fields', () {
      expect(
        () =>
            AuthRequestDto.fromJson({'username': '   ', 'password': 'secret'}),
        throwsA(isA<ApiException>()),
      );

      expect(
        () => AuthRequestDto.fromJson({'username': 'Tester', 'password': ''}),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('AuthSessionDto', () {
    test('round-trips a JWT session', () {
      final dto = AuthSessionDto(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: DateTime.utc(2026, 6, 21, 11),
      );

      final decoded = AuthSessionDto.fromJson(dto.toJson());

      expect(decoded.accessToken, 'access-token');
      expect(decoded.refreshToken, 'refresh-token');
      expect(decoded.expiresAt, DateTime.utc(2026, 6, 21, 11));
    });

    test('rejects malformed JWT payloads', () {
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

    test('rejects blank access tokens', () {
      expect(
        () => AuthSessionDto.fromJson({
          'accessToken': '   ',
          'expiresAt': '2026-06-21T11:00:00.000Z',
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

    test('rejects an empty refresh token when provided', () {
      expect(
        () => AuthSessionDto.fromJson({
          'accessToken': 'access-token',
          'refreshToken': '   ',
          'expiresAt': '2026-06-21T11:00:00.000Z',
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

    test('omits refresh token from JSON when absent', () {
      final dto = AuthSessionDto(
        accessToken: 'access-token',
        expiresAt: DateTime.utc(2026, 6, 21, 11),
      );

      expect(dto.toJson().containsKey('refreshToken'), isFalse);
    });
  });

  group('PlayerProfileDto', () {
    test('maps profile payload and applies documented defaults', () {
      final profile = PlayerProfileDto.fromJson({
        'id': 'player-1',
        'username': 'Tester',
        'createdAt': '2026-06-21T10:00:00.000Z',
      });

      expect(profile.id, 'player-1');
      expect(profile.username, 'Tester');
      expect(profile.gamePoints, 5);
      expect(profile.adsRemoved, isFalse);
      expect(profile.currentLeagueDivision, isNull);
      expect(profile.hasWeeklyLeagueEntry, isFalse);
      expect(profile.reservedLeagueSlot, isFalse);
    });

    test('normalizes id and username', () {
      final profile = PlayerProfileDto.fromJson({
        'id': '  player-1  ',
        'username': '  Tester  ',
        'createdAt': '2026-06-21T10:00:00.000Z',
      });

      expect(profile.id, 'player-1');
      expect(profile.username, 'Tester');
    });

    test('rejects negative game points', () {
      expect(
        () => PlayerProfileDto.fromJson({
          'id': 'player-1',
          'username': 'Tester',
          'createdAt': '2026-06-21T10:00:00.000Z',
          'gamePoints': -1,
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

    test('rejects non-positive league divisions', () {
      expect(
        () => PlayerProfileDto.fromJson({
          'id': 'player-1',
          'username': 'Tester',
          'createdAt': '2026-06-21T10:00:00.000Z',
          'currentLeagueDivision': 0,
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

    test('copyWith can clear nullable fields', () {
      final profile = PlayerProfileDto.fromJson({
        'id': 'player-1',
        'username': 'Tester',
        'createdAt': '2026-06-21T10:00:00.000Z',
        'lastDailyGpAwardedAt': '2026-06-21T09:00:00.000Z',
        'currentLeagueDivision': 2,
      });

      final updated = profile.copyWith(
        lastDailyGpAwardedAt: null,
        currentLeagueDivision: null,
      );

      expect(updated.lastDailyGpAwardedAt, isNull);
      expect(updated.currentLeagueDivision, isNull);
    });

    test('copyWith preserves nullable fields when omitted', () {
      final awardedAt = DateTime.utc(2026, 6, 21, 9);

      final profile = PlayerProfileDto(
        id: 'player-1',
        username: 'Tester',
        createdAt: DateTime.utc(2026, 6, 21, 10),
        gamePoints: 5,
        lastDailyGpAwardedAt: awardedAt,
        adsRemoved: false,
        currentLeagueDivision: 2,
        hasWeeklyLeagueEntry: false,
        reservedLeagueSlot: false,
      );

      final updated = profile.copyWith(gamePoints: 10);

      expect(updated.gamePoints, 10);
      expect(updated.lastDailyGpAwardedAt, awardedAt);
      expect(updated.currentLeagueDivision, 2);
    });
  });

  group('AuthResponseDto', () {
    test('serializes profile and JWT session', () {
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

    test('rejects missing player profile', () {
      expect(
        () => AuthResponseDto.fromJson({
          'session': {
            'accessToken': 'access-token',
            'expiresAt': '2026-06-21T11:00:00.000Z',
          },
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

    test('rejects missing session', () {
      expect(
        () => AuthResponseDto.fromJson({
          'playerProfile': {
            'id': 'player-1',
            'username': 'Tester',
            'createdAt': '2026-06-21T10:00:00.000Z',
          },
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
  });
}
