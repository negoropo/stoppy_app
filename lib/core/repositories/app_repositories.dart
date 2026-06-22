import '../../features/ads/domain/repositories/ad_repository.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/knockout/domain/repositories/knockout_repository.dart';
import '../../features/league/domain/repositories/league_repository.dart';
import '../../features/purchases/domain/repositories/purchase_repository.dart';

final class AppRepositories {
  const AppRepositories({
    required this.authRepository,
    required this.purchaseRepository,
    required this.adRepository,
    required this.leagueRepository,
    required this.knockoutRepository,
  });

  final AuthRepository authRepository;
  final PurchaseRepository purchaseRepository;
  final AdRepository adRepository;
  final LeagueRepository leagueRepository;
  final KnockoutRepository knockoutRepository;
}