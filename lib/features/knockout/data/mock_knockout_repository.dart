import 'dart:math';

import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_duel_score.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_duel_snapshot.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_match.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_entry.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_registration_result.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_round.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_run.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament.dart';
import 'package:stoppy_app/features/knockout/domain/repositories/knockout_repository.dart';
import 'package:stoppy_app/features/knockout/domain/services/knockout_bracket_planner.dart';
import 'package:stoppy_app/features/knockout/domain/services/knockout_duel_score_calculator.dart';
import 'package:stoppy_app/features/knockout/domain/services/knockout_repechage_selector.dart';
import 'package:stoppy_app/features/knockout/domain/services/knockout_tournament_schedule.dart';

class MockKnockoutRepository implements KnockoutRepository {
  MockKnockoutRepository({
    KnockoutTournament? initialTournament,
    KnockoutTournamentSchedule schedule = const KnockoutTournamentSchedule(),
    KnockoutBracketPlanner bracketPlanner = const KnockoutBracketPlanner(),
    KnockoutDuelScoreCalculator duelScoreCalculator =
        const KnockoutDuelScoreCalculator(),
    KnockoutRepechageSelector repechageSelector =
        const KnockoutRepechageSelector(),
    Random? random,
    DateTime Function()? now,
  }) : _currentTournament =
           initialTournament ??
           schedule.createRegistrationTournament((now ?? DateTime.now)()),
       _schedule = schedule,
       _bracketPlanner = bracketPlanner,
       _duelScoreCalculator = duelScoreCalculator,
       _repechageSelector = repechageSelector,
       _random = random ?? Random(1),
       _now = now ?? DateTime.now;

  static const int defaultEntryCostGamePoints =
      KnockoutTournamentSchedule.entryCostGamePoints;

  KnockoutTournament _currentTournament;
  final KnockoutTournamentSchedule _schedule;
  final KnockoutBracketPlanner _bracketPlanner;
  final KnockoutDuelScoreCalculator _duelScoreCalculator;
  final KnockoutRepechageSelector _repechageSelector;
  final Random _random;
  final DateTime Function() _now;

  final Map<String, KnockoutPlayerEntry> _entriesByPlayerId = {};
  final List<KnockoutRun> _runs = [];

  @override
  Future<KnockoutTournament> fetchCurrentTournament() async {
    _refreshTournamentStatus();
    return _currentTournament;
  }

  @override
  Future<KnockoutDuelSnapshot?> fetchActiveDuel({
    required String tournamentId,
    required String playerId,
  }) async {
    _refreshTournamentStatus();
    if (tournamentId != _currentTournament.id ||
        !_currentTournament.hasStarted) {
      return null;
    }

    final round = _currentTournament.currentRound;
    if (round == null || !round.isActive) {
      return null;
    }

    final match = _activeMatchForPlayer(round: round, playerId: playerId);
    if (match != null) {
      return _snapshotForMatch(round: round, match: match, playerId: playerId);
    }

    if (round.byePlayerIds.contains(playerId)) {
      return KnockoutDuelSnapshot(
        tournamentId: _currentTournament.id,
        roundNumber: round.roundNumber,
        roundEndsAt: round.endsAt,
        playerId: playerId,
        match: KnockoutMatch(
          id: 'round-${round.roundNumber}-bye-$playerId',
          roundNumber: round.roundNumber,
          status: KnockoutMatchStatus.completed,
          playerOneId: playerId,
          winnerPlayerId: playerId,
        ),
        hasBye: true,
      );
    }

    return null;
  }

  @override
  Future<void> submitKnockoutRun(KnockoutRun run) async {
    _refreshTournamentStatus();
    final round = _currentTournament.currentRound;
    if (round == null || !round.isActive) {
      return;
    }

    KnockoutMatch? match;
    for (final candidate in round.matches) {
      if (candidate.id == run.matchId) {
        match = candidate;
        break;
      }
    }
    if (match == null ||
        match.status != KnockoutMatchStatus.active ||
        match.roundNumber != run.roundNumber ||
        (match.playerOneId != run.playerId &&
            match.playerTwoId != run.playerId)) {
      return;
    }

    final alreadySubmitted = _runs.any(
          (existingRun) => existingRun.id == run.id,
    );

    if (alreadySubmitted) {
      return;
    }

    _runs.add(run);
    _replaceMatch(round, _scoreMatch(match));
  }

  @override
  Future<KnockoutTournament> settleCurrentRound({
    required String tournamentId,
  }) async {
    _refreshTournamentStatus();
    if (tournamentId != _currentTournament.id ||
        !_currentTournament.hasStarted ||
        _currentTournament.isCompleted) {
      return _currentTournament;
    }

    final round = _currentTournament.currentRound;
    if (round == null || _now().isBefore(round.endsAt)) {
      return _currentTournament;
    }

    final settlement = _settleRound(round);
    final completedRound = round.copyWith(
      status: KnockoutRoundStatus.completed,
      matches: settlement.matches,
    );
    final updatedRounds = [
      for (final existingRound in _currentTournament.rounds)
        if (existingRound.roundNumber == round.roundNumber)
          completedRound
        else
          existingRound,
    ];

    final eliminatedPlayerIds = {
      ..._currentTournament.eliminatedPlayerIds,
      ...settlement.eliminatedPlayerIds,
    }.toList();

    if (settlement.advancingPlayerIds.length <= 1) {
      _currentTournament = _currentTournament.copyWith(
        status: KnockoutTournamentStatus.completed,
        rounds: updatedRounds,
        eliminatedPlayerIds: eliminatedPlayerIds,
      );
      return _currentTournament;
    }

    final nextRoundStartsAt = round.endsAt.add(const Duration(minutes: 1));
    final nextRound = _bracketPlanner.createRoundFromPlayerIds(
      roundNumber: round.roundNumber + 1,
      playerIds: settlement.advancingPlayerIds,
      roundStartsAt: nextRoundStartsAt,
      random: _random,
    );

    _currentTournament = _currentTournament.copyWith(
      rounds: [...updatedRounds, nextRound],
      eliminatedPlayerIds: eliminatedPlayerIds,
    );
    return _currentTournament;
  }

  @override
  Future<KnockoutPlayerEntry?> currentEntry({
    required String tournamentId,
    required String playerId,
  }) async {
    _refreshTournamentStatus();

    if (tournamentId != _currentTournament.id) {
      return null;
    }

    return _entriesByPlayerId[playerId];
  }

  @override
  Future<KnockoutRegistrationResult> registerPlayer({
    required KnockoutTournament tournament,
    required PlayerProfile playerProfile,
  }) async {
    _refreshTournamentStatus();

    if (tournament.id != _currentTournament.id) {
      return KnockoutRegistrationResult.failure(
        tournament: _currentTournament,
        failureReason: KnockoutRegistrationFailureReason.registrationClosed,
        message: 'This Knockout tournament is no longer available.',
      );
    }

    if (!_currentTournament.isRegistrationOpen) {
      return KnockoutRegistrationResult.failure(
        tournament: _currentTournament,
        failureReason: KnockoutRegistrationFailureReason.registrationClosed,
        message: 'Knockout registration is closed.',
      );
    }

    final existingEntry = _entriesByPlayerId[playerProfile.id];
    if (existingEntry != null) {
      return KnockoutRegistrationResult.failure(
        tournament: _currentTournament,
        failureReason: KnockoutRegistrationFailureReason.duplicateRegistration,
        message: 'You are already registered for this Knockout.',
      );
    }

    if (playerProfile.gamePoints < _currentTournament.entryCostGamePoints) {
      return KnockoutRegistrationResult.failure(
        tournament: _currentTournament,
        failureReason: KnockoutRegistrationFailureReason.insufficientGamePoints,
        message:
            'You need ${_currentTournament.entryCostGamePoints} GP to register.',
      );
    }

    final entry = KnockoutPlayerEntry(
      playerId: playerProfile.id,
      username: playerProfile.username,
      tournamentId: _currentTournament.id,
      registeredAt: _now(),
      accountCreatedAt: playerProfile.createdAt,
      entryCostGamePoints: _currentTournament.entryCostGamePoints,
    );

    _entriesByPlayerId[playerProfile.id] = entry;

    _currentTournament = _currentTournament.copyWith(
      entries: [..._currentTournament.entries, entry],
    );

    return KnockoutRegistrationResult.success(
      tournament: _currentTournament,
      playerEntry: entry,
    );
  }

  @override
  Future<KnockoutTournament> closeRegistration({
    required String tournamentId,
  }) async {
    _refreshTournamentStatus();

    if (tournamentId != _currentTournament.id) {
      return _currentTournament;
    }

    if (_currentTournament.status == KnockoutTournamentStatus.inProgress ||
        _currentTournament.status == KnockoutTournamentStatus.completed) {
      return _currentTournament;
    }

    _currentTournament = _currentTournament.copyWith(
      status: KnockoutTournamentStatus.registrationClosed,
    );

    return _currentTournament;
  }

  @override
  Future<KnockoutTournament> startTournament({
    required String tournamentId,
  }) async {
    _refreshTournamentStatus();

    if (tournamentId != _currentTournament.id) {
      return _currentTournament;
    }

    if (_currentTournament.status == KnockoutTournamentStatus.inProgress ||
        _currentTournament.status == KnockoutTournamentStatus.completed) {
      return _currentTournament;
    }

    final openingRound = _bracketPlanner.createOpeningRound(
      entries: _currentTournament.entries,
      roundStartsAt: _currentTournament.startsAt,
      random: _random,
    );

    _currentTournament = _currentTournament.copyWith(
      status: KnockoutTournamentStatus.inProgress,
      rounds: [openingRound],
    );

    return _currentTournament;
  }

  void _refreshTournamentStatus() {
    if (_currentTournament.status == KnockoutTournamentStatus.inProgress ||
        _currentTournament.status == KnockoutTournamentStatus.completed) {
      return;
    }

    final updatedStatus = _schedule.registrationStatus(
      now: _now(),
      registrationOpensAt: _currentTournament.registrationOpensAt,
      registrationClosesAt: _currentTournament.registrationClosesAt,
      startsAt: _currentTournament.startsAt,
    );

    if (updatedStatus == _currentTournament.status) {
      return;
    }

    if (updatedStatus == KnockoutTournamentStatus.inProgress &&
        _currentTournament.rounds.isEmpty) {
      _currentTournament = _currentTournament.copyWith(
        status: KnockoutTournamentStatus.registrationClosed,
      );
      return;
    }

    _currentTournament = _currentTournament.copyWith(status: updatedStatus);
  }

  KnockoutMatch? _activeMatchForPlayer({
    required KnockoutRound round,
    required String playerId,
  }) {
    for (final match in round.matches) {
      if (match.status == KnockoutMatchStatus.active &&
          (match.playerOneId == playerId || match.playerTwoId == playerId)) {
        return match;
      }
    }

    return null;
  }

  KnockoutDuelSnapshot _snapshotForMatch({
    required KnockoutRound round,
    required KnockoutMatch match,
    required String playerId,
  }) {
    final isPlayerOne = match.playerOneId == playerId;
    return KnockoutDuelSnapshot(
      tournamentId: _currentTournament.id,
      roundNumber: round.roundNumber,
      roundEndsAt: round.endsAt,
      playerId: playerId,
      opponentId: isPlayerOne ? match.playerTwoId : match.playerOneId,
      match: match,
      playerScore: isPlayerOne ? match.playerOneScore : match.playerTwoScore,
      opponentScore: isPlayerOne ? match.playerTwoScore : match.playerOneScore,
      playerRunCount: isPlayerOne
          ? match.playerOneRunCount
          : match.playerTwoRunCount,
      opponentRunCount: isPlayerOne
          ? match.playerTwoRunCount
          : match.playerOneRunCount,
    );
  }

  KnockoutMatch _scoreMatch(KnockoutMatch match) {
    final playerOneScore = _scoreForPlayer(match.playerOneId, match.id);
    final playerTwoScore = _scoreForPlayer(match.playerTwoId, match.id);

    return match.copyWith(
      playerOneScore: playerOneScore.baseScore.round(),
      playerTwoScore: playerTwoScore.baseScore.round(),
      playerOneRunCount: playerOneScore.runCount,
      playerTwoRunCount: playerTwoScore.runCount,
    );
  }

  KnockoutDuelScore _scoreForPlayer(String? playerId, String matchId) {
    if (playerId == null) {
      return KnockoutDuelScore(
        playerId: 'empty-slot',
        runCount: 0,
        baseScore: 0,
        countedRunScores: const [],
        allRunScores: const [],
      );
    }

    return _duelScoreCalculator.calculate(
      playerId: playerId,
      runs: _runs.where((run) => run.matchId == matchId).toList(),
    );
  }

  void _replaceMatch(KnockoutRound round, KnockoutMatch updatedMatch) {
    final updatedMatches = [
      for (final match in round.matches)
        if (match.id == updatedMatch.id) updatedMatch else match,
    ];
    final updatedRound = round.copyWith(matches: updatedMatches);
    _currentTournament = _currentTournament.copyWith(
      rounds: [
        for (final existingRound in _currentTournament.rounds)
          if (existingRound.roundNumber == round.roundNumber)
            updatedRound
          else
            existingRound,
      ],
    );
  }

  _RoundSettlement _settleRound(KnockoutRound round) {
    final matches = <KnockoutMatch>[];
    final advancingPlayerIds = <String>[...round.byePlayerIds];
    final eliminatedPlayerIds = <String>[];
    final naturalLoserCandidates = <KnockoutRepechageCandidate>[];
    final zeroRunEliminatedIds = <String>[];

    for (final match in round.matches) {
      final scoredMatch = _scoreMatch(match);
      if (scoredMatch.requiresRepechage) {
        matches.add(scoredMatch.copyWith(status: KnockoutMatchStatus.voided));
        zeroRunEliminatedIds.addAll([
          if (scoredMatch.playerOneId != null) scoredMatch.playerOneId!,
          if (scoredMatch.playerTwoId != null) scoredMatch.playerTwoId!,
        ]);
        continue;
      }

      final winnerPlayerId = _winnerFor(scoredMatch);
      final loserPlayerId = _loserFor(scoredMatch, winnerPlayerId);
      if (winnerPlayerId != null) {
        advancingPlayerIds.add(winnerPlayerId);
      }
      if (loserPlayerId != null) {
        naturalLoserCandidates.add(
          KnockoutRepechageCandidate(
            entry: _entriesByPlayerId[loserPlayerId]!,
            eliminatedScore: _scoreForLoser(scoredMatch, loserPlayerId),
          ),
        );
      }

      matches.add(
        scoredMatch.copyWith(
          status: KnockoutMatchStatus.completed,
          winnerPlayerId: winnerPlayerId,
        ),
      );
    }

    final repechageNeeded = matches
        .where((match) => match.status == KnockoutMatchStatus.voided)
        .length;
    final repechageWinners = _repechageSelector.selectReplacementAdvancements(
      eliminatedCandidates: naturalLoserCandidates,
      neededCount: repechageNeeded,
    );
    final repechageWinnerIds = repechageWinners
        .map((entry) => entry.playerId)
        .toSet();
    advancingPlayerIds.addAll(repechageWinnerIds);

    var repechageIndex = 0;
    final settledMatches = [
      for (final match in matches)
        if (match.status == KnockoutMatchStatus.voided &&
            repechageIndex < repechageWinners.length)
          match.copyWith(
            status: KnockoutMatchStatus.completed,
            repechageWinnerPlayerId:
                repechageWinners[repechageIndex++].playerId,
          )
        else
          match,
    ];

    eliminatedPlayerIds.addAll(zeroRunEliminatedIds);
    for (final candidate in naturalLoserCandidates) {
      if (!repechageWinnerIds.contains(candidate.entry.playerId)) {
        eliminatedPlayerIds.add(candidate.entry.playerId);
      }
    }

    return _RoundSettlement(
      matches: settledMatches,
      advancingPlayerIds: advancingPlayerIds.toSet().toList(),
      eliminatedPlayerIds: eliminatedPlayerIds.toSet().toList(),
    );
  }

  String? _winnerFor(KnockoutMatch match) {
    if (match.playerOneId == null) {
      return match.playerTwoId;
    }
    if (match.playerTwoId == null) {
      return match.playerOneId;
    }
    if (match.playerOneScore > match.playerTwoScore) {
      return match.playerOneId;
    }
    if (match.playerTwoScore > match.playerOneScore) {
      return match.playerTwoId;
    }

    // Exact non-zero ties are not expected to be common, but the mock must stay
    // deterministic. Lifetime tournament strength is used as a backend-ready
    // placeholder until an official duel tie-breaker is defined.
    final playerOneEntry = _entriesByPlayerId[match.playerOneId]!;
    final playerTwoEntry = _entriesByPlayerId[match.playerTwoId]!;
    final comparison = _compareEntriesForTie(playerOneEntry, playerTwoEntry);
    return comparison <= 0 ? playerOneEntry.playerId : playerTwoEntry.playerId;
  }

  String? _loserFor(KnockoutMatch match, String? winnerPlayerId) {
    if (winnerPlayerId == null) {
      return null;
    }
    if (match.playerOneId == winnerPlayerId) {
      return match.playerTwoId;
    }
    if (match.playerTwoId == winnerPlayerId) {
      return match.playerOneId;
    }
    return null;
  }

  double _scoreForLoser(KnockoutMatch match, String loserPlayerId) {
    if (match.playerOneId == loserPlayerId) {
      return match.playerOneScore.toDouble();
    }
    return match.playerTwoScore.toDouble();
  }

  int _compareEntriesForTie(KnockoutPlayerEntry a, KnockoutPlayerEntry b) {
    final runCountComparison = b.lifetimeRunCount.compareTo(a.lifetimeRunCount);
    if (runCountComparison != 0) {
      return runCountComparison;
    }
    final averageComparison = b.lifetimeAverageRunScore.compareTo(
      a.lifetimeAverageRunScore,
    );
    if (averageComparison != 0) {
      return averageComparison;
    }
    return a.accountCreatedAt.compareTo(b.accountCreatedAt);
  }
}

class _RoundSettlement {
  const _RoundSettlement({
    required this.matches,
    required this.advancingPlayerIds,
    required this.eliminatedPlayerIds,
  });

  final List<KnockoutMatch> matches;
  final List<String> advancingPlayerIds;
  final List<String> eliminatedPlayerIds;
}
