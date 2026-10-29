import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';

PlayerProfile profileWith(int gamePoints) => PlayerProfile(
  id: 'player-id',
  username: 'Tester',
  createdAt: DateTime.utc(2026),
  gamePoints: gamePoints,
);

void main() {
  for (final balance in [999999, 1000000, 2147483647]) {
    test(
      'copyWith preserves $balance GP when omitted or unrelated fields change',
      () {
        final original = profileWith(balance);
        expect(original.copyWith().gamePoints, balance);
        final updated = original.copyWith(
          username: 'Updated',
          adsRemoved: true,
        );
        expect(updated.gamePoints, balance);
        expect(updated.username, 'Updated');
        expect(updated.adsRemoved, isTrue);
        expect(original.username, 'Tester');
        expect(original.gamePoints, balance);
      },
    );
  }

  test(
    'copyWith explicitly replaces GP with high valid authoritative amounts',
    () {
      final original = profileWith(5);
      expect(original.copyWith(gamePoints: 1000000).gamePoints, 1000000);
      expect(original.copyWith(gamePoints: 2147483647).gamePoints, 2147483647);
      expect(
        profileWith(2147483647).copyWith(gamePoints: 1000001).gamePoints,
        1000001,
      );
    },
  );

  test('copyWith retains negative-to-zero handling and ordinary balances', () {
    expect(profileWith(5).copyWith(gamePoints: -1).gamePoints, 0);
    expect(profileWith(-1).copyWith().gamePoints, 0);
    for (final balance in [0, 5, 10, 75]) {
      expect(profileWith(5).copyWith(gamePoints: balance).gamePoints, balance);
    }
  });
}
