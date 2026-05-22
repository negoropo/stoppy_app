import 'dart:math';

import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_entry.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_registration_result.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament.dart';
import 'package:stoppy_app/features/knockout/domain/repositories/knockout_repository.dart';
import 'package:stoppy_app/features/knockout/domain/services/knockout_bracket_planner.dart';
import 'package:stoppy_app/features/knockout/domain/services/knockout_tournament_schedule.dart';

class MockKnockoutRepository implements KnockoutRepository {
  MockKnockoutRepository({
    KnockoutTournament? initialTournament,
    KnockoutTournamentSchedule schedule = const KnockoutTournamentSchedule(),
    KnockoutBracketPlanner bracketPlanner = const KnockoutBracketPlanner(),
    Random? random,
    DateTime Function()? now,
  }) : _currentTournament =
      initialTournament ??
          schedule.createRegistrationTournament((now ?? DateTime.now)()),
        _schedule = schedule,
        _bracketPlanner = bracketPlanner,
        _random = random ?? Random(1),
        _now = now ?? DateTime.now;

  static const int defaultEntryCostGamePoints =
      KnockoutTournamentSchedule.entryCostGamePoints;

  KnockoutTournament _currentTournament;
  final KnockoutTournamentSchedule _schedule;
  final KnockoutBracketPlanner _bracketPlanner;
  final Random _random;
  final DateTime Function() _now;

  final Map<String, KnockoutPlayerEntry> _entriesByPlayerId = {};

  @override
  Future<KnockoutTournament> fetchCurrentTournament() async {
    _refreshTournamentStatus();
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
}