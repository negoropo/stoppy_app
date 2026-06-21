import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/knockout/data/dto/knockout_persistence_dtos.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_hall_of_fame_entry.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_match.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_entry.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_records.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_round.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament_history_entry.dart';

void main() {
  test('knockout persisted DTOs round-trip nested tournament state', () {
    final entry = KnockoutPlayerEntry(
      playerId: 'player-1',
      username: 'Tester',
      tournamentId: 'tournament-1',
      registeredAt: DateTime.utc(2026, 6, 1),
      accountCreatedAt: DateTime.utc(2026, 1, 1),
      entryCostGamePoints: 25,
    );
    final match = KnockoutMatch(
      id: 'match-1',
      roundNumber: 1,
      status: KnockoutMatchStatus.active,
      playerOneId: 'player-1',
      playerTwoId: 'player-2',
      playerOneScore: 100,
      playerTwoScore: 90,
      playerOneRunCount: 1,
      playerTwoRunCount: 1,
    );
    final round = KnockoutRound(
      roundNumber: 1,
      startsAt: DateTime.utc(2026, 6, 1),
      endsAt: DateTime.utc(2026, 6, 1, 23, 59),
      status: KnockoutRoundStatus.active,
      matches: [match],
    );
    final tournament = KnockoutTournament(
      id: 'tournament-1',
      name: 'June Knockout',
      entryCostGamePoints: 25,
      tournamentMonth: DateTime.utc(2026, 6, 1),
      registrationOpensAt: DateTime.utc(2026, 5, 1),
      registrationClosesAt: DateTime.utc(2026, 5, 31),
      startsAt: DateTime.utc(2026, 6, 1),
      status: KnockoutTournamentStatus.inProgress,
      entries: [entry],
      rounds: [round],
    );

    final decodedTournament = KnockoutTournamentDto.fromJson(
      KnockoutTournamentDto.fromDomain(tournament).toJson(),
    ).toDomain();

    expect(decodedTournament.currentRound?.matches.single.id, 'match-1');
    expect(decodedTournament.entries.single.username, 'Tester');

    final history = KnockoutTournamentHistoryEntry(
      tournamentId: 'tournament-1',
      tournamentName: 'June Knockout',
      tournamentMonth: DateTime.utc(2026, 6, 1),
      playerId: 'player-1',
      outcome: KnockoutTournamentOutcome.eliminated,
      finalRoundNumber: 2,
      completedAt: DateTime.utc(2026, 6, 5),
    );
    final records = KnockoutPlayerRecords(
      playerId: 'player-1',
      tournamentsPlayed: 1,
      highestRoundReached: 2,
      totalDuelsPlayed: 2,
      totalDuelsWon: 1,
    );
    final hallOfFame = KnockoutHallOfFameEntry(
      playerId: 'player-1',
      displayName: 'Tester',
      titlesWon: 1,
      wonTournamentMonths: [DateTime.utc(2026, 6, 1)],
    );

    expect(
      KnockoutTournamentHistoryEntryDto.fromJson(
        KnockoutTournamentHistoryEntryDto.fromDomain(history).toJson(),
      ).toDomain().finalRoundNumber,
      2,
    );
    expect(
      KnockoutPlayerRecordsDto.fromJson(
        KnockoutPlayerRecordsDto.fromDomain(records).toJson(),
      ).toDomain().totalDuelsWon,
      1,
    );
    expect(
      KnockoutHallOfFameEntryDto.fromJson(
        KnockoutHallOfFameEntryDto.fromDomain(hallOfFame).toJson(),
      ).toDomain().titlesWon,
      1,
    );
  });
}
