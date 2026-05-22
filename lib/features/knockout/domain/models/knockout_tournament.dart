import 'dart:collection';

import 'knockout_player_entry.dart';
import 'knockout_round.dart';

enum KnockoutTournamentStatus {
  registrationOpen,
  registrationClosed,
  inProgress,
  completed,
}

class KnockoutTournament {
  KnockoutTournament({
    required this.id,
    required this.name,
    required this.entryCostGamePoints,
    required this.tournamentMonth,
    required this.registrationOpensAt,
    required this.registrationClosesAt,
    required this.startsAt,
    this.status = KnockoutTournamentStatus.registrationOpen,
    List<KnockoutPlayerEntry> entries = const [],
    List<KnockoutRound> rounds = const [],
  }) : assert(id.trim().isNotEmpty),
        assert(name.trim().isNotEmpty),
        assert(entryCostGamePoints >= 0),
        assert(registrationOpensAt.isBefore(registrationClosesAt)),
        assert(registrationClosesAt.isBefore(startsAt)),
        entries = UnmodifiableListView(entries),
        rounds = UnmodifiableListView(rounds);

  final String id;
  final String name;
  final int entryCostGamePoints;

  /// Represents the tournament month.
  ///
  /// Expected convention:
  /// - day: 1
  /// - time: 00:00
  /// - local app/backend tournament timezone
  final DateTime tournamentMonth;

  final DateTime registrationOpensAt;
  final DateTime registrationClosesAt;
  final DateTime startsAt;

  final KnockoutTournamentStatus status;
  final List<KnockoutPlayerEntry> entries;
  final List<KnockoutRound> rounds;

  bool get isRegistrationOpen {
    return status == KnockoutTournamentStatus.registrationOpen;
  }

  bool get hasStarted {
    return status == KnockoutTournamentStatus.inProgress;
  }

  bool get isCompleted {
    return status == KnockoutTournamentStatus.completed;
  }

  KnockoutRound? get currentRound {
    for (final round in rounds) {
      if (!round.isCompleted) {
        return round;
      }
    }

    return null;
  }

  KnockoutTournament copyWith({
    String? id,
    String? name,
    int? entryCostGamePoints,
    DateTime? tournamentMonth,
    DateTime? registrationOpensAt,
    DateTime? registrationClosesAt,
    DateTime? startsAt,
    KnockoutTournamentStatus? status,
    List<KnockoutPlayerEntry>? entries,
    List<KnockoutRound>? rounds,
  }) {
    return KnockoutTournament(
      id: id ?? this.id,
      name: name ?? this.name,
      entryCostGamePoints: entryCostGamePoints ?? this.entryCostGamePoints,
      tournamentMonth: tournamentMonth ?? this.tournamentMonth,
      registrationOpensAt: registrationOpensAt ?? this.registrationOpensAt,
      registrationClosesAt: registrationClosesAt ?? this.registrationClosesAt,
      startsAt: startsAt ?? this.startsAt,
      status: status ?? this.status,
      entries: entries ?? this.entries,
      rounds: rounds ?? this.rounds,
    );
  }
}

extension KnockoutTournamentStatusLabel on KnockoutTournamentStatus {
  String get label {
    return switch (this) {
      KnockoutTournamentStatus.registrationOpen => 'Registration open',
      KnockoutTournamentStatus.registrationClosed => 'Registration closed',
      KnockoutTournamentStatus.inProgress => 'In progress',
      KnockoutTournamentStatus.completed => 'Completed',
    };
  }
}