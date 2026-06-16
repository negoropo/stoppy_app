import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/auth/data/dto/player_profile_dto.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';

void main() {
  test('PlayerProfileDto round-trips domain profile JSON', () {
    final profile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026, 6, 3, 12),
      gamePoints: 42,
      lastDailyGpAwardedAt: DateTime(2026, 6, 3),
      adsRemoved: true,
      currentLeagueDivision: 2,
      hasWeeklyLeagueEntry: true,
      reservedLeagueSlot: true,
    );

    final dto = PlayerProfileDto.fromDomain(profile);
    final decoded = PlayerProfileDto.fromJson(dto.toJson()).toDomain();
    final mapperDecoded = const PlayerProfileMapper().toDomain(
      const PlayerProfileMapper().toDto(profile),
    );

    expect(decoded.toJson(), profile.toJson());
    expect(mapperDecoded.toJson(), profile.toJson());
  });
}
