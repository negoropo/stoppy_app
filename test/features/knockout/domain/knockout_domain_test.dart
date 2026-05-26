import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_entry.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_run.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament.dart';
import 'package:stoppy_app/features/knockout/domain/services/knockout_bracket_planner.dart';
import 'package:stoppy_app/features/knockout/domain/services/knockout_duel_score_calculator.dart';
import 'package:stoppy_app/features/knockout/domain/services/knockout_repechage_selector.dart';
import 'package:stoppy_app/features/knockout/domain/services/knockout_tournament_schedule.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_match.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_status.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_round.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_duel_snapshot.dart';

void main() {
  group('KnockoutTournamentSchedule', () {
    const schedule = KnockoutTournamentSchedule();

    test('creates one monthly tournament with 25 GP entry cost', () {
      final tournament = schedule.createRegistrationTournament(
        DateTime(2026, 5, 22, 10),
      );

      expect(tournament.id, '2026-06');
      expect(tournament.name, 'June Knockout');
      expect(tournament.entryCostGamePoints, 25);
      expect(tournament.registrationOpensAt, DateTime(2026, 5));
      expect(tournament.registrationClosesAt, DateTime(2026, 5, 31, 23, 59));
      expect(tournament.startsAt, DateTime(2026, 6));
      expect(tournament.status, KnockoutTournamentStatus.registrationOpen);
    });

    test('closes registration after the final pre-tournament minute', () {
      final status = schedule.registrationStatus(
        now: DateTime(2026, 5, 31, 23, 59, 30),
        registrationOpensAt: DateTime(2026, 5),
        registrationClosesAt: DateTime(2026, 5, 31, 23, 59),
        startsAt: DateTime(2026, 6),
      );

      expect(status, KnockoutTournamentStatus.registrationClosed);
    });

    test('marks tournament in progress from tournament start', () {
      final status = schedule.registrationStatus(
        now: DateTime(2026, 6),
        registrationOpensAt: DateTime(2026, 5),
        registrationClosesAt: DateTime(2026, 5, 31, 23, 59),
        startsAt: DateTime(2026, 6),
      );

      expect(status, KnockoutTournamentStatus.inProgress);
    });

    test('daily knockout rounds end at 23:59 local time', () {
      final end = schedule.roundEndsAt(DateTime(2026, 6, 3, 8, 30));

      expect(end, DateTime(2026, 6, 3, 23, 59));
    });
  });

  group('KnockoutDuelScoreCalculator', () {
    const calculator = KnockoutDuelScoreCalculator();

    test('uses best run for 1 to 5 runs', () {
      final result = calculator.calculate(
        playerId: 'player',
        runs: _runs([100, 400, 300, 200, 250]),
      );

      expect(result.bestRunsCount, 1);
      expect(result.countedRunScores, [400]);
      expect(result.baseScore, 400);
    });

    test('averages best 2 runs for 6 to 10 runs', () {
      final result = calculator.calculate(
        playerId: 'player',
        runs: _runs([100, 900, 300, 800, 250, 400]),
      );

      expect(result.bestRunsCount, 2);
      expect(result.countedRunScores, [900, 800]);
      expect(result.baseScore, 850);
    });

    test('averages best 3 runs for 11 to 15 runs without bonus points', () {
      final result = calculator.calculate(
        playerId: 'player',
        runs: _runs([100, 900, 300, 800, 250, 400, 700, 650, 500, 10, 999]),
      );

      expect(result.bestRunsCount, 3);
      expect(result.countedRunScores, [999, 900, 800]);
      expect(result.baseScore, closeTo(899.666, 0.001));
    });
  });

  group('KnockoutBracketPlanner', () {
    const planner = KnockoutBracketPlanner();

    test('reduces 35 players to 32 with 3 opening matches and 29 byes', () {
      final entries = _entries(35);

      final round = planner.createOpeningRound(
        entries: entries,
        roundStartsAt: DateTime(2026, 6),
        random: Random(1),
      );

      expect(round.status, KnockoutRoundStatus.active);
      expect(
        round.matches.every(
          (match) => match.status == KnockoutMatchStatus.active,
        ),
        isTrue,
      );

      final matchedPlayerIds = round.matches
          .expand((match) => [match.playerOneId, match.playerTwoId])
          .whereType<String>()
          .toSet();

      expect(round.matches.length, 3);
      expect(round.byePlayerIds.length, 29);
      expect({...matchedPlayerIds, ...round.byePlayerIds}.length, 35);
      expect(round.endsAt, DateTime(2026, 6, 1, 23, 59));
    });

    test('calculates opening match counts correctly', () {
      expect(planner.openingMatchCount(35), 3);
      expect(planner.openingMatchCount(32), 16);
      expect(planner.openingMatchCount(1), 0);
    });

    test('calculates nearest lower power of two correctly', () {
      expect(planner.nearestLowerPowerOfTwo(35), 32);
      expect(planner.nearestLowerPowerOfTwo(64), 64);
      expect(planner.nearestLowerPowerOfTwo(1), 1);
    });

    test(
      'creates a normal first round when player count is a power of two',
      () {
        final round = planner.createOpeningRound(
          entries: _entries(32),
          roundStartsAt: DateTime(2026, 6),
          random: Random(1),
        );

        expect(round.matches.length, 16);
        expect(round.byePlayerIds, isEmpty);
      },
    );

    test('gives the only player a bye', () {
      final round = planner.createOpeningRound(
        entries: _entries(1),
        roundStartsAt: DateTime(2026, 6),
        random: Random(1),
      );

      expect(round.matches, isEmpty);
      expect(round.byePlayerIds, ['player-0']);
    });
  });

  group('KnockoutRepechageSelector', () {
    const selector = KnockoutRepechageSelector();

    test('selects replacements by official tie-breaker priority', () {
      final oldAccount = DateTime(2025);
      final newAccount = DateTime(2026);
      final candidates = [
        KnockoutRepechageCandidate(
          entry: _entry(
            'lower-score',
            lifetimeRunCount: 100,
            lifetimeAverageRunScore: 900,
            accountCreatedAt: oldAccount,
          ),
          eliminatedScore: 100,
        ),
        KnockoutRepechageCandidate(
          entry: _entry(
            'best-score',
            lifetimeRunCount: 1,
            lifetimeAverageRunScore: 1,
            accountCreatedAt: newAccount,
          ),
          eliminatedScore: 500,
        ),
        KnockoutRepechageCandidate(
          entry: _entry(
            'best-lifetime-runs',
            lifetimeRunCount: 30,
            lifetimeAverageRunScore: 10,
            accountCreatedAt: newAccount,
          ),
          eliminatedScore: 300,
        ),
        KnockoutRepechageCandidate(
          entry: _entry(
            'best-lifetime-average',
            lifetimeRunCount: 20,
            lifetimeAverageRunScore: 600,
            accountCreatedAt: newAccount,
          ),
          eliminatedScore: 300,
        ),
        KnockoutRepechageCandidate(
          entry: _entry(
            'oldest-account',
            lifetimeRunCount: 20,
            lifetimeAverageRunScore: 600,
            accountCreatedAt: oldAccount,
          ),
          eliminatedScore: 300,
        ),
      ];

      final replacements = selector.selectReplacementAdvancements(
        eliminatedCandidates: candidates,
        neededCount: 4,
      );

      expect(replacements.map((entry) => entry.playerId), [
        'best-score',
        'best-lifetime-runs',
        'oldest-account',
        'best-lifetime-average',
      ]);
    });
  });

  group('KnockoutPlayerStatus', () {
    test('only active duel status can play tournament runs', () {
      final activeStatus = KnockoutPlayerStatus(
        state: KnockoutPlayerTournamentState.activeDuel,
        duelSnapshot: KnockoutDuelSnapshot(
          tournamentId: '2026-06',
          roundNumber: 1,
          roundEndsAt: DateTime(2026, 6, 1, 23, 59),
          playerId: 'player',
          opponentId: 'opponent',
          match: const KnockoutMatch(
            id: 'match-1',
            roundNumber: 1,
            status: KnockoutMatchStatus.active,
            playerOneId: 'player',
            playerTwoId: 'opponent',
          ),
          playerScore: 0,
          opponentScore: 0,
          playerRunCount: 0,
          opponentRunCount: 0,
        ),
      );
      const byeStatus = KnockoutPlayerStatus(
        state: KnockoutPlayerTournamentState.byeWaitingNextRound,
      );

      expect(activeStatus.canPlayTournamentRun, isTrue);
      expect(byeStatus.canPlayTournamentRun, isFalse);
      expect(activeStatus.title, 'Active duel');
      expect(byeStatus.title, 'Bye - waiting for next round');
    });
  });
}

List<KnockoutRun> _runs(List<int> scores) {
  return [
    for (var index = 0; index < scores.length; index += 1)
      KnockoutRun(
        id: 'run-$index',
        playerId: 'player',
        matchId: 'match-1',
        roundNumber: 1,
        score: scores[index],
        completedAt: DateTime(2026, 6, 1, 8 + index),
      ),
  ];
}

List<KnockoutPlayerEntry> _entries(int count) {
  return [
    for (var index = 0; index < count; index += 1) _entry('player-$index'),
  ];
}

KnockoutPlayerEntry _entry(
  String playerId, {
  int lifetimeRunCount = 0,
  double lifetimeAverageRunScore = 0,
  DateTime? accountCreatedAt,
}) {
  return KnockoutPlayerEntry(
    playerId: playerId,
    username: playerId,
    tournamentId: '2026-06',
    registeredAt: DateTime(2026, 5, 22),
    accountCreatedAt: accountCreatedAt ?? DateTime(2026),
    entryCostGamePoints: 25,
    lifetimeRunCount: lifetimeRunCount,
    lifetimeAverageRunScore: lifetimeAverageRunScore,
  );
}
