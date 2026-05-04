import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/game/domain/economy/warmup_availability_policy.dart';

void main() {
  group('WarmupAvailabilityPolicy', () {
    const policy = WarmupAvailabilityPolicy();

    PlayerProfile playerWithGp(int gamePoints) {
      return PlayerProfile(
        id: 'player-id',
        username: 'Tester',
        createdAt: DateTime(2026),
        gamePoints: gamePoints,
      );
    }

    test('warmup is available at onboarding with 5 GP', () {
      expect(policy.isWarmupAvailable(playerWithGp(5)), isTrue);
    });

    test('warmup is available when GP is below 10', () {
      expect(policy.isWarmupAvailable(playerWithGp(9)), isTrue);
    });

    test('warmup is not available when GP is 10 or higher', () {
      expect(policy.isWarmupAvailable(playerWithGp(10)), isFalse);
    });
  });
}
