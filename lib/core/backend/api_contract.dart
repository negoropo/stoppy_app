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

  static bool isPublicAuthPath(String path) {
    final normalizedPath = _normalizePath(path);

    return normalizedPath == authRegister ||
        normalizedPath == authLogin;
  }

  static String _normalizePath(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return trimmed;
    }

    final parsed = Uri.tryParse(trimmed);

    if (parsed == null || parsed.hasScheme || parsed.hasAuthority) {
      return trimmed;
    }

    final normalizedPath = parsed.path;

    if (normalizedPath.length > 1 && normalizedPath.endsWith('/')) {
      return normalizedPath.substring(
        0,
        normalizedPath.length - 1,
      );
    }

    return normalizedPath;
  }
}