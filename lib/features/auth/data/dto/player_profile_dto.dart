import '../../domain/models/player_profile.dart';

class PlayerProfileDto {
  const PlayerProfileDto({
    required this.id,
    required this.username,
    required this.createdAt,
    required this.gamePoints,
    this.lastDailyGpAwardedAt,
    required this.adsRemoved,
    this.currentLeagueDivision,
    required this.hasWeeklyLeagueEntry,
    required this.reservedLeagueSlot,
  });

  final String id;
  final String username;
  final DateTime createdAt;
  final int gamePoints;
  final DateTime? lastDailyGpAwardedAt;
  final bool adsRemoved;
  final int? currentLeagueDivision;
  final bool hasWeeklyLeagueEntry;
  final bool reservedLeagueSlot;

  factory PlayerProfileDto.fromDomain(PlayerProfile profile) {
    return PlayerProfileDto(
      id: profile.id,
      username: profile.username,
      createdAt: profile.createdAt,
      gamePoints: profile.gamePoints,
      lastDailyGpAwardedAt: profile.lastDailyGpAwardedAt,
      adsRemoved: profile.adsRemoved,
      currentLeagueDivision: profile.currentLeagueDivision,
      hasWeeklyLeagueEntry: profile.hasWeeklyLeagueEntry,
      reservedLeagueSlot: profile.reservedLeagueSlot,
    );
  }

  factory PlayerProfileDto.fromJson(Map<String, Object?> json) {
    return PlayerProfileDto(
      id: json['id'] as String,
      username: json['username'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      gamePoints: json['gamePoints'] as int? ?? 5,
      lastDailyGpAwardedAt: json['lastDailyGpAwardedAt'] == null
          ? null
          : DateTime.parse(json['lastDailyGpAwardedAt'] as String),
      adsRemoved: json['adsRemoved'] as bool? ?? false,
      currentLeagueDivision: json['currentLeagueDivision'] as int?,
      hasWeeklyLeagueEntry: json['hasWeeklyLeagueEntry'] as bool? ?? false,
      reservedLeagueSlot: json['reservedLeagueSlot'] as bool? ?? false,
    );
  }

  PlayerProfile toDomain() {
    return PlayerProfile(
      id: id,
      username: username,
      createdAt: createdAt,
      gamePoints: gamePoints,
      lastDailyGpAwardedAt: lastDailyGpAwardedAt,
      adsRemoved: adsRemoved,
      currentLeagueDivision: currentLeagueDivision,
      hasWeeklyLeagueEntry: hasWeeklyLeagueEntry,
      reservedLeagueSlot: reservedLeagueSlot,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'username': username,
      'createdAt': createdAt.toIso8601String(),
      'gamePoints': gamePoints,
      'lastDailyGpAwardedAt': lastDailyGpAwardedAt?.toIso8601String(),
      'adsRemoved': adsRemoved,
      'currentLeagueDivision': currentLeagueDivision,
      'hasWeeklyLeagueEntry': hasWeeklyLeagueEntry,
      'reservedLeagueSlot': reservedLeagueSlot,
    };
  }
}
