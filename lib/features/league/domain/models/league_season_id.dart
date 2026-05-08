class LeagueSeasonId {
  const LeagueSeasonId({required this.weekStartDate});

  final DateTime weekStartDate;

  factory LeagueSeasonId.fromDate(DateTime date) {
    final localDate = date.toLocal();
    final midnight = DateTime(localDate.year, localDate.month, localDate.day);
    final monday = midnight.subtract(Duration(days: localDate.weekday - 1));

    return LeagueSeasonId(weekStartDate: monday);
  }

  String get value {
    final year = weekStartDate.year.toString().padLeft(4, '0');
    final month = weekStartDate.month.toString().padLeft(2, '0');
    final day = weekStartDate.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
