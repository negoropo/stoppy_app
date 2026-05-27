import 'knockout_duel_snapshot.dart';

enum KnockoutPlayerTournamentState {
  notRegistered,
  registeredWaitingStart,
  activeDuel,
  byeWaitingNextRound,
  eliminated,
  champion,
  tournamentCompleted,
}

class KnockoutPlayerStatus {
  const KnockoutPlayerStatus({required this.state, this.duelSnapshot})
    : assert(
        state != KnockoutPlayerTournamentState.activeDuel ||
            duelSnapshot != null,
        'Active duel status must include a duel snapshot.',
      );

  final KnockoutPlayerTournamentState state;
  final KnockoutDuelSnapshot? duelSnapshot;

  bool get canPlayTournamentRun {
    return state == KnockoutPlayerTournamentState.activeDuel;
  }

  String get title {
    return switch (state) {
      KnockoutPlayerTournamentState.notRegistered => 'Not registered',
      KnockoutPlayerTournamentState.registeredWaitingStart =>
        'Registered - waiting for tournament start',
      KnockoutPlayerTournamentState.activeDuel => 'Active duel',
      KnockoutPlayerTournamentState.byeWaitingNextRound =>
        'Bye - waiting for next round',
      KnockoutPlayerTournamentState.eliminated => 'Eliminated',
      KnockoutPlayerTournamentState.champion => 'Tournament champion',
      KnockoutPlayerTournamentState.tournamentCompleted =>
        'Tournament completed',
    };
  }

  String get description {
    return switch (state) {
      KnockoutPlayerTournamentState.notRegistered =>
        'Register while the monthly window is open.',
      KnockoutPlayerTournamentState.registeredWaitingStart =>
        'Your duel will appear when the tournament starts.',
      KnockoutPlayerTournamentState.activeDuel =>
        'Play tournament runs before the daily settlement time.',
      KnockoutPlayerTournamentState.byeWaitingNextRound =>
        'You advanced automatically and are waiting for the next round.',
      KnockoutPlayerTournamentState.eliminated =>
        'Your tournament run has ended.',
      KnockoutPlayerTournamentState.champion =>
        'You won this monthly Knockout.',
      KnockoutPlayerTournamentState.tournamentCompleted =>
        'This monthly Knockout has finished.',
    };
  }
}
