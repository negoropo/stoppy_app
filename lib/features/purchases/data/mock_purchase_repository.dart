import '../../auth/domain/models/player_profile.dart';
import '../domain/models/purchase_product.dart';
import '../domain/models/purchase_product_type.dart';
import '../domain/models/purchase_result.dart';
import '../domain/repositories/purchase_repository.dart';

class MockPurchaseRepository implements PurchaseRepository {
  const MockPurchaseRepository();

  static const String smallGpPackId = 'mock_gp_pack_small';
  static const String largeGpPackId = 'mock_gp_pack_large';
  static const String removeAdsId = 'mock_remove_ads';

  static const List<PurchaseProduct> _products = [
    PurchaseProduct(
      id: smallGpPackId,
      title: 'Small GP Pack',
      description: 'Adds 10 Game Points.',
      type: PurchaseProductType.gamePointPack,
      displayPrice: r'Mock $0.99',
      gamePointsAmount: 10,
    ),
    PurchaseProduct(
      id: largeGpPackId,
      title: 'Large GP Pack',
      description: 'Adds 25 Game Points.',
      type: PurchaseProductType.gamePointPack,
      displayPrice: r'Mock $1.99',
      gamePointsAmount: 25,
    ),
    PurchaseProduct(
      id: removeAdsId,
      title: 'Remove Ads',
      description: 'Disables ads for this player profile.',
      type: PurchaseProductType.removeAds,
      displayPrice: r'Mock $2.99',
    ),
  ];

  @override
  Future<List<PurchaseProduct>> loadProducts() async {
    return List.unmodifiable(_products);
  }

  @override
  Future<PurchaseResult> purchaseProduct({
    required String productId,
    required PlayerProfile playerProfile,
  }) async {
    final product = _productForId(productId);
    if (product == null) {
      return const PurchaseResult.failure(
        error: PurchaseError.productNotFound,
        message: 'Product is not available.',
      );
    }

    return switch (product.type) {
      PurchaseProductType.gamePointPack => _purchaseGamePointPack(
        product: product,
        playerProfile: playerProfile,
      ),
      PurchaseProductType.removeAds => _purchaseRemoveAds(
        product: product,
        playerProfile: playerProfile,
      ),
    };
  }

  PurchaseResult _purchaseGamePointPack({
    required PurchaseProduct product,
    required PlayerProfile playerProfile,
  }) {
    // Mock GP purchases only produce a new profile snapshot. Real IAP should
    // validate the receipt server-side before applying this same profile delta.
    final updatedPlayerProfile = playerProfile.copyWith(
      gamePoints: playerProfile.gamePoints + product.gamePointsAmount,
    );

    return PurchaseResult.success(
      product: product,
      playerProfile: updatedPlayerProfile,
      message: '${product.gamePointsAmount} GP added.',
    );
  }

  PurchaseResult _purchaseRemoveAds({
    required PurchaseProduct product,
    required PlayerProfile playerProfile,
  }) {
    if (playerProfile.adsRemoved) {
      return const PurchaseResult.failure(
        error: PurchaseError.alreadyOwned,
        message: 'Ads have already been removed.',
      );
    }

    final updatedPlayerProfile = playerProfile.copyWith(adsRemoved: true);

    return PurchaseResult.success(
      product: product,
      playerProfile: updatedPlayerProfile,
      message: 'Ads removed.',
    );
  }

  PurchaseProduct? _productForId(String productId) {
    for (final product in _products) {
      if (product.id == productId) {
        return product;
      }
    }

    return null;
  }
}
