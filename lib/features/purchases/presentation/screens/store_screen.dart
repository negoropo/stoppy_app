import 'package:flutter/material.dart';

import '../../../auth/domain/models/player_profile.dart';
import '../../domain/models/purchase_product.dart';
import '../../domain/repositories/purchase_repository.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({
    super.key,
    required this.playerProfile,
    required this.purchaseRepository,
    required this.onPlayerProfileUpdated,
  });

  final PlayerProfile playerProfile;
  final PurchaseRepository purchaseRepository;
  final ValueChanged<PlayerProfile> onPlayerProfileUpdated;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  late Future<List<PurchaseProduct>> _productsFuture;
  late PlayerProfile _playerProfile;
  String? _message;
  String? _purchasingProductId;

  @override
  void initState() {
    super.initState();
    _playerProfile = widget.playerProfile;
    _productsFuture = widget.purchaseRepository.loadProducts();
  }

  Future<void> _purchase(PurchaseProduct product) async {
    if (_purchasingProductId != null) {
      return;
    }

    setState(() {
      _purchasingProductId = product.id;
      _message = null;
    });

    final result = await widget.purchaseRepository.purchaseProduct(
      productId: product.id,
      playerProfile: _playerProfile,
    );

    if (!mounted) {
      return;
    }

    final updatedPlayerProfile = result.playerProfile;
    if (result.success && updatedPlayerProfile != null) {
      _playerProfile = updatedPlayerProfile;
      widget.onPlayerProfileUpdated(updatedPlayerProfile);
    }

    setState(() {
      _purchasingProductId = null;
      _message = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      appBar: AppBar(
        title: const Text('Store'),
        backgroundColor: const Color(0xFF101418),
        foregroundColor: const Color(0xFFD6DEE8),
      ),
      body: SafeArea(
        child: FutureBuilder<List<PurchaseProduct>>(
          future: _productsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            final products = snapshot.data ?? const <PurchaseProduct>[];

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StoreProfileSummary(playerProfile: _playerProfile),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFFD166),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ...products.map(
                  (product) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _StoreProductTile(
                      product: product,
                      isPurchasing: _purchasingProductId == product.id,
                      onPurchase: () => _purchase(product),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StoreProfileSummary extends StatelessWidget {
  const _StoreProfileSummary({required this.playerProfile});

  final PlayerProfile playerProfile;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xEE101418),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3A424C)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Color(0xFFD6DEE8),
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Player: ${playerProfile.username}'),
              const SizedBox(height: 4),
              Text('GP: ${playerProfile.gamePoints}'),
              const SizedBox(height: 4),
              Text('Ads removed: ${playerProfile.adsRemoved ? 'Yes' : 'No'}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreProductTile extends StatelessWidget {
  const _StoreProductTile({
    required this.product,
    required this.isPurchasing,
    required this.onPurchase,
  });

  final PurchaseProduct product;
  final bool isPurchasing;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xEE101418),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD166)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              product.title,
              style: const TextStyle(
                color: Color(0xFFFFD166),
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              product.description,
              style: const TextStyle(
                color: Color(0xFFD6DEE8),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: isPurchasing ? null : onPurchase,
              child: isPurchasing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Buy - ${product.displayPrice}'),
            ),
          ],
        ),
      ),
    );
  }
}
