class BackendConfig {
  const BackendConfig({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 15),
  }) : assert(baseUrl != '');

  final String baseUrl;
  final Duration timeout;
}

/// Compatibility type retained while call sites migrate to [BackendConfig].
@Deprecated('Use BackendConfig instead.')
class BackendApiClientConfig extends BackendConfig {
  const BackendApiClientConfig({
    required super.baseUrl,
    super.timeout = const Duration(seconds: 15),
  });
}