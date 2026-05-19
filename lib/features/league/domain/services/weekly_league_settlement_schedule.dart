import '../models/league_season_id.dart';

class WeeklyLeagueSettlementSchedule {
  const WeeklyLeagueSettlementSchedule();

  static const int settlementWeekday = DateTime.sunday;
  static const int settlementHour = 23;
  static const int settlementMinute = 59;

  bool isSettlementDue({
    required DateTime now,
    required LeagueSeasonId seasonId,
  }) {
    final localNow = now.toLocal();

    return !localNow.isBefore(settlementTimeForSeason(seasonId));
  }

  DateTime settlementTimeForSeason(LeagueSeasonId seasonId) {
    // League seasons close at Sunday 23:59 in the app's local runtime clock.
    // The production backend should evaluate this with an explicit
    // Europe/Lisbon clock so DST and anti-cheat validation are centralized.
    return seasonId.weekStartDate.add(
      const Duration(
        days: settlementWeekday - DateTime.monday,
        hours: settlementHour,
        minutes: settlementMinute,
      ),
    );
  }
}
