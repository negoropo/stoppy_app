enum RepositoryRuntime { mock, backend }

final class AppEnvironment {
  const AppEnvironment({
    required this.repositoryRuntime,
    required this.apiBaseUrl,
  }) : assert(apiBaseUrl != '');

  static const defaultApiBaseUrl = 'http://localhost:8080';

  final RepositoryRuntime repositoryRuntime;
  final String apiBaseUrl;

  const AppEnvironment.mock()
    : repositoryRuntime = RepositoryRuntime.mock,
      apiBaseUrl = defaultApiBaseUrl;

  const AppEnvironment.backend({this.apiBaseUrl = defaultApiBaseUrl})
    : repositoryRuntime = RepositoryRuntime.backend;

  factory AppEnvironment.fromDartDefines() {
    const runtimeName = String.fromEnvironment(
      'STP_REPOSITORY_RUNTIME',
      defaultValue: 'mock',
    );

    const apiBaseUrl = String.fromEnvironment(
      'STP_API_BASE_URL',
      defaultValue: defaultApiBaseUrl,
    );

    return AppEnvironment(
      repositoryRuntime: RepositoryRuntimeX.fromName(runtimeName),
      apiBaseUrl: apiBaseUrl,
    );
  }

  bool get usesBackend {
    return repositoryRuntime == RepositoryRuntime.backend;
  }
}

extension RepositoryRuntimeX on RepositoryRuntime {
  static RepositoryRuntime fromName(String name) {
    return switch (name.trim().toLowerCase()) {
      'backend' => RepositoryRuntime.backend,
      'mock' => RepositoryRuntime.mock,
      _ => RepositoryRuntime.mock,
    };
  }
}
