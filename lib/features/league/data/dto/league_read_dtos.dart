import 'package:stoppy_app/core/backend/json_reader.dart';

import '../../domain/models/league_player_entry.dart';
import '../../domain/models/league_ranking_entry.dart';
import '../../domain/models/league_ranking_snapshot.dart';
import '../../domain/models/weekly_league_history_entry.dart';
import '../../domain/models/weekly_league_run.dart';
import 'league_persistence_dtos.dart';
import 'weekly_league_run_dto.dart';

final class LeagueCurrentEntryResponseDto {
  const LeagueCurrentEntryResponseDto({required this.entry});

  final LeaguePlayerEntryDto? entry;

  factory LeagueCurrentEntryResponseDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'LeagueCurrentEntryResponseDto',
    );
    final data = reader.toMap();

    if (!data.containsKey('entry')) {
      throw const FormatException(
        'League current entry response must contain entry.',
      );
    }

    final rawEntry = data['entry'];

    return LeagueCurrentEntryResponseDto(
      entry: rawEntry == null ? null : LeaguePlayerEntryDto.fromJson(rawEntry),
    );
  }

  LeaguePlayerEntry? toDomain() {
    return entry?.toDomain();
  }

  Map<String, Object?> toJson() {
    return {'entry': entry?.toJson()};
  }
}

final class LeagueRankingEntryDto {
  const LeagueRankingEntryDto({
    required this.rank,
    required this.playerEntry,
    required this.weeklyScore,
  });

  final int rank;
  final LeaguePlayerEntryDto playerEntry;
  final WeeklyLeagueScoreDto weeklyScore;

  factory LeagueRankingEntryDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'LeagueRankingEntryDto',
    );

    final rank = reader.requiredPositiveInt('rank');
    final playerEntry = LeaguePlayerEntryDto.fromJson(
      reader.requiredObject('playerEntry').toMap(),
    );
    final weeklyScore = WeeklyLeagueScoreDto.fromJson(
      reader.requiredObject('weeklyScore').toMap(),
    );

    if (playerEntry.playerId != weeklyScore.playerId) {
      throw const FormatException(
        'League ranking entry player and weekly score must match.',
      );
    }

    return LeagueRankingEntryDto(
      rank: rank,
      playerEntry: playerEntry,
      weeklyScore: weeklyScore,
    );
  }

  factory LeagueRankingEntryDto.fromDomain(LeagueRankingEntry entry) {
    return LeagueRankingEntryDto(
      rank: entry.rank,
      playerEntry: LeaguePlayerEntryDto.fromDomain(entry.playerEntry),
      weeklyScore: WeeklyLeagueScoreDto.fromDomain(entry.weeklyScore),
    );
  }

  LeagueRankingEntry toDomain() {
    return LeagueRankingEntry(
      rank: rank,
      playerEntry: playerEntry.toDomain(),
      weeklyScore: weeklyScore.toDomain(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'rank': rank,
      'playerEntry': playerEntry.toJson(),
      'weeklyScore': weeklyScore.toJson(),
    };
  }
}

final class LeagueRankingResponseDto {
  const LeagueRankingResponseDto({required this.entries});

  final List<LeagueRankingEntryDto> entries;

  factory LeagueRankingResponseDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'LeagueRankingResponseDto',
    );

    return LeagueRankingResponseDto(
      entries: reader
          .requiredObjectList('entries')
          .map((entry) => LeagueRankingEntryDto.fromJson(entry.toMap()))
          .toList(growable: false),
    );
  }

  List<LeagueRankingEntry> toDomain() {
    return List<LeagueRankingEntry>.unmodifiable(
      entries.map((entry) => entry.toDomain()),
    );
  }

  Map<String, Object?> toJson() {
    return {'entries': entries.map((entry) => entry.toJson()).toList()};
  }
}

final class LeagueRankingSnapshotDto {
  const LeagueRankingSnapshotDto({
    required this.currentPlayerRank,
    required this.currentPlayerEntry,
    required this.playersAbove,
    required this.playersBelow,
    required this.scoreNeededForPromotionZone,
    required this.scoreNeededToStayInDivision,
    required this.promotionZoneEndRank,
    required this.relegationZoneStartRank,
  });

  final int currentPlayerRank;
  final LeagueRankingEntryDto currentPlayerEntry;
  final List<LeagueRankingEntryDto> playersAbove;
  final List<LeagueRankingEntryDto> playersBelow;
  final double? scoreNeededForPromotionZone;
  final double? scoreNeededToStayInDivision;
  final int? promotionZoneEndRank;
  final int? relegationZoneStartRank;

  factory LeagueRankingSnapshotDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'LeagueRankingSnapshotDto',
    );
    final currentPlayerRank = reader.requiredPositiveInt('currentPlayerRank');
    final currentPlayerEntry = LeagueRankingEntryDto.fromJson(
      reader.requiredObject('currentPlayerEntry').toMap(),
    );
    final playersAbove = reader
        .requiredObjectList('playersAbove')
        .map((entry) => LeagueRankingEntryDto.fromJson(entry.toMap()))
        .toList(growable: false);
    final playersBelow = reader
        .requiredObjectList('playersBelow')
        .map((entry) => LeagueRankingEntryDto.fromJson(entry.toMap()))
        .toList(growable: false);

    final dto = LeagueRankingSnapshotDto(
      currentPlayerRank: currentPlayerRank,
      currentPlayerEntry: currentPlayerEntry,
      playersAbove: playersAbove,
      playersBelow: playersBelow,
      scoreNeededForPromotionZone: _optionalNonNegativeDouble(
        reader,
        'scoreNeededForPromotionZone',
      ),
      scoreNeededToStayInDivision: _optionalNonNegativeDouble(
        reader,
        'scoreNeededToStayInDivision',
      ),
      promotionZoneEndRank: reader.optionalPositiveInt('promotionZoneEndRank'),
      relegationZoneStartRank: reader.optionalPositiveInt(
        'relegationZoneStartRank',
      ),
    );

    return dto._validated();
  }

  factory LeagueRankingSnapshotDto.fromDomain(LeagueRankingSnapshot snapshot) {
    return LeagueRankingSnapshotDto(
      currentPlayerRank: snapshot.currentPlayerRank,
      currentPlayerEntry: LeagueRankingEntryDto.fromDomain(
        snapshot.currentPlayerEntry,
      ),
      playersAbove: snapshot.playersAbove
          .map(LeagueRankingEntryDto.fromDomain)
          .toList(growable: false),
      playersBelow: snapshot.playersBelow
          .map(LeagueRankingEntryDto.fromDomain)
          .toList(growable: false),
      scoreNeededForPromotionZone: snapshot.scoreNeededForPromotionZone,
      scoreNeededToStayInDivision: snapshot.scoreNeededToStayInDivision,
      promotionZoneEndRank: snapshot.promotionZoneEndRank,
      relegationZoneStartRank: snapshot.relegationZoneStartRank,
    );
  }

  LeagueRankingSnapshotDto _validated() {
    if (currentPlayerRank != currentPlayerEntry.rank) {
      throw const FormatException(
        'League snapshot currentPlayerRank must match current entry rank.',
      );
    }

    if (playersAbove.any((entry) => entry.rank >= currentPlayerRank) ||
        playersBelow.any((entry) => entry.rank <= currentPlayerRank)) {
      throw const FormatException(
        'League snapshot nearby ranking is inconsistent with current rank.',
      );
    }

    _validateUniqueRanks([
      ...playersAbove,
      currentPlayerEntry,
      ...playersBelow,
    ]);
    _validateCurrentPlayerAppearsOnlyOnce(
      currentPlayerEntry: currentPlayerEntry,
      playersAbove: playersAbove,
      playersBelow: playersBelow,
    );

    return this;
  }

  LeagueRankingSnapshot toDomain() {
    return LeagueRankingSnapshot(
      currentPlayerRank: currentPlayerRank,
      currentPlayerEntry: currentPlayerEntry.toDomain(),
      playersAbove: playersAbove.map((entry) => entry.toDomain()).toList(),
      playersBelow: playersBelow.map((entry) => entry.toDomain()).toList(),
      scoreNeededForPromotionZone: scoreNeededForPromotionZone,
      scoreNeededToStayInDivision: scoreNeededToStayInDivision,
      promotionZoneEndRank: promotionZoneEndRank,
      relegationZoneStartRank: relegationZoneStartRank,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'currentPlayerRank': currentPlayerRank,
      'currentPlayerEntry': currentPlayerEntry.toJson(),
      'playersAbove': playersAbove.map((entry) => entry.toJson()).toList(),
      'playersBelow': playersBelow.map((entry) => entry.toJson()).toList(),
      'scoreNeededForPromotionZone': scoreNeededForPromotionZone,
      'scoreNeededToStayInDivision': scoreNeededToStayInDivision,
      'promotionZoneEndRank': promotionZoneEndRank,
      'relegationZoneStartRank': relegationZoneStartRank,
    };
  }
}

final class LeagueHistoryResponseDto {
  const LeagueHistoryResponseDto({required this.entries});

  final List<WeeklyLeagueHistoryEntryDto> entries;

  factory LeagueHistoryResponseDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'LeagueHistoryResponseDto',
    );

    return LeagueHistoryResponseDto(
      entries: reader
          .requiredObjectList('entries')
          .map((entry) => WeeklyLeagueHistoryEntryDto.fromJson(entry.toMap()))
          .toList(growable: false),
    );
  }

  List<WeeklyLeagueHistoryEntry> toDomain() {
    return List<WeeklyLeagueHistoryEntry>.unmodifiable(
      entries.map((entry) => entry.toDomain()),
    );
  }

  Map<String, Object?> toJson() {
    return {'entries': entries.map((entry) => entry.toJson()).toList()};
  }
}

final class LeagueWeeklyRunsResponseDto {
  const LeagueWeeklyRunsResponseDto({required this.runs});

  final List<WeeklyLeagueRunDto> runs;

  factory LeagueWeeklyRunsResponseDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'LeagueWeeklyRunsResponseDto',
    );

    return LeagueWeeklyRunsResponseDto(
      runs: reader
          .requiredObjectList('runs')
          .map((run) => WeeklyLeagueRunDto.fromJson(run.toMap()))
          .toList(growable: false),
    );
  }

  List<WeeklyLeagueRun> toDomain() {
    return List<WeeklyLeagueRun>.unmodifiable(
      runs.map((run) => run.toDomain()),
    );
  }

  Map<String, Object?> toJson() {
    return {'runs': runs.map((run) => run.toJson()).toList()};
  }
}

double? _optionalNonNegativeDouble(JsonReader reader, String key) {
  final rawValue = reader.toMap()[key];

  if (rawValue == null) {
    return null;
  }

  if (rawValue is num && rawValue >= 0) {
    return rawValue.toDouble();
  }

  throw FormatException(
    'League ranking snapshot field must be non-negative or null: $key.',
  );
}

void _validateUniqueRanks(List<LeagueRankingEntryDto> entries) {
  final seenRanks = <int>{};

  for (final entry in entries) {
    if (!seenRanks.add(entry.rank)) {
      throw FormatException(
        'League snapshot contains duplicate rank ${entry.rank}.',
      );
    }
  }
}

void _validateCurrentPlayerAppearsOnlyOnce({
  required LeagueRankingEntryDto currentPlayerEntry,
  required List<LeagueRankingEntryDto> playersAbove,
  required List<LeagueRankingEntryDto> playersBelow,
}) {
  final currentPlayerId = currentPlayerEntry.playerEntry.playerId;
  final nearbyEntries = [...playersAbove, ...playersBelow];
  final isRepeated = nearbyEntries.any(
    (entry) => entry.playerEntry.playerId == currentPlayerId,
  );

  if (isRepeated) {
    throw const FormatException(
      'League snapshot current player cannot appear above or below itself.',
    );
  }
}
