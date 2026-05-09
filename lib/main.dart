import 'package:flutter/material.dart';
import 'features/ads/domain/repositories/ad_repository.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/league/domain/repositories/league_repository.dart';
import 'features/purchases/domain/repositories/purchase_repository.dart';

void main() {
  runApp(const StoppyApp());
}

class StoppyApp extends StatelessWidget {
  const StoppyApp({
    super.key,
    this.authRepository,
    this.purchaseRepository,
    this.adRepository,
    this.leagueRepository,
  });

  final AuthRepository? authRepository;
  final PurchaseRepository? purchaseRepository;
  final AdRepository? adRepository;
  final LeagueRepository? leagueRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stoppy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: AuthGate(
        authRepository: authRepository,
        purchaseRepository: purchaseRepository,
        adRepository: adRepository,
        leagueRepository: leagueRepository,
      ),
    );
  }
}
