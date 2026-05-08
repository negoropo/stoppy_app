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
  }) : assert(currentPlayerRank > 0),
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
}
