import 'ad_type.dart';

enum AdLoadStatus { loading, loaded, failed }

class AdLoadState {
  const AdLoadState({required this.adType, required this.status});

  final AdType adType;
  final AdLoadStatus status;

  bool get isLoaded => status == AdLoadStatus.loaded;

  bool get isLoading => status == AdLoadStatus.loading;

  bool get hasFailed => status == AdLoadStatus.failed;

  AdLoadState copyWith({AdType? adType, AdLoadStatus? status}) {
    return AdLoadState(
      adType: adType ?? this.adType,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'AdLoadState(adType: $adType, status: $status)';
  }
}
