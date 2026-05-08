import 'dart:collection';

class LeagueDivisionSettlement {
  LeagueDivisionSettlement({
    required this.divisionNumber,
    List<String> promotedPlayerIds = const [],
    List<String> relegatedPlayerIds = const [],
    List<String> keptPlayerIds = const [],
    List<String> lostReservationPlayerIds = const [],
    this.closedDivision = false,
  }) : assert(divisionNumber > 0),
       promotedPlayerIds = UnmodifiableListView(promotedPlayerIds),
       relegatedPlayerIds = UnmodifiableListView(relegatedPlayerIds),
       keptPlayerIds = UnmodifiableListView(keptPlayerIds),
       lostReservationPlayerIds = UnmodifiableListView(
         lostReservationPlayerIds,
       ),
       assert(
         _hasUniquePlayers(
           promotedPlayerIds,
           relegatedPlayerIds,
           keptPlayerIds,
         ),
         'A player cannot exist in multiple settlement groups.',
       );

  final int divisionNumber;

  final List<String> promotedPlayerIds;
  final List<String> relegatedPlayerIds;
  final List<String> keptPlayerIds;

  /// Players losing reserved-slot rights
  /// for next season.
  final List<String> lostReservationPlayerIds;

  /// True when the division disappears next season.
  final bool closedDivision;

  static bool _hasUniquePlayers(
    List<String> promoted,
    List<String> relegated,
    List<String> kept,
  ) {
    final all = [...promoted, ...relegated, ...kept];

    return all.toSet().length == all.length;
  }
}
