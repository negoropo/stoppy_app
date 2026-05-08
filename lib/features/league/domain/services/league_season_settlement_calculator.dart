import 'dart:math' as math;

import '../models/league_division.dart';
import '../models/league_division_settlement.dart';
import '../models/league_ranking_entry.dart';

class LeagueSeasonSettlementCalculator {
  const LeagueSeasonSettlementCalculator();

  int minimumRelegationCount(LeagueDivision division) {
    // Relegation uses capacity instead of current player count so empty
    // reserved slots cannot shrink the competitive pressure in a division.
    return (division.capacity * 0.4).ceil();
  }

  int minimumPromotionCountWherePossible(LeagueDivision division) {
    return (division.capacity * 0.2).ceil();
  }

  List<String> relegatedPlayerIdsForDivision({
    required LeagueDivision division,
    required bool isLastDivision,
    required List<LeagueRankingEntry> rankedEntries,
  }) {
    if (isLastDivision) {
      return const [];
    }

    final inactiveEntries = rankedEntries
        .where((entry) => entry.isInactive)
        .toList();
    final activeEntries = rankedEntries
        .where((entry) => !entry.isInactive)
        .toList();
    final minimumRelegation = minimumRelegationCount(division);
    final neededActiveRelegations = math.max(
      0,
      minimumRelegation - inactiveEntries.length,
    );
    final worstActiveEntries = activeEntries.reversed.take(
      neededActiveRelegations,
    );

    // Inactive players always relegate. If they exceed the 40% floor, the
    // whole inactive set moves down because an unpaid reserved slot should not
    // protect a player from weekly league movement.
    return [
      ...inactiveEntries.map((entry) => entry.playerEntry.playerId),
      ...worstActiveEntries.map((entry) => entry.playerEntry.playerId),
    ];
  }

  List<String> promotedPlayerIdsForLowerDivision({
    required LeagueDivision lowerDivision,
    required int aboveDivisionRelegationCount,
    required List<LeagueRankingEntry> lowerDivisionRankedEntries,
  }) {
    final activeEntries = lowerDivisionRankedEntries
        .where((entry) => !entry.isInactive)
        .toList();
    final promotionCount = math.max(
      aboveDivisionRelegationCount,
      minimumPromotionCountWherePossible(lowerDivision),
    );

    return activeEntries
        .take(math.min(promotionCount, activeEntries.length))
        .map((entry) => entry.playerEntry.playerId)
        .toList();
  }

  LeagueDivisionSettlement settlePenultimateAndLastDivision({
    required LeagueDivision penultimateDivision,
    required LeagueDivision lastDivision,
    required List<LeagueRankingEntry> penultimateRankedEntries,
    required List<LeagueRankingEntry> lastRankedEntries,
  }) {
    final inactivePenultimateEntries = penultimateRankedEntries
        .where((entry) => entry.isInactive)
        .toList();
    final activePenultimateEntries = penultimateRankedEntries
        .where((entry) => !entry.isInactive)
        .toList();
    final activeLastEntries = lastRankedEntries
        .where((entry) => !entry.isInactive)
        .toList();
    final inactiveLastEntries = lastRankedEntries
        .where((entry) => entry.isInactive)
        .toList();
    final targetPromotionCount = math.max(
      minimumPromotionCountWherePossible(lastDivision),
      inactivePenultimateEntries.length,
    );

    final lastPromotionCandidateCount = math.min(
      targetPromotionCount,
      activeLastEntries.length,
    );
    final promotionCandidates = activeLastEntries.take(
      lastPromotionCandidateCount,
    );
    final extraActiveRelegationCount = math.max(
      0,
      promotionCandidates.length - inactivePenultimateEntries.length,
    );
    final activeRelegations = activePenultimateEntries.reversed.take(
      extraActiveRelegationCount,
    );
    final relegatedEntries = [
      ...inactivePenultimateEntries,
      ...activeRelegations,
    ];
    final promotedPlayerIds = promotionCandidates
        .map((entry) => entry.playerEntry.playerId)
        .toSet();

    final activeLastPlayerIds = activeLastEntries
        .map((entry) => entry.playerEntry.playerId)
        .toSet();

    // The bottom division can disappear when it has no active players to keep
    // or promote. This avoids carrying a purely inactive last division into the
    // next season as dead capacity.
    return LeagueDivisionSettlement(
      divisionNumber: penultimateDivision.number,
      promotedPlayerIds: promotionCandidates
          .map((entry) => entry.playerEntry.playerId)
          .toList(),
      relegatedPlayerIds: relegatedEntries
          .map((entry) => entry.playerEntry.playerId)
          .toList(),
      keptPlayerIds: [
        ...activePenultimateEntries
            .where(
              (entry) => !relegatedEntries.any(
                (relegated) =>
                    relegated.playerEntry.playerId ==
                    entry.playerEntry.playerId,
              ),
            )
            .map((entry) => entry.playerEntry.playerId),
        ...activeLastPlayerIds.where(
          (playerId) => !promotedPlayerIds.contains(playerId),
        ),
      ],
      lostReservationPlayerIds: [
        ...inactivePenultimateEntries.map(
          (entry) => entry.playerEntry.playerId,
        ),
        ...inactiveLastEntries.map((entry) => entry.playerEntry.playerId),
      ],
      closedDivision: activeLastEntries.isEmpty,
    );
  }
}
