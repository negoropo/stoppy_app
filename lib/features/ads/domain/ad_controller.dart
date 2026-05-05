import '../../auth/domain/models/player_profile.dart';
import 'models/ad_show_result.dart';
import 'models/ad_type.dart';
import 'repositories/ad_repository.dart';

class AdController {
  const AdController({required this.adRepository});

  static const int bannerRefreshLevelInterval = 10;

  final AdRepository adRepository;

  Future<void> preloadBeforeRun(PlayerProfile? playerProfile) async {
    final preloadTasks = <Future<void>>[];

    if (!_areNonOptionalAdsRemoved(playerProfile)) {
      preloadTasks.add(adRepository.preloadAd(AdType.banner));
      preloadTasks.add(adRepository.preloadAd(AdType.interstitial));
    }

    preloadTasks.add(adRepository.preloadAd(AdType.rewarded));

    await Future.wait(preloadTasks);
  }

  Future<int> refreshBannerAfterSafeZoneStop({
    required PlayerProfile? playerProfile,
    required int currentRunLevel,
    required int lastBannerLoadedRunLevel,
    required bool wasSafeZoneStop,
  }) async {
    if (_areNonOptionalAdsRemoved(playerProfile) || !wasSafeZoneStop) {
      return lastBannerLoadedRunLevel;
    }

    final levelsSinceLastLoad = currentRunLevel - lastBannerLoadedRunLevel;
    if (levelsSinceLastLoad < bannerRefreshLevelInterval) {
      return lastBannerLoadedRunLevel;
    }

    await adRepository.preloadAd(AdType.banner);
    return currentRunLevel;
  }

  Future<AdShowResult> showRewardedExtraLife() {
    return adRepository.showAd(AdType.rewarded);
  }

  Future<AdShowResult> showInterstitialOnExit(
      PlayerProfile? playerProfile,
      ) async {
    if (_areNonOptionalAdsRemoved(playerProfile)) {
      return const AdShowResult(shown: false, rewardGranted: false);
    }

    if (!adRepository.isAdLoaded(AdType.interstitial)) {
      return const AdShowResult(shown: false, rewardGranted: false);
    }

    return adRepository.showAd(AdType.interstitial);
  }

  bool _areNonOptionalAdsRemoved(PlayerProfile? playerProfile) {
    return playerProfile?.adsRemoved ?? false;
  }
}