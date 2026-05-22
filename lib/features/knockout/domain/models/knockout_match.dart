enum KnockoutMatchStatus {
  pending,
  active,
  completed,
  voided,
}

class KnockoutMatch {
  const KnockoutMatch({
    required this.id,
    required this.roundNumber,
    this.status = KnockoutMatchStatus.pending,
    this.playerOneId,
    this.playerTwoId,
    this.playerOneScore = 0,
    this.playerTwoScore = 0,
    this.playerOneRunCount = 0,
    this.playerTwoRunCount = 0,
    this.winnerPlayerId,
    this.repechageWinnerPlayerId,
  }) : assert(id != ''),
        assert(roundNumber > 0),
        assert(playerOneScore >= 0),
        assert(playerTwoScore >= 0),
        assert(playerOneRunCount >= 0),
        assert(playerTwoRunCount >= 0);

  final String id;
  final int roundNumber;

  final KnockoutMatchStatus status;

  final String? playerOneId;
  final String? playerTwoId;

  final int playerOneScore;
  final int playerTwoScore;

  final int playerOneRunCount;
  final int playerTwoRunCount;

  /// Winner from the duel itself.
  final String? winnerPlayerId;

  /// Winner inserted through repechage when no natural winner exists.
  final String? repechageWinnerPlayerId;

  bool get hasTwoPlayers {
    return playerOneId != null && playerTwoId != null;
  }

  bool get isBye {
    return playerOneId != null && playerTwoId == null;
  }

  bool get hasAnyRuns {
    return playerOneRunCount > 0 || playerTwoRunCount > 0;
  }

  bool get hasNoRuns {
    return !hasAnyRuns;
  }

  bool get requiresRepechage {
    return hasTwoPlayers && hasNoRuns;
  }

  bool get hasWinner {
    return winnerPlayerId != null || repechageWinnerPlayerId != null;
  }

  bool get isCompleted {
    return status == KnockoutMatchStatus.completed;
  }

  String? get advancingPlayerId {
    return winnerPlayerId ?? repechageWinnerPlayerId;
  }

  KnockoutMatch copyWith({
    String? id,
    int? roundNumber,
    KnockoutMatchStatus? status,
    String? playerOneId,
    String? playerTwoId,
    int? playerOneScore,
    int? playerTwoScore,
    int? playerOneRunCount,
    int? playerTwoRunCount,
    String? winnerPlayerId,
    String? repechageWinnerPlayerId,
  }) {
    return KnockoutMatch(
      id: id ?? this.id,
      roundNumber: roundNumber ?? this.roundNumber,
      status: status ?? this.status,
      playerOneId: playerOneId ?? this.playerOneId,
      playerTwoId: playerTwoId ?? this.playerTwoId,
      playerOneScore: playerOneScore ?? this.playerOneScore,
      playerTwoScore: playerTwoScore ?? this.playerTwoScore,
      playerOneRunCount: playerOneRunCount ?? this.playerOneRunCount,
      playerTwoRunCount: playerTwoRunCount ?? this.playerTwoRunCount,
      winnerPlayerId: winnerPlayerId ?? this.winnerPlayerId,
      repechageWinnerPlayerId:
      repechageWinnerPlayerId ?? this.repechageWinnerPlayerId,
    );
  }
}

extension KnockoutMatchStatusLabel on KnockoutMatchStatus {
  String get label {
    return switch (this) {
      KnockoutMatchStatus.pending => 'Pending',
      KnockoutMatchStatus.active => 'Active',
      KnockoutMatchStatus.completed => 'Completed',
      KnockoutMatchStatus.voided => 'Voided',
    };
  }
}