import 'package:flutter/material.dart';
import 'core/config/app_environment.dart';
import 'core/repositories/app_repositories.dart';
import 'core/repositories/repository_factory.dart';
import 'features/ads/domain/repositories/ad_repository.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/knockout/domain/repositories/knockout_repository.dart';
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
    this.knockoutRepository,
    this.environment,
    this.repositories,
  }) : assert(
         repositories == null ||
             (authRepository == null &&
                 purchaseRepository == null &&
                 adRepository == null &&
                 leagueRepository == null &&
                 knockoutRepository == null),
         'Use either repositories bundle or individual repositories, not both.',
       );

  final AuthRepository? authRepository;
  final PurchaseRepository? purchaseRepository;
  final AdRepository? adRepository;
  final LeagueRepository? leagueRepository;
  final KnockoutRepository? knockoutRepository;
  final AppEnvironment? environment;
  final AppRepositories? repositories;

  @override
  Widget build(BuildContext context) {
    final resolvedRepositories =
        repositories ??
        RepositoryFactory(
          environment: environment ?? AppEnvironment.fromDartDefines(),
        ).createRepositories();

    return MaterialApp(
      title: 'Stoppy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: AuthGate(
        authRepository: authRepository ?? resolvedRepositories.authRepository,
        purchaseRepository:
            purchaseRepository ?? resolvedRepositories.purchaseRepository,
        adRepository: adRepository ?? resolvedRepositories.adRepository,
        leagueRepository:
            leagueRepository ?? resolvedRepositories.leagueRepository,
        knockoutRepository:
            knockoutRepository ?? resolvedRepositories.knockoutRepository,
      ),
    );
  }
}
