enum AdType { banner, interstitial, rewarded }

extension AdTypeX on AdType {
  String get name {
    switch (this) {
      case AdType.banner:
        return 'banner';
      case AdType.interstitial:
        return 'interstitial';
      case AdType.rewarded:
        return 'rewarded';
    }
  }
}