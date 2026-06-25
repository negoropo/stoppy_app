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

class StoppyApp extends StatefulWidget {
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
  State<StoppyApp> createState() => _StoppyAppState();
}

class _StoppyAppState extends State<StoppyApp> {
  late AppRepositories _resolvedRepositories;

  @override
  void initState() {
    super.initState();
    _resolvedRepositories = _createRepositories();
  }

  @override
  void didUpdateWidget(covariant StoppyApp oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.repositories, widget.repositories) ||
        oldWidget.environment != widget.environment) {
      _resolvedRepositories = _createRepositories();
    }
  }

  AppRepositories _createRepositories() {
    return widget.repositories ??
        RepositoryFactory(
          environment: widget.environment ?? AppEnvironment.fromDartDefines(),
        ).createRepositories();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stoppy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: AuthGate(
        authRepository:
            widget.authRepository ?? _resolvedRepositories.authRepository,
        purchaseRepository:
            widget.purchaseRepository ??
            _resolvedRepositories.purchaseRepository,
        adRepository: widget.adRepository ?? _resolvedRepositories.adRepository,
        leagueRepository:
            widget.leagueRepository ?? _resolvedRepositories.leagueRepository,
        knockoutRepository:
            widget.knockoutRepository ??
            _resolvedRepositories.knockoutRepository,
      ),
    );
  }
}
