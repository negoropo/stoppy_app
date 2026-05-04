import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/purchases/data/mock_purchase_repository.dart';

void main() {
  group('MockPurchaseRepository', () {
    const repository = MockPurchaseRepository();

    PlayerProfile playerProfile({int gamePoints = 5, bool adsRemoved = false}) {
      return PlayerProfile(
        id: 'player-id',
        username: 'Tester',
        createdAt: DateTime(2026),
        gamePoints: gamePoints,
        adsRemoved: adsRemoved,
      );
    }

    test('loads fake products', () async {
      final products = await repository.loadProducts();

      expect(products, hasLength(3));
      expect(
        products.map((product) => product.id),
        containsAll([
          MockPurchaseRepository.smallGpPackId,
          MockPurchaseRepository.largeGpPackId,
          MockPurchaseRepository.removeAdsId,
        ]),
      );
    });

    test('buying small GP pack increases player GP by 10', () async {
      final result = await repository.purchaseProduct(
        productId: MockPurchaseRepository.smallGpPackId,
        playerProfile: playerProfile(gamePoints: 5),
      );

      expect(result.success, isTrue);
      expect(result.playerProfile?.gamePoints, 15);
      expect(result.message, '10 GP added.');
    });

    test('buying large GP pack increases player GP by 25', () async {
      final result = await repository.purchaseProduct(
        productId: MockPurchaseRepository.largeGpPackId,
        playerProfile: playerProfile(gamePoints: 5),
      );

      expect(result.success, isTrue);
      expect(result.playerProfile?.gamePoints, 30);
      expect(result.message, '25 GP added.');
    });

    test('buying remove ads sets adsRemoved to true', () async {
      final result = await repository.purchaseProduct(
        productId: MockPurchaseRepository.removeAdsId,
        playerProfile: playerProfile(),
      );

      expect(result.success, isTrue);
      expect(result.playerProfile?.adsRemoved, isTrue);
      expect(result.message, 'Ads removed.');
    });

    test('buying remove ads twice returns a meaningful error', () async {
      final result = await repository.purchaseProduct(
        productId: MockPurchaseRepository.removeAdsId,
        playerProfile: playerProfile(adsRemoved: true),
      );

      expect(result.success, isFalse);
      expect(result.playerProfile, isNull);
      expect(result.message, 'Ads have already been removed.');
    });

    test('unknown product returns a meaningful error', () async {
      final result = await repository.purchaseProduct(
        productId: 'missing-product',
        playerProfile: playerProfile(),
      );

      expect(result.success, isFalse);
      expect(result.message, 'Product is not available.');
    });
  });
}
