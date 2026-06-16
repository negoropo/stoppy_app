import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/config/app_environment.dart';
import 'package:stoppy_app/core/repositories/repository_factory.dart';
import 'package:stoppy_app/features/ads/data/mock_ad_repository.dart';
import 'package:stoppy_app/features/auth/data/backend/backend_auth_repository.dart';
import 'package:stoppy_app/features/auth/data/mock_auth_repository.dart';
import 'package:stoppy_app/features/knockout/data/backend/backend_knockout_repository.dart';
import 'package:stoppy_app/features/knockout/data/mock_knockout_repository.dart';
import 'package:stoppy_app/features/league/data/backend/backend_league_repository.dart';
import 'package:stoppy_app/features/league/data/mock_league_repository.dart';
import 'package:stoppy_app/features/purchases/data/mock_purchase_repository.dart';

void main() {
  group('RepositoryFactory', () {
    test('uses mock repositories by default runtime', () {
      final repositories = const RepositoryFactory(
        environment: AppEnvironment.mock(),
      ).createRepositories();

      expect(repositories.authRepository, isA<MockAuthRepository>());
      expect(repositories.purchaseRepository, isA<MockPurchaseRepository>());
      expect(repositories.adRepository, isA<MockAdRepository>());
      expect(repositories.leagueRepository, isA<MockLeagueRepository>());
      expect(repositories.knockoutRepository, isA<MockKnockoutRepository>());
    });

    test('uses backend skeletons when backend runtime is selected', () {
      final repositories = const RepositoryFactory(
        environment: AppEnvironment.backend(apiBaseUrl: 'https://api.test'),
      ).createRepositories();

      expect(repositories.authRepository, isA<BackendAuthRepository>());
      expect(repositories.purchaseRepository, isA<MockPurchaseRepository>());
      expect(repositories.adRepository, isA<MockAdRepository>());
      expect(repositories.leagueRepository, isA<BackendLeagueRepository>());
      expect(repositories.knockoutRepository, isA<BackendKnockoutRepository>());
    });
  });
}
