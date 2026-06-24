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

    return PlayerProfileDto(
      id: reader.requiredString(idKey).trim(),
      username: reader.requiredString(usernameKey).trim(),
      createdAt: reader.requiredDateTime(createdAtKey),
      gamePoints: reader.optionalNonNegativeInt(gamePointsKey, defaultValue: 5),
      lastDailyGpAwardedAt: reader.optionalDateTime(lastDailyGpAwardedAtKey),
      adsRemoved: reader.optionalBool(adsRemovedKey, defaultValue: false),
      currentLeagueDivision: reader.optionalPositiveInt(
        currentLeagueDivisionKey,
      ),
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
    Object? lastDailyGpAwardedAt = _unset,
    bool? adsRemoved,
    Object? currentLeagueDivision = _unset,
    bool? hasWeeklyLeagueEntry,
    bool? reservedLeagueSlot,
  }) {
    assert(
      identical(lastDailyGpAwardedAt, _unset) ||
          lastDailyGpAwardedAt is DateTime?,
      'lastDailyGpAwardedAt must be a DateTime, null, or omitted.',
    );

    assert(
      identical(currentLeagueDivision, _unset) || currentLeagueDivision is int?,
      'currentLeagueDivision must be an int, null, or omitted.',
    );

    return PlayerProfileDto(
      id: id ?? this.id,
      username: username ?? this.username,
      createdAt: createdAt ?? this.createdAt,
      gamePoints: gamePoints ?? this.gamePoints,
      lastDailyGpAwardedAt: identical(lastDailyGpAwardedAt, _unset)
          ? this.lastDailyGpAwardedAt
          : lastDailyGpAwardedAt as DateTime?,
      adsRemoved: adsRemoved ?? this.adsRemoved,
      currentLeagueDivision: identical(currentLeagueDivision, _unset)
          ? this.currentLeagueDivision
          : currentLeagueDivision as int?,
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

const Object _unset = Object();
