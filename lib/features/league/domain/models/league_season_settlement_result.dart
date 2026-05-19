import 'dart:collection';

import 'league_division_settlement.dart';
import 'league_season_id.dart';

class LeagueSeasonSettlementResult {
  LeagueSeasonSettlementResult({
    required this.seasonId,
    required this.settledAt,
    required this.executed,
    List<LeagueDivisionSettlement> divisionSettlements = const [],
  }) : divisionSettlements = UnmodifiableListView(divisionSettlements);

  final LeagueSeasonId seasonId;
  final DateTime settledAt;
  final bool executed;
  final List<LeagueDivisionSettlement> divisionSettlements;
}
