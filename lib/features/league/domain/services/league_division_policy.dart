import '../models/league_division.dart';
import '../models/league_player_entry.dart';

class LeagueDivisionPolicy {
  const LeagueDivisionPolicy();

  static const int firstDivisionCapacity = 10;
  static const int weeklyEntryCostGamePoints = 10;

  int capacityForDivision(int divisionNumber) {
    if (divisionNumber < 1) {
      throw ArgumentError.value(
        divisionNumber,
        'divisionNumber',
        'Division numbers start at 1.',
      );
    }

    return firstDivisionCapacity * (1 << (divisionNumber - 1));
  }

  LeagueDivision placeNewPlayer({
    required List<LeagueDivision> divisions,
    required List<LeaguePlayerEntry> entries,
  }) {
    if (divisions.isEmpty) {
      return const LeagueDivision(number: 1, capacity: firstDivisionCapacity);
    }

    final sortedDivisions = [...divisions]
      ..sort((a, b) => a.number.compareTo(b.number));

    final lowestDivision = sortedDivisions.last;

    final usedSlots = entries
        .where(
          (entry) =>
              entry.divisionNumber == lowestDivision.number &&
              entry.hasReservedSlot,
        )
        .length;

    if (usedSlots < lowestDivision.capacity) {
      return lowestDivision;
    }

    return lowestDivision.nextDivision();
  }

  /// Marks a player as active for the weekly league.
  ///
  /// GP validation and deduction must happen outside this policy because
  /// PlayerProfile owns the player's Game Points balance.
  LeaguePlayerEntry activateWeeklyEntry(LeaguePlayerEntry entry) {
    return entry.markEntryPaid();
  }
}
