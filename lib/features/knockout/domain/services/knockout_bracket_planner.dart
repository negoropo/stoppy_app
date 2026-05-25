import 'dart:math';

import '../models/knockout_match.dart';
import '../models/knockout_player_entry.dart';
import '../models/knockout_round.dart';
import 'knockout_tournament_schedule.dart';

class KnockoutBracketPlanner {
  const KnockoutBracketPlanner({
    this.schedule = const KnockoutTournamentSchedule(),
  });

  final KnockoutTournamentSchedule schedule;

  KnockoutRound createOpeningRound({
    required List<KnockoutPlayerEntry> entries,
    required DateTime roundStartsAt,
    required Random random,
  }) {
    final shuffledEntries = [...entries]..shuffle(random);
    final matchCount = openingMatchCount(shuffledEntries.length);
    final matchedPlayerCount = matchCount * 2;
    final matchedEntries = shuffledEntries.take(matchedPlayerCount).toList();
    final byeEntries = shuffledEntries.skip(matchedPlayerCount).toList();

    return KnockoutRound(
      roundNumber: 1,
      startsAt: roundStartsAt,
      endsAt: schedule.roundEndsAt(roundStartsAt),
      status: KnockoutRoundStatus.active,
      matches: [
        for (var index = 0; index < matchCount; index += 1)
          KnockoutMatch(
            id: 'round-1-match-${index + 1}',
            roundNumber: 1,
            status: KnockoutMatchStatus.active,
            playerOneId: matchedEntries[index * 2].playerId,
            playerTwoId: matchedEntries[index * 2 + 1].playerId,
          ),
      ],
      byePlayerIds: byeEntries.map((entry) => entry.playerId).toList(),
    );
  }

  KnockoutRound createRoundFromPlayerIds({
    required int roundNumber,
    required List<String> playerIds,
    required DateTime roundStartsAt,
    required Random random,
  }) {
    final shuffledPlayerIds = [...playerIds]..shuffle(random);
    final matchablePlayerCount = shuffledPlayerIds.length.isEven
        ? shuffledPlayerIds.length
        : shuffledPlayerIds.length - 1;
    final matchedPlayerIds = shuffledPlayerIds
        .take(matchablePlayerCount)
        .toList();
    final byePlayerIds = shuffledPlayerIds.skip(matchablePlayerCount).toList();

    return KnockoutRound(
      roundNumber: roundNumber,
      startsAt: roundStartsAt,
      endsAt: schedule.roundEndsAt(roundStartsAt),
      status: KnockoutRoundStatus.active,
      matches: [
        for (var index = 0; index < matchedPlayerIds.length ~/ 2; index += 1)
          KnockoutMatch(
            id: 'round-$roundNumber-match-${index + 1}',
            roundNumber: roundNumber,
            status: KnockoutMatchStatus.active,
            playerOneId: matchedPlayerIds[index * 2],
            playerTwoId: matchedPlayerIds[index * 2 + 1],
          ),
      ],
      byePlayerIds: byePlayerIds,
    );
  }

  int openingMatchCount(int playerCount) {
    if (playerCount < 2) {
      return 0;
    }

    final lowerPowerOfTwo = nearestLowerPowerOfTwo(playerCount);
    final requiredEliminations = playerCount - lowerPowerOfTwo;

    if (requiredEliminations > 0) {
      return requiredEliminations;
    }

    return playerCount ~/ 2;
  }

  int nearestLowerPowerOfTwo(int value) {
    if (value < 1) {
      return 0;
    }

    var power = 1;
    while (power * 2 <= value) {
      power *= 2;
    }

    return power;
  }
}
