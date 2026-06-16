class BackendApiClientConfig {
  const BackendApiClientConfig({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 15),
  });

  final String baseUrl;
  final Duration timeout;
}
