import 'dart:collection';

import 'league_ranking_entry.dart';

class LeagueRankingSnapshot {
  LeagueRankingSnapshot({
    required this.currentPlayerRank,
    required this.currentPlayerEntry,
    required List<LeagueRankingEntry> playersAbove,
    required List<LeagueRankingEntry> playersBelow,
    required this.scoreNeededForPromotionZone,
    required this.scoreNeededToStayInDivision,
    required this.promotionZoneEndRank,
    required this.relegationZoneStartRank,
  }) : assert(currentPlayerRank > 0),
       assert(promotionZoneEndRank == null || promotionZoneEndRank > 0),
       assert(relegationZoneStartRank == null || relegationZoneStartRank > 0),
       playersAbove = UnmodifiableListView(playersAbove),
       playersBelow = UnmodifiableListView(playersBelow);

  final int currentPlayerRank;
  final LeagueRankingEntry currentPlayerEntry;

  /// Ordered nearest-first:
  /// closest higher rank first.
  final List<LeagueRankingEntry> playersAbove;

  /// Ordered nearest-first:
  /// closest lower rank first.
  final List<LeagueRankingEntry> playersBelow;

  /// Null when promotion does not exist
  /// (e.g. division 1).
  final double? scoreNeededForPromotionZone;

  /// Null when relegation does not exist
  /// (e.g. last division).
  final double? scoreNeededToStayInDivision;

  /// Null when the division has no promotion zone.
  final int? promotionZoneEndRank;

  /// Null when the division has no relegation zone.
  final int? relegationZoneStartRank;
}
