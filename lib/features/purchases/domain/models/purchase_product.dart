import 'purchase_product_type.dart';

class PurchaseProduct {
  const PurchaseProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.displayPrice,
    this.gamePointsAmount = 0,
  }) : assert(
  type != PurchaseProductType.gamePointPack || gamePointsAmount > 0,
  'GamePointPack must have a positive gamePointsAmount',
  ),
        assert(
        type != PurchaseProductType.removeAds || gamePointsAmount == 0,
        'RemoveAds should not have gamePointsAmount',
        );

  final String id;
  final String title;
  final String description;
  final PurchaseProductType type;
  final String displayPrice;
  final int gamePointsAmount;
}