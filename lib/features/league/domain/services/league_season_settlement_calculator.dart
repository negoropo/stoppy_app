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

    final regularRelegationCount = math.min(
      minimumRelegationCount(division),
      rankedEntries.length,
    );

    // Session 17 ranks active players before inactive unpaid players, then
    // relegates the bottom 40% slice for regular divisions. Inactive players are
    // still naturally exposed because they sort after active players, but the
    // whole inactive group is no longer force-relegated when it exceeds 40%.
    return rankedEntries.reversed
        .take(regularRelegationCount)
        .map((entry) => entry.playerEntry.playerId)
        .toList();
  }

  List<String> promotedPlayerIdsForLowerDivision({
    required LeagueDivision lowerDivision,
    required int aboveDivisionRelegationCount,
    required List<LeagueRankingEntry> lowerDivisionRankedEntries,
  }) {
    final activeEntries = lowerDivisionRankedEntries
        .where((entry) => !entry.isInactive)
        .toList();

    // Normal lower divisions always offer at least their 20% promotion floor
    // when enough active players exist, while still matching larger relegation
    // pressure from the division above.
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

    final mustCloseLastDivision =
        activeLastEntries.isEmpty ||
        activeLastEntries.length < inactivePenultimateEntries.length;

    // The bottom division disappears when it cannot provide enough active
    // promoted players to replace inactive penultimate slots. Carrying that
    // under-filled division forward would preserve dead reserved capacity.
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
      closedDivision: mustCloseLastDivision,
    );
  }
}
