import 'package:stoppy_app/core/backend/domain_mapper.dart';
import 'package:stoppy_app/core/backend/json_reader.dart';

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

  factory PlayerProfileDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(json, context: 'PlayerProfileDto');
    final currentLeagueDivision = reader.optionalPositiveInt(
      currentLeagueDivisionKey,
    );
    return PlayerProfileDto(
      id: reader.requiredString(idKey),
      username: reader.requiredString(usernameKey),
      createdAt: reader.requiredDateTime(createdAtKey),
      gamePoints: reader.optionalInt(gamePointsKey, defaultValue: 5),
      lastDailyGpAwardedAt: reader.optionalDateTime(lastDailyGpAwardedAtKey),
      adsRemoved: reader.optionalBool(adsRemovedKey, defaultValue: false),
      currentLeagueDivision: currentLeagueDivision,
      hasWeeklyLeagueEntry: reader.optionalBool(
        hasWeeklyLeagueEntryKey,
        defaultValue: false,
      ),
      reservedLeagueSlot: reader.optionalBool(
        reservedLeagueSlotKey,
        defaultValue: false,
      ),
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
      lastDailyGpAwardedAt: lastDailyGpAwardedAt ?? this.lastDailyGpAwardedAt,
      adsRemoved: adsRemoved ?? this.adsRemoved,
      currentLeagueDivision:
          currentLeagueDivision ?? this.currentLeagueDivision,
      hasWeeklyLeagueEntry: hasWeeklyLeagueEntry ?? this.hasWeeklyLeagueEntry,
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
