import 'package:stoppy_app/core/backend/domain_mapper.dart';

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

  static const idKey = 'id';
  static const usernameKey = 'username';
  static const createdAtKey = 'createdAt';
  static const gamePointsKey = 'gamePoints';
  static const lastDailyGpAwardedAtKey = 'lastDailyGpAwardedAt';
  static const adsRemovedKey = 'adsRemoved';
  static const currentLeagueDivisionKey = 'currentLeagueDivision';
  static const hasWeeklyLeagueEntryKey = 'hasWeeklyLeagueEntry';
  static const reservedLeagueSlotKey = 'reservedLeagueSlot';

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
      id: json[idKey] as String,
      username: json[usernameKey] as String,
      createdAt: DateTime.parse(json[createdAtKey] as String),
      gamePoints: json[gamePointsKey] as int,
      lastDailyGpAwardedAt: json[lastDailyGpAwardedAtKey] == null
          ? null
          : DateTime.parse(json[lastDailyGpAwardedAtKey] as String),
      adsRemoved: json[adsRemovedKey] as bool,
      currentLeagueDivision: json[currentLeagueDivisionKey] as int?,
      hasWeeklyLeagueEntry: json[hasWeeklyLeagueEntryKey] as bool,
      reservedLeagueSlot: json[reservedLeagueSlotKey] as bool,
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

  PlayerProfileDto copyWith({
    String? id,
    String? username,
    DateTime? createdAt,
    int? gamePoints,
    DateTime? lastDailyGpAwardedAt,
    bool? adsRemoved,
    int? currentLeagueDivision,
    bool? hasWeeklyLeagueEntry,
    bool? reservedLeagueSlot,
  }) {
    return PlayerProfileDto(
      id: id ?? this.id,
      username: username ?? this.username,
      createdAt: createdAt ?? this.createdAt,
      gamePoints: gamePoints ?? this.gamePoints,
      lastDailyGpAwardedAt:
      lastDailyGpAwardedAt ?? this.lastDailyGpAwardedAt,
      adsRemoved: adsRemoved ?? this.adsRemoved,
      currentLeagueDivision:
      currentLeagueDivision ?? this.currentLeagueDivision,
      hasWeeklyLeagueEntry:
      hasWeeklyLeagueEntry ?? this.hasWeeklyLeagueEntry,
      reservedLeagueSlot: reservedLeagueSlot ?? this.reservedLeagueSlot,
    );
  }

  Map<String, Object?> toJson() {
    return {
      idKey: id,
      usernameKey: username,
      createdAtKey: createdAt.toIso8601String(),
      gamePointsKey: gamePoints,
      lastDailyGpAwardedAtKey: lastDailyGpAwardedAt?.toIso8601String(),
      adsRemovedKey: adsRemoved,
      currentLeagueDivisionKey: currentLeagueDivision,
      hasWeeklyLeagueEntryKey: hasWeeklyLeagueEntry,
      reservedLeagueSlotKey: reservedLeagueSlot,
    };
  }
}

class PlayerProfileMapper
    extends DomainMapper<PlayerProfile, PlayerProfileDto> {
  const PlayerProfileMapper();

  @override
  PlayerProfileDto toDto(PlayerProfile domain) {
    return PlayerProfileDto.fromDomain(domain);
  }

  @override
  PlayerProfile toDomain(PlayerProfileDto dto) {
    return dto.toDomain();
  }
}