import 'package:stoppy_app/core/backend/json_reader.dart';

import '../../domain/models/knockout_duel_snapshot.dart';
import '../../domain/models/knockout_player_entry.dart';
import '../../domain/models/knockout_player_status.dart';
import '../../domain/models/knockout_tournament_history_entry.dart';
import '../../domain/models/knockout_hall_of_fame_entry.dart';
import 'knockout_persistence_dtos.dart';

final class KnockoutCurrentEntryResponseDto {
  const KnockoutCurrentEntryResponseDto({this.playerEntry});

  final KnockoutPlayerEntryDto? playerEntry;

  factory KnockoutCurrentEntryResponseDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'KnockoutCurrentEntryResponseDto',
    );
    final data = reader.toMap();

    return KnockoutCurrentEntryResponseDto(
      playerEntry: data['playerEntry'] == null
          ? null
          : KnockoutPlayerEntryDto.fromJson(data['playerEntry']),
    );
  }

  KnockoutPlayerEntry? toDomain() => playerEntry?.toDomain();
}

final class KnockoutPlayerStatusDto {
  const KnockoutPlayerStatusDto({required this.state, this.duelSnapshot});

  final KnockoutPlayerTournamentState state;
  final KnockoutDuelSnapshotDto? duelSnapshot;

  factory KnockoutPlayerStatusDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'KnockoutPlayerStatusDto',
    );
    final data = reader.toMap();

    return KnockoutPlayerStatusDto(
      state: _playerStateFromName(reader.requiredString('state')),
      duelSnapshot: data['duelSnapshot'] == null
          ? null
          : KnockoutDuelSnapshotDto.fromJson(data['duelSnapshot']),
    )._validated();
  }

  KnockoutPlayerStatusDto _validated() {
    if (state == KnockoutPlayerTournamentState.activeDuel &&
        duelSnapshot == null) {
      throw const FormatException(
        'Active Knockout player status must include a duel snapshot.',
      );
    }

    if (state != KnockoutPlayerTournamentState.activeDuel &&
        duelSnapshot != null) {
      throw const FormatException(
        'Only active Knockout duel status may include a duel snapshot.',
      );
    }

    return this;
  }

  KnockoutPlayerStatus toDomain() {
    _validated();
    return KnockoutPlayerStatus(
      state: state,
      duelSnapshot: duelSnapshot?.toDomain(),
    );
  }
}

final class KnockoutActiveDuelResponseDto {
  const KnockoutActiveDuelResponseDto({this.duelSnapshot});

  final KnockoutDuelSnapshotDto? duelSnapshot;

  factory KnockoutActiveDuelResponseDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'KnockoutActiveDuelResponseDto',
    );
    final data = reader.toMap();

    return KnockoutActiveDuelResponseDto(
      duelSnapshot: data['duelSnapshot'] == null
          ? null
          : KnockoutDuelSnapshotDto.fromJson(data['duelSnapshot']),
    );
  }

  KnockoutDuelSnapshot? toDomain() => duelSnapshot?.toDomain();
}

final class KnockoutDuelSnapshotDto {
  const KnockoutDuelSnapshotDto({
    required this.tournamentId,
    required this.roundNumber,
    required this.roundEndsAt,
    required this.playerId,
    required this.match,
    this.opponentId,
    required this.playerScore,
    required this.opponentScore,
    required this.playerRunCount,
    required this.opponentRunCount,
    required this.hasBye,
  });

  final String tournamentId;
  final int roundNumber;
  final DateTime roundEndsAt;
  final String playerId;
  final KnockoutMatchDto match;
  final String? opponentId;
  final int playerScore;
  final int opponentScore;
  final int playerRunCount;
  final int opponentRunCount;
  final bool hasBye;

  factory KnockoutDuelSnapshotDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'KnockoutDuelSnapshotDto',
    );

    return KnockoutDuelSnapshotDto(
      tournamentId: reader.requiredString('tournamentId'),
      roundNumber: reader.requiredPositiveInt('roundNumber'),
      roundEndsAt: reader.requiredDateTime('roundEndsAt'),
      playerId: reader.requiredString('playerId'),
      match: KnockoutMatchDto.fromJson(reader.requiredObject('match').toMap()),
      opponentId: _optionalNonBlankString(reader, 'opponentId'),
      playerScore: reader.optionalNonNegativeInt(
        'playerScore',
        defaultValue: 0,
      ),
      opponentScore: reader.optionalNonNegativeInt(
        'opponentScore',
        defaultValue: 0,
      ),
      playerRunCount: reader.optionalNonNegativeInt(
        'playerRunCount',
        defaultValue: 0,
      ),
      opponentRunCount: reader.optionalNonNegativeInt(
        'opponentRunCount',
        defaultValue: 0,
      ),
      hasBye: reader.optionalBool('hasBye', defaultValue: false),
    )._validated();
  }

  KnockoutDuelSnapshotDto _validated() {
    if (match.roundNumber != roundNumber) {
      throw const FormatException(
        'Knockout duel snapshot round must match the embedded match round.',
      );
    }

    final isPlayerOne = playerId == match.playerOneId;
    final isPlayerTwo = playerId == match.playerTwoId;

    if (!isPlayerOne && !isPlayerTwo) {
      throw const FormatException(
        'Knockout duel snapshot player must belong to the embedded match.',
      );
    }

    final expectedOpponentId = isPlayerOne
        ? match.playerTwoId
        : match.playerOneId;
    if (opponentId != expectedOpponentId) {
      throw const FormatException(
        'Knockout duel snapshot opponent must match the embedded match.',
      );
    }

    final expectedPlayerScore = isPlayerOne
        ? match.playerOneScore
        : match.playerTwoScore;
    final expectedOpponentScore = isPlayerOne
        ? match.playerTwoScore
        : match.playerOneScore;
    if (playerScore != expectedPlayerScore ||
        opponentScore != expectedOpponentScore) {
      throw const FormatException(
        'Knockout duel snapshot scores must match the embedded match.',
      );
    }

    final expectedPlayerRunCount = isPlayerOne
        ? match.playerOneRunCount
        : match.playerTwoRunCount;
    final expectedOpponentRunCount = isPlayerOne
        ? match.playerTwoRunCount
        : match.playerOneRunCount;
    if (playerRunCount != expectedPlayerRunCount ||
        opponentRunCount != expectedOpponentRunCount) {
      throw const FormatException(
        'Knockout duel snapshot run counts must match the embedded match.',
      );
    }

    return this;
  }

  KnockoutDuelSnapshot toDomain() {
    _validated();
    return KnockoutDuelSnapshot(
      tournamentId: tournamentId,
      roundNumber: roundNumber,
      roundEndsAt: roundEndsAt,
      playerId: playerId,
      opponentId: opponentId,
      match: match.toDomain(),
      playerScore: playerScore,
      opponentScore: opponentScore,
      playerRunCount: playerRunCount,
      opponentRunCount: opponentRunCount,
      hasBye: hasBye,
    );
  }
}

final class KnockoutHistoryResponseDto {
  const KnockoutHistoryResponseDto({required this.history});

  final List<KnockoutTournamentHistoryEntryDto> history;

  factory KnockoutHistoryResponseDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'KnockoutHistoryResponseDto',
    );

    return KnockoutHistoryResponseDto(
      history: reader
          .optionalObjectList('history')
          .map(
            (item) => KnockoutTournamentHistoryEntryDto.fromJson(item.toMap()),
          )
          .toList(growable: false),
    );
  }

  List<KnockoutTournamentHistoryEntry> toDomain() {
    return history.map((entry) => entry.toDomain()).toList(growable: false);
  }
}

final class KnockoutHallOfFameResponseDto {
  const KnockoutHallOfFameResponseDto({required this.hallOfFame});

  final List<KnockoutHallOfFameEntryDto> hallOfFame;

  factory KnockoutHallOfFameResponseDto.fromJson(Object? json) {
    final reader = JsonReader.fromObject(
      json,
      context: 'KnockoutHallOfFameResponseDto',
    );

    return KnockoutHallOfFameResponseDto(
      hallOfFame: reader
          .optionalObjectList('hallOfFame')
          .map((item) => KnockoutHallOfFameEntryDto.fromJson(item.toMap()))
          .toList(growable: false),
    );
  }

  List<KnockoutHallOfFameEntry> toDomain() {
    return hallOfFame.map((entry) => entry.toDomain()).toList(growable: false);
  }
}

KnockoutPlayerTournamentState _playerStateFromName(String value) {
  for (final state in KnockoutPlayerTournamentState.values) {
    if (state.name == value) {
      return state;
    }
  }
  throw FormatException('Unknown Knockout player status: $value.');
}

String? _optionalNonBlankString(JsonReader reader, String key) {
  final value = reader.optionalString(key);
  if (value == null) {
    return null;
  }
  if (value.trim().isEmpty) {
    throw FormatException('$key must be null or a non-empty string.');
  }
  return value;
}
