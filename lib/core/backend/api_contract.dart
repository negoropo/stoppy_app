abstract final class ApiContract {
  static const version = 'v1';
  static const apiPrefix = '/api/$version';

  static const contentTypeHeader = 'Content-Type';
  static const acceptHeader = 'Accept';
  static const authorizationHeader = 'Authorization';

  static const jsonContentType = 'application/json';
  static const bearerScheme = 'Bearer';

  static const authRegister = '$apiPrefix/auth/register';
  static const authLogin = '$apiPrefix/auth/login';
  static const authRefresh = '$apiPrefix/auth/refresh';

  static const playerProfile = '$apiPrefix/player/profile';

  static const leagueEntry = '$apiPrefix/league/enter';
  static const leagueSnapshot = '$apiPrefix/league/snapshot';
  static const leagueHistory = '$apiPrefix/league/history';
  static const leagueRecords = '$apiPrefix/league/records';
  static const leagueAchievements = '$apiPrefix/league/achievements';
  static const leagueRuns = '$apiPrefix/league/runs';
  static const leagueRunSubmission = '$apiPrefix/runs/league';

  static const knockoutTournament = '$apiPrefix/knockout/tournament';
  static const knockoutRegistration = '$apiPrefix/knockout/register';
  static const knockoutStatus = '$apiPrefix/knockout/status';
  static const knockoutActiveDuel = '$apiPrefix/knockout/active-duel';
  static const knockoutHistory = '$apiPrefix/knockout/history';
  static const knockoutRecords = '$apiPrefix/knockout/records';
  static const knockoutHallOfFame = '$apiPrefix/knockout/hall-of-fame';
  static const knockoutRunSubmission = '$apiPrefix/runs/knockout';

  static const Set<String> _publicAuthPaths = {
    authRegister,
    authLogin,
    authRefresh,
  };

  /// Returns whether [path] identifies one of the public authentication
  /// endpoints that must not receive an Authorization header.
  ///
  /// Only relative API paths are accepted. Absolute URLs, paths containing
  /// query parameters or fragments, and auth-like sibling paths are rejected.
  /// A trailing slash is ignored.
  static bool isPublicAuthPath(String path) {
    final normalizedPath = _normalizeRelativePath(path);

    return normalizedPath != null && _publicAuthPaths.contains(normalizedPath);
  }

  static String? _normalizeRelativePath(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return null;
    }

    final parsed = Uri.tryParse(trimmed);

    if (parsed == null ||
        parsed.hasScheme ||
        parsed.hasAuthority ||
        parsed.hasQuery ||
        parsed.hasFragment) {
      return null;
    }

    var normalizedPath = parsed.path;

    if (normalizedPath.isEmpty || !normalizedPath.startsWith('/')) {
      return null;
    }

    while (normalizedPath.length > 1 && normalizedPath.endsWith('/')) {
      normalizedPath = normalizedPath.substring(0, normalizedPath.length - 1);
    }

    return normalizedPath;
  }
}
