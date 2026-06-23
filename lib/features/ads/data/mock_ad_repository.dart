import '../domain/models/ad_load_state.dart';
import '../domain/models/ad_show_result.dart';
import '../domain/models/ad_type.dart';
import '../domain/repositories/ad_repository.dart';

class MockAdRepository implements AdRepository {
  MockAdRepository({
    this.rewardedShowSucceeds = true,
    this.interstitialShowSucceeds = true,
    this.preloadDelay = const Duration(milliseconds: 100),
    this.showDelay = const Duration(milliseconds: 100),
  });

  final bool rewardedShowSucceeds;
  final bool interstitialShowSucceeds;
  final Duration preloadDelay;
  final Duration showDelay;

  final Map<AdType, AdLoadState> _adLoadStates = {
    AdType.banner: AdLoadState(
      adType: AdType.banner,
      status: AdLoadStatus.failed,
    ),
    AdType.interstitial: AdLoadState(
      adType: AdType.interstitial,
      status: AdLoadStatus.failed,
    ),
    AdType.rewarded: AdLoadState(
      adType: AdType.rewarded,
      status: AdLoadStatus.failed,
    ),
  };

  final Map<AdType, int> preloadCounts = {
    AdType.banner: 0,
    AdType.interstitial: 0,
    AdType.rewarded: 0,
  };

  final Map<AdType, int> showCounts = {
    AdType.banner: 0,
    AdType.interstitial: 0,
    AdType.rewarded: 0,
  };

  @override
  Future<AdLoadState> preloadAd(AdType adType) async {
    _adLoadStates[adType] = AdLoadState(
      adType: adType,
      status: AdLoadStatus.loading,
    );

    await Future.delayed(preloadDelay);

    preloadCounts[adType] = (preloadCounts[adType] ?? 0) + 1;

    final loadedState = AdLoadState(
      adType: adType,
      status: AdLoadStatus.loaded,
    );

    _adLoadStates[adType] = loadedState;

    return loadedState;
  }

  @override
  Future<AdShowResult> showAd(AdType adType) async {
    await Future.delayed(showDelay);

    if (!isAdLoaded(adType)) {
      return const AdShowResult(shown: false, rewardGranted: false);
    }

    showCounts[adType] = (showCounts[adType] ?? 0) + 1;

    _adLoadStates[adType] = AdLoadState(
      adType: adType,
      status: AdLoadStatus.failed,
    );

    if (adType == AdType.rewarded) {
      return AdShowResult(shown: true, rewardGranted: rewardedShowSucceeds);
    }

    if (adType == AdType.interstitial) {
      return AdShowResult(
        shown: interstitialShowSucceeds,
        rewardGranted: false,
      );
    }

    return const AdShowResult(shown: true, rewardGranted: false);
  }

  @override
  bool isAdLoaded(AdType adType) {
    return getAdLoadState(adType).isLoaded;
  }

  @override
  AdLoadState getAdLoadState(AdType adType) {
    return _adLoadStates[adType] ??
        AdLoadState(adType: adType, status: AdLoadStatus.failed);
  }
}
