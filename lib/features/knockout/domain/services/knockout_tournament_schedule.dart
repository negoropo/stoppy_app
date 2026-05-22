import '../models/knockout_tournament.dart';

class KnockoutTournamentSchedule {
  const KnockoutTournamentSchedule();

  static const int entryCostGamePoints = 25;

  KnockoutTournament createRegistrationTournament(DateTime now) {
    final localNow = now.toLocal();

    // Mock/client-side rule:
    // expose registration for the next monthly tournament.
    //
    // TODO: Future backend must be the authority for:
    // - Europe/Lisbon timezone
    // - exact previous tournament end time
    // - exact monthly registration opening window
    final tournamentMonth = DateTime(localNow.year, localNow.month + 1);

    final registrationOpensAt = DateTime(localNow.year, localNow.month);
    final startsAt = tournamentMonth;
    final registrationClosesAt = startsAt.subtract(const Duration(minutes: 1));

    return KnockoutTournament(
      id: monthId(tournamentMonth),
      name: '${_monthName(tournamentMonth.month)} Knockout',
      entryCostGamePoints: entryCostGamePoints,
      tournamentMonth: tournamentMonth,
      registrationOpensAt: registrationOpensAt,
      registrationClosesAt: registrationClosesAt,
      startsAt: startsAt,
      status: registrationStatus(
        now: localNow,
        registrationOpensAt: registrationOpensAt,
        registrationClosesAt: registrationClosesAt,
        startsAt: startsAt,
      ),
    );
  }

  KnockoutTournamentStatus registrationStatus({
    required DateTime now,
    required DateTime registrationOpensAt,
    required DateTime registrationClosesAt,
    required DateTime startsAt,
  }) {
    if (!now.isBefore(startsAt)) {
      return KnockoutTournamentStatus.inProgress;
    }

    // Registration is modeled as a closed interval:
    // registrationOpensAt <= now <= registrationClosesAt.
    final isInsideRegistrationWindow =
        !now.isBefore(registrationOpensAt) &&
            !now.isAfter(registrationClosesAt);

    if (isInsideRegistrationWindow) {
      return KnockoutTournamentStatus.registrationOpen;
    }

    return KnockoutTournamentStatus.registrationClosed;
  }

  DateTime roundEndsAt(DateTime roundStart) {
    final local = roundStart.toLocal();

    // Mock/client-side rule:
    // each duel settles at 23:59 local device time.
    //
    // TODO: Future backend must enforce 23:59 Europe/Lisbon,
    // including daylight-saving changes.
    return DateTime(local.year, local.month, local.day, 23, 59);
  }

  String monthId(DateTime month) {
    final year = month.year.toString().padLeft(4, '0');
    final monthValue = month.month.toString().padLeft(2, '0');

    return '$year-$monthValue';
  }

  String _monthName(int month) {
    return const [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ][month - 1];
  }
}