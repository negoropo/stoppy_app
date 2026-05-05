import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/ads/data/mock_ad_repository.dart';
import 'package:stoppy_app/features/ads/domain/ad_controller.dart';
import 'package:stoppy_app/features/ads/domain/models/ad_type.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';

void main() {
  group('AdController', () {
    PlayerProfile playerProfile({bool adsRemoved = false}) {
      return PlayerProfile(
        id: 'player-id',
        username: 'Tester',
        createdAt: DateTime(2026),
        adsRemoved: adsRemoved,
      );
    }

    test('ads removed skips banners', () async {
      final repository = MockAdRepository();
      final controller = AdController(adRepository: repository);

      await controller.preloadBeforeRun(playerProfile(adsRemoved: true));

      expect(repository.preloadCounts[AdType.banner], 0);
    });

    test('ads removed skips interstitials', () async {
      final repository = MockAdRepository();
      final controller = AdController(adRepository: repository);

      await controller.preloadBeforeRun(playerProfile(adsRemoved: true));
      final result = await controller.showInterstitialOnExit(
        playerProfile(adsRemoved: true),
      );

      expect(result.shown, isFalse);
      expect(result.rewardGranted, isFalse);
      expect(repository.preloadCounts[AdType.interstitial], 0);
      expect(repository.showCounts[AdType.interstitial], 0);
    });

    test('ads removed does not skip rewarded ads', () async {
      final repository = MockAdRepository();
      final controller = AdController(adRepository: repository);

      await controller.preloadBeforeRun(playerProfile(adsRemoved: true));

      expect(repository.preloadCounts[AdType.rewarded], 1);
    });

    test(
      'rewarded extra life remains available when adsRemoved is true',
          () async {
        final repository = MockAdRepository();
        final controller = AdController(adRepository: repository);

        await controller.preloadBeforeRun(playerProfile(adsRemoved: true));
        final result = await controller.showRewardedExtraLife();

        expect(result.shown, isTrue);
        expect(result.rewardGranted, isTrue);
        expect(repository.showCounts[AdType.rewarded], 1);
      },
    );

    test('rewarded extra life grants reward signal', () async {
      final repository = MockAdRepository();
      final controller = AdController(adRepository: repository);

      await controller.preloadBeforeRun(playerProfile());
      final result = await controller.showRewardedExtraLife();

      expect(result.shown, isTrue);
      expect(result.rewardGranted, isTrue);
    });

    test('rewarded can be shown but reward may not be granted', () async {
      final repository = MockAdRepository(rewardedShowSucceeds: false);
      final controller = AdController(adRepository: repository);

      await controller.preloadBeforeRun(playerProfile());
      final result = await controller.showRewardedExtraLife();

      expect(result.shown, isTrue);
      expect(result.rewardGranted, isFalse);
      expect(repository.showCounts[AdType.rewarded], 1);
    });

    test(
      'rewarded accepted prevents interstitial when exit is not called',
          () async {
        final repository = MockAdRepository();
        final controller = AdController(adRepository: repository);

        await controller.preloadBeforeRun(playerProfile());
        final result = await controller.showRewardedExtraLife();

        expect(result.shown, isTrue);
        expect(result.rewardGranted, isTrue);
        expect(repository.showCounts[AdType.rewarded], 1);
        expect(repository.showCounts[AdType.interstitial], 0);
      },
    );

    test('declined rewarded triggers interstitial on exit', () async {
      final repository = MockAdRepository();
      final controller = AdController(adRepository: repository);

      await controller.preloadBeforeRun(playerProfile());
      final result = await controller.showInterstitialOnExit(playerProfile());

      expect(result.shown, isTrue);
      expect(result.rewardGranted, isFalse);
      expect(repository.showCounts[AdType.interstitial], 1);
    });

    test('interstitial can fail to show', () async {
      final repository = MockAdRepository(interstitialShowSucceeds: false);
      final controller = AdController(adRepository: repository);

      await controller.preloadBeforeRun(playerProfile());
      final result = await controller.showInterstitialOnExit(playerProfile());

      expect(result.shown, isFalse);
      expect(result.rewardGranted, isFalse);
      expect(repository.showCounts[AdType.interstitial], 1);
    });

    test('banner refresh only after 10 levels', () async {
      final repository = MockAdRepository();
      final controller = AdController(adRepository: repository);

      await controller.preloadBeforeRun(playerProfile());

      var lastLoadedRunLevel = await controller.refreshBannerAfterSafeZoneStop(
        playerProfile: playerProfile(),
        currentRunLevel: 10,
        lastBannerLoadedRunLevel: 1,
        wasSafeZoneStop: true,
      );

      expect(lastLoadedRunLevel, 1);
      expect(repository.preloadCounts[AdType.banner], 1);

      lastLoadedRunLevel = await controller.refreshBannerAfterSafeZoneStop(
        playerProfile: playerProfile(),
        currentRunLevel: 11,
        lastBannerLoadedRunLevel: lastLoadedRunLevel,
        wasSafeZoneStop: true,
      );

      expect(lastLoadedRunLevel, 11);
      expect(repository.preloadCounts[AdType.banner], 2);
    });

    test('banner refresh only on successful safe-zone stop', () async {
      final repository = MockAdRepository();
      final controller = AdController(adRepository: repository);

      await controller.preloadBeforeRun(playerProfile());

      final lastLoadedRunLevel = await controller
          .refreshBannerAfterSafeZoneStop(
        playerProfile: playerProfile(),
        currentRunLevel: 11,
        lastBannerLoadedRunLevel: 1,
        wasSafeZoneStop: false,
      );

      expect(lastLoadedRunLevel, 1);
      expect(repository.preloadCounts[AdType.banner], 1);
    });

    test('ads removed prevents banner refresh', () async {
      final repository = MockAdRepository();
      final controller = AdController(adRepository: repository);

      await controller.preloadBeforeRun(playerProfile(adsRemoved: true));

      final lastLoadedRunLevel = await controller
          .refreshBannerAfterSafeZoneStop(
        playerProfile: playerProfile(adsRemoved: true),
        currentRunLevel: 20,
        lastBannerLoadedRunLevel: 1,
        wasSafeZoneStop: true,
      );

      expect(lastLoadedRunLevel, 1);
      expect(repository.preloadCounts[AdType.banner], 0);
    });

    test('interstitial and rewarded preload at run start', () async {
      final repository = MockAdRepository();
      final controller = AdController(adRepository: repository);

      await controller.preloadBeforeRun(playerProfile());

      expect(repository.preloadCounts[AdType.interstitial], 1);
      expect(repository.preloadCounts[AdType.rewarded], 1);
    });

    test('banner also preloads at run start when ads are not removed', () async {
      final repository = MockAdRepository();
      final controller = AdController(adRepository: repository);

      await controller.preloadBeforeRun(playerProfile());

      expect(repository.preloadCounts[AdType.banner], 1);
    });
  });
}