import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/json_reader.dart';

import '../../domain/models/knockout_hall_of_fame_entry.dart';
import '../../domain/models/knockout_match.dart';
import '../../domain/models/knockout_player_entry.dart';
import '../../domain/models/knockout_player_records.dart';
import '../../domain/models/knockout_round.dart';
import '../../domain/models/knockout_tournament.dart';
import '../../domain/models/knockout_tournament_history_entry.dart';

class KnockoutPlayerEntryDto {
  const KnockoutPlayerEntryDto({
    required this.playerId,
    required this.username,
    required this.tournamentId,
    required this.registeredAt,
    required this.accountCreatedAt,
    required this.entryCostGamePoints,
    required this.lifetimeRunCount,
    required this.lifetimeAverageRunScore,
  });

  final String playerId;
  final String username;
  final String tournamentId;
  final DateTime registeredAt;
  final DateTime accountCreatedAt;
  final int entryCostGamePoints;
  final int lifetimeRunCount;
  final double lifetimeAverageRunScore;

  factory KnockoutPlayerEntryDto.fromDomain(KnockoutPlayerEntry entry) {
    return KnockoutPlayerEntryDto(
      playerId: entry.playerId,
      username: entry.username,
      tournamentId: entry.tournamentId,
      registeredAt: entry.registeredAt,
      accountCreatedAt: entry.accountCreatedAt,
      entryCostGamePoints: entry.entryCostGamePoints,
      lifetimeRunCount: entry.lifetimeRunCount,
      lifetimeAverageRunScore: entry.lifetimeAverageRunScore,
    );
  }

  factory KnockoutPlayerEntryDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'KnockoutPlayerEntryDto',
    );
    return KnockoutPlayerEntryDto(
      playerId: reader.requiredString('playerId'),
      username: reader.requiredString('username'),
      tournamentId: reader.requiredString('tournamentId'),
      registeredAt: reader.requiredDateTime('registeredAt'),
      accountCreatedAt: reader.requiredDateTime('accountCreatedAt'),
      entryCostGamePoints: reader.requiredNonNegativeInt('entryCostGamePoints'),
      lifetimeRunCount: reader.optionalNonNegativeInt(
        'lifetimeRunCount',
        defaultValue: 0,
      ),
      lifetimeAverageRunScore: reader.optionalNonNegativeDouble(
        'lifetimeAverageRunScore',
        defaultValue: 0,
      ),
    );
  }

  KnockoutPlayerEntry toDomain() => KnockoutPlayerEntry(
    playerId: playerId,
    username: username,
    tournamentId: tournamentId,
    registeredAt: registeredAt,
    accountCreatedAt: accountCreatedAt,
    entryCostGamePoints: entryCostGamePoints,
    lifetimeRunCount: lifetimeRunCount,
    lifetimeAverageRunScore: lifetimeAverageRunScore,
  );

  Map<String, Object?> toJson() => {
    'playerId': playerId,
    'username': username,
    'tournamentId': tournamentId,
    'registeredAt': registeredAt.toIso8601String(),
    'accountCreatedAt': accountCreatedAt.toIso8601String(),
    'entryCostGamePoints': entryCostGamePoints,
    'lifetimeRunCount': lifetimeRunCount,
    'lifetimeAverageRunScore': lifetimeAverageRunScore,
  };
}

class KnockoutMatchDto {
  const KnockoutMatchDto({
    required this.id,
    required this.roundNumber,
    required this.status,
    this.playerOneId,
    this.playerTwoId,
    required this.playerOneScore,
    required this.playerTwoScore,
    required this.playerOneRunCount,
    required this.playerTwoRunCount,
    this.winnerPlayerId,
    this.repechageWinnerPlayerId,
  });

  final String id;
  final int roundNumber;
  final KnockoutMatchStatus status;
  final String? playerOneId;
  final String? playerTwoId;
  final int playerOneScore;
  final int playerTwoScore;
  final int playerOneRunCount;
  final int playerTwoRunCount;
  final String? winnerPlayerId;
  final String? repechageWinnerPlayerId;

  factory KnockoutMatchDto.fromDomain(KnockoutMatch match) {
    return KnockoutMatchDto(
      id: match.id,
      roundNumber: match.roundNumber,
      status: match.status,
      playerOneId: match.playerOneId,
      playerTwoId: match.playerTwoId,
      playerOneScore: match.playerOneScore,
      playerTwoScore: match.playerTwoScore,
      playerOneRunCount: match.playerOneRunCount,
      playerTwoRunCount: match.playerTwoRunCount,
      winnerPlayerId: match.winnerPlayerId,
      repechageWinnerPlayerId: match.repechageWinnerPlayerId,
    );
  }

  factory KnockoutMatchDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(json, context: 'KnockoutMatchDto');
    return KnockoutMatchDto(
      id: reader.requiredString('id'),
      roundNumber: reader.requiredPositiveInt('roundNumber'),
      status: _matchStatusFromName(reader.requiredString('status')),
      playerOneId: reader.optionalString('playerOneId'),
      playerTwoId: reader.optionalString('playerTwoId'),
      playerOneScore: reader.optionalNonNegativeInt(
        'playerOneScore',
        defaultValue: 0,
      ),
      playerTwoScore: reader.optionalNonNegativeInt(
        'playerTwoScore',
        defaultValue: 0,
      ),
      playerOneRunCount: reader.optionalNonNegativeInt(
        'playerOneRunCount',
        defaultValue: 0,
      ),
      playerTwoRunCount: reader.optionalNonNegativeInt(
        'playerTwoRunCount',
        defaultValue: 0,
      ),
      winnerPlayerId: reader.optionalString('winnerPlayerId'),
      repechageWinnerPlayerId: reader.optionalString('repechageWinnerPlayerId'),
    );
  }

  KnockoutMatch toDomain() => KnockoutMatch(
    id: id,
    roundNumber: roundNumber,
    status: status,
    playerOneId: playerOneId,
    playerTwoId: playerTwoId,
    playerOneScore: playerOneScore,
    playerTwoScore: playerTwoScore,
    playerOneRunCount: playerOneRunCount,
    playerTwoRunCount: playerTwoRunCount,
    winnerPlayerId: winnerPlayerId,
    repechageWinnerPlayerId: repechageWinnerPlayerId,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'roundNumber': roundNumber,
    'status': status.name,
    'playerOneId': playerOneId,
    'playerTwoId': playerTwoId,
    'playerOneScore': playerOneScore,
    'playerTwoScore': playerTwoScore,
    'playerOneRunCount': playerOneRunCount,
    'playerTwoRunCount': playerTwoRunCount,
    'winnerPlayerId': winnerPlayerId,
    'repechageWinnerPlayerId': repechageWinnerPlayerId,
  };
}

class KnockoutRoundDto {
  const KnockoutRoundDto({
    required this.roundNumber,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.matches,
    required this.byePlayerIds,
  });

  final int roundNumber;
  final DateTime startsAt;
  final DateTime endsAt;
  final KnockoutRoundStatus status;
  final List<KnockoutMatchDto> matches;
  final List<String> byePlayerIds;

  factory KnockoutRoundDto.fromDomain(KnockoutRound round) {
    return KnockoutRoundDto(
      roundNumber: round.roundNumber,
      startsAt: round.startsAt,
      endsAt: round.endsAt,
      status: round.status,
      matches: round.matches.map(KnockoutMatchDto.fromDomain).toList(),
      byePlayerIds: round.byePlayerIds,
    );
  }

  factory KnockoutRoundDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(json, context: 'KnockoutRoundDto');
    return KnockoutRoundDto(
      roundNumber: reader.requiredPositiveInt('roundNumber'),
      startsAt: reader.requiredDateTime('startsAt'),
      endsAt: reader.requiredDateTime('endsAt'),
      status: _roundStatusFromName(reader.requiredString('status')),
      matches: reader
          .requiredObjectList('matches')
          .map((item) => KnockoutMatchDto.fromJson(item.toMap()))
          .toList(growable: false),
      byePlayerIds: reader.optionalStringList('byePlayerIds'),
    );
  }

  KnockoutRound toDomain() => KnockoutRound(
    roundNumber: roundNumber,
    startsAt: startsAt,
    endsAt: endsAt,
    status: status,
    matches: matches.map((match) => match.toDomain()).toList(),
    byePlayerIds: byePlayerIds,
  );

  Map<String, Object?> toJson() => {
    'roundNumber': roundNumber,
    'startsAt': startsAt.toIso8601String(),
    'endsAt': endsAt.toIso8601String(),
    'status': status.name,
    'matches': matches.map((match) => match.toJson()).toList(),
    'byePlayerIds': byePlayerIds,
  };
}

class KnockoutTournamentDto {
  const KnockoutTournamentDto({
    required this.id,
    required this.name,
    required this.entryCostGamePoints,
    required this.tournamentMonth,
    required this.registrationOpensAt,
    required this.registrationClosesAt,
    required this.startsAt,
    required this.status,
    required this.entries,
    required this.rounds,
    required this.eliminatedPlayerIds,
    this.championPlayerId,
  });

  final String id;
  final String name;
  final int entryCostGamePoints;
  final DateTime tournamentMonth;
  final DateTime registrationOpensAt;
  final DateTime registrationClosesAt;
  final DateTime startsAt;
  final KnockoutTournamentStatus status;
  final List<KnockoutPlayerEntryDto> entries;
  final List<KnockoutRoundDto> rounds;
  final List<String> eliminatedPlayerIds;
  final String? championPlayerId;

  factory KnockoutTournamentDto.fromDomain(KnockoutTournament tournament) {
    return KnockoutTournamentDto(
      id: tournament.id,
      name: tournament.name,
      entryCostGamePoints: tournament.entryCostGamePoints,
      tournamentMonth: tournament.tournamentMonth,
      registrationOpensAt: tournament.registrationOpensAt,
      registrationClosesAt: tournament.registrationClosesAt,
      startsAt: tournament.startsAt,
      status: tournament.status,
      entries: tournament.entries
          .map(KnockoutPlayerEntryDto.fromDomain)
          .toList(),
      rounds: tournament.rounds.map(KnockoutRoundDto.fromDomain).toList(),
      eliminatedPlayerIds: tournament.eliminatedPlayerIds,
      championPlayerId: tournament.championPlayerId,
    );
  }

  factory KnockoutTournamentDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'KnockoutTournamentDto',
    );
    return KnockoutTournamentDto(
      id: reader.requiredString('id'),
      name: reader.requiredString('name'),
      entryCostGamePoints: reader.requiredNonNegativeInt('entryCostGamePoints'),
      tournamentMonth: reader.requiredDateTime('tournamentMonth'),
      registrationOpensAt: reader.requiredDateTime('registrationOpensAt'),
      registrationClosesAt: reader.requiredDateTime('registrationClosesAt'),
      startsAt: reader.requiredDateTime('startsAt'),
      status: _tournamentStatusFromName(reader.requiredString('status')),
      entries: reader
          .requiredObjectList('entries')
          .map((item) => KnockoutPlayerEntryDto.fromJson(item.toMap()))
          .toList(growable: false),
      rounds: reader
          .requiredObjectList('rounds')
          .map((item) => KnockoutRoundDto.fromJson(item.toMap()))
          .toList(growable: false),
      eliminatedPlayerIds: reader.optionalStringList('eliminatedPlayerIds'),
      championPlayerId: reader.optionalString('championPlayerId'),
    );
  }

  KnockoutTournament toDomain() => KnockoutTournament(
    id: id,
    name: name,
    entryCostGamePoints: entryCostGamePoints,
    tournamentMonth: tournamentMonth,
    registrationOpensAt: registrationOpensAt,
    registrationClosesAt: registrationClosesAt,
    startsAt: startsAt,
    status: status,
    entries: entries.map((entry) => entry.toDomain()).toList(),
    rounds: rounds.map((round) => round.toDomain()).toList(),
    eliminatedPlayerIds: eliminatedPlayerIds,
    championPlayerId: championPlayerId,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'entryCostGamePoints': entryCostGamePoints,
    'tournamentMonth': tournamentMonth.toIso8601String(),
    'registrationOpensAt': registrationOpensAt.toIso8601String(),
    'registrationClosesAt': registrationClosesAt.toIso8601String(),
    'startsAt': startsAt.toIso8601String(),
    'status': status.name,
    'entries': entries.map((entry) => entry.toJson()).toList(),
    'rounds': rounds.map((round) => round.toJson()).toList(),
    'eliminatedPlayerIds': eliminatedPlayerIds,
    'championPlayerId': championPlayerId,
  };
}

class KnockoutTournamentHistoryEntryDto {
  const KnockoutTournamentHistoryEntryDto({
    required this.tournamentId,
    required this.tournamentName,
    required this.tournamentMonth,
    required this.playerId,
    this.playerUsername,
    required this.outcome,
    required this.finalRoundNumber,
    required this.completedAt,
  });

  final String tournamentId;
  final String tournamentName;
  final DateTime tournamentMonth;
  final String playerId;
  final String? playerUsername;
  final KnockoutTournamentOutcome outcome;
  final int finalRoundNumber;
  final DateTime completedAt;

  factory KnockoutTournamentHistoryEntryDto.fromDomain(
    KnockoutTournamentHistoryEntry entry,
  ) {
    return KnockoutTournamentHistoryEntryDto(
      tournamentId: entry.tournamentId,
      tournamentName: entry.tournamentName,
      tournamentMonth: entry.tournamentMonth,
      playerId: entry.playerId,
      playerUsername: entry.playerUsername,
      outcome: entry.outcome,
      finalRoundNumber: entry.finalRoundNumber,
      completedAt: entry.completedAt,
    );
  }

  factory KnockoutTournamentHistoryEntryDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'KnockoutTournamentHistoryEntryDto',
    );
    return KnockoutTournamentHistoryEntryDto(
      tournamentId: reader.requiredString('tournamentId'),
      tournamentName: reader.requiredString('tournamentName'),
      tournamentMonth: reader.requiredDateTime('tournamentMonth'),
      playerId: reader.requiredString('playerId'),
      playerUsername: reader.optionalString('playerUsername'),
      outcome: _historyOutcomeFromName(reader.requiredString('outcome')),
      finalRoundNumber: reader.requiredPositiveInt('finalRoundNumber'),
      completedAt: reader.requiredDateTime('completedAt'),
    );
  }

  KnockoutTournamentHistoryEntry toDomain() => KnockoutTournamentHistoryEntry(
    tournamentId: tournamentId,
    tournamentName: tournamentName,
    tournamentMonth: tournamentMonth,
    playerId: playerId,
    playerUsername: playerUsername,
    outcome: outcome,
    finalRoundNumber: finalRoundNumber,
    completedAt: completedAt,
  );

  Map<String, Object?> toJson() => {
    'tournamentId': tournamentId,
    'tournamentName': tournamentName,
    'tournamentMonth': tournamentMonth.toIso8601String(),
    'playerId': playerId,
    'playerUsername': playerUsername,
    'outcome': outcome.name,
    'finalRoundNumber': finalRoundNumber,
    'completedAt': completedAt.toIso8601String(),
  };
}

class KnockoutPlayerRecordsDto {
  const KnockoutPlayerRecordsDto({
    required this.playerId,
    required this.tournamentsPlayed,
    required this.tournamentsWon,
    required this.highestRoundReached,
    required this.totalDuelsPlayed,
    required this.totalDuelsWon,
  });

  final String playerId;
  final int tournamentsPlayed;
  final int tournamentsWon;
  final int highestRoundReached;
  final int totalDuelsPlayed;
  final int totalDuelsWon;

  factory KnockoutPlayerRecordsDto.fromDomain(KnockoutPlayerRecords records) {
    return KnockoutPlayerRecordsDto(
      playerId: records.playerId,
      tournamentsPlayed: records.tournamentsPlayed,
      tournamentsWon: records.tournamentsWon,
      highestRoundReached: records.highestRoundReached,
      totalDuelsPlayed: records.totalDuelsPlayed,
      totalDuelsWon: records.totalDuelsWon,
    );
  }

  factory KnockoutPlayerRecordsDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'KnockoutPlayerRecordsDto',
    );
    return KnockoutPlayerRecordsDto(
      playerId: reader.requiredString('playerId'),
      tournamentsPlayed: reader.requiredNonNegativeInt('tournamentsPlayed'),
      tournamentsWon: reader.requiredNonNegativeInt('tournamentsWon'),
      highestRoundReached: reader.requiredNonNegativeInt('highestRoundReached'),
      totalDuelsPlayed: reader.requiredNonNegativeInt('totalDuelsPlayed'),
      totalDuelsWon: reader.requiredNonNegativeInt('totalDuelsWon'),
    );
  }

  KnockoutPlayerRecords toDomain() => KnockoutPlayerRecords(
    playerId: playerId,
    tournamentsPlayed: tournamentsPlayed,
    tournamentsWon: tournamentsWon,
    highestRoundReached: highestRoundReached,
    totalDuelsPlayed: totalDuelsPlayed,
    totalDuelsWon: totalDuelsWon,
  );

  Map<String, Object?> toJson() => {
    'playerId': playerId,
    'tournamentsPlayed': tournamentsPlayed,
    'tournamentsWon': tournamentsWon,
    'highestRoundReached': highestRoundReached,
    'totalDuelsPlayed': totalDuelsPlayed,
    'totalDuelsWon': totalDuelsWon,
  };
}

class KnockoutHallOfFameEntryDto {
  const KnockoutHallOfFameEntryDto({
    required this.playerId,
    required this.displayName,
    required this.titlesWon,
    required this.wonTournamentMonths,
  });

  final String playerId;
  final String displayName;
  final int titlesWon;
  final List<DateTime> wonTournamentMonths;

  factory KnockoutHallOfFameEntryDto.fromDomain(KnockoutHallOfFameEntry entry) {
    return KnockoutHallOfFameEntryDto(
      playerId: entry.playerId,
      displayName: entry.displayName,
      titlesWon: entry.titlesWon,
      wonTournamentMonths: entry.wonTournamentMonths,
    );
  }

  factory KnockoutHallOfFameEntryDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'KnockoutHallOfFameEntryDto',
    );

    final titlesWon = reader.requiredPositiveInt('titlesWon');
    final wonTournamentMonths = reader.optionalDateTimeList(
      'wonTournamentMonths',
    );

    if (wonTournamentMonths.isNotEmpty &&
        wonTournamentMonths.length != titlesWon) {
      throw ApiException(
        const ApiError(
          code: ApiErrorCode.malformedPayload,
          message:
              'KnockoutHallOfFameEntryDto.wonTournamentMonths length must match titlesWon.',
        ),
      );
    }

    return KnockoutHallOfFameEntryDto(
      playerId: reader.requiredString('playerId'),
      displayName: reader.requiredString('displayName'),
      titlesWon: titlesWon,
      wonTournamentMonths: wonTournamentMonths,
    );
  }

  KnockoutHallOfFameEntry toDomain() => KnockoutHallOfFameEntry(
    playerId: playerId,
    displayName: displayName,
    titlesWon: titlesWon,
    wonTournamentMonths: wonTournamentMonths,
  );

  Map<String, Object?> toJson() => {
    'playerId': playerId,
    'displayName': displayName,
    'titlesWon': titlesWon,
    'wonTournamentMonths': wonTournamentMonths
        .map((month) => month.toIso8601String())
        .toList(),
  };
}

KnockoutMatchStatus _matchStatusFromName(String value) {
  return _enumByName(KnockoutMatchStatus.values, value, 'match status');
}

KnockoutRoundStatus _roundStatusFromName(String value) {
  return _enumByName(KnockoutRoundStatus.values, value, 'round status');
}

KnockoutTournamentStatus _tournamentStatusFromName(String value) {
  return _enumByName(
    KnockoutTournamentStatus.values,
    value,
    'tournament status',
  );
}

KnockoutTournamentOutcome _historyOutcomeFromName(String value) {
  return _enumByName(
    KnockoutTournamentOutcome.values,
    value,
    'tournament outcome',
  );
}

T _enumByName<T extends Enum>(List<T> values, String value, String label) {
  for (final candidate in values) {
    if (candidate.name == value) {
      return candidate;
    }
  }
  throw FormatException('Unknown $label: $value');
}
