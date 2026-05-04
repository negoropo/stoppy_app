import '../../../auth/domain/models/player_profile.dart';
import '../models/purchase_product.dart';
import '../models/purchase_result.dart';

abstract class PurchaseRepository {
  Future<List<PurchaseProduct>> loadProducts();

  Future<PurchaseResult> purchaseProduct({
    required String productId,
    required PlayerProfile playerProfile,
  });
}
