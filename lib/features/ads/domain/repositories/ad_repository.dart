import '../models/ad_load_state.dart';
import '../models/ad_show_result.dart';
import '../models/ad_type.dart';

abstract class AdRepository {
  Future<AdLoadState> preloadAd(AdType adType);

  Future<AdShowResult> showAd(AdType adType);

  bool isAdLoaded(AdType adType);

  AdLoadState getAdLoadState(AdType adType);
}
