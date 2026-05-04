import '../../../auth/domain/models/player_profile.dart';
import 'purchase_product.dart';

enum PurchaseError {
  productNotFound,
  alreadyOwned,
  unknown,
}

class PurchaseResult {
  const PurchaseResult._({
    required this.success,
    this.product,
    this.playerProfile,
    this.error,
    this.message,
  });

  const PurchaseResult.success({
    required PurchaseProduct product,
    required PlayerProfile playerProfile,
    String? message,
  }) : this._(
    success: true,
    product: product,
    playerProfile: playerProfile,
    message: message,
  );

  const PurchaseResult.failure({
    required PurchaseError error,
    String? message,
  }) : this._(
    success: false,
    error: error,
    message: message,
  );

  final bool success;
  final PurchaseProduct? product;
  final PlayerProfile? playerProfile;

  // Typed error (important for future IAP handling)
  final PurchaseError? error;

  // Optional UI message
  final String? message;
}