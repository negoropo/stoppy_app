import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/league/domain/models/league_division.dart';
import 'package:stoppy_app/features/league/domain/models/league_player_entry.dart';
import 'package:stoppy_app/features/league/domain/models/league_ranking_entry.dart';
import 'package:stoppy_app/features/league/domain/models/weekly_league_run.dart';
import 'package:stoppy_app/features/league/domain/services/league_division_policy.dart';
import 'package:stoppy_app/features/league/domain/services/league_ranking_calculator.dart';
import 'package:stoppy_app/features/league/domain/services/league_season_settlement_calculator.dart';
import 'package:stoppy_app/features/league/domain/services/weekly_league_score_calculator.dart';

void main() {
  group('LeagueDivisionPolicy', () {
    const policy = LeagueDivisionPolicy();

    test('calculates division capacities by doubling each division', () {
      expect(policy.capacityForDivision(1), 10);
      expect(policy.capacityForDivision(2), 20);
      expect(policy.capacityForDivision(3), 40);
      expect(policy.capacityForDivision(4), 80);
    });

    test('places new players in lowest division with available capacity', () {
      const divisions = [
        LeagueDivision(number: 1, capacity: 10),
        LeagueDivision(number: 2, capacity: 20),
      ];
      final entries = List.generate(
        19,
        (index) => _entry('p$index', divisionNumber: 2),
      );

      final placement = policy.placeNewPlayer(
        divisions: divisions,
        entries: entries,
      );

      expect(placement.number, 2);
      expect(placement.capacity, 20);
    });

    test('creates a new division when the lowest division is full', () {
      const divisions = [
        LeagueDivision(number: 1, capacity: 10),
        LeagueDivision(number: 2, capacity: 20),
      ];
      final entries = List.generate(
        20,
        (index) => _entry('p$index', divisionNumber: 2),
      );

      final placement = policy.placeNewPlayer(
        divisions: divisions,
        entries: entries,
      );

      expect(placement.number, 3);
      expect(placement.capacity, 40);
    });

    test('places new player after full division 1 and full division 2', () {
      const divisions = [
        LeagueDivision(number: 1, capacity: 10),
        LeagueDivision(number: 2, capacity: 20),
      ];
      final entries = [
        for (var index = 0; index < 10; index += 1)
          _entry('d1-$index', divisionNumber: 1),
        for (var index = 0; index < 20; index += 1)
          _entry('d2-$index', divisionNumber: 2),
      ];

      final placement = policy.placeNewPlayer(
        divisions: divisions,
        entries: entries,
      );

      expect(placement.number, 3);
      expect(placement.capacity, 40);
    });

    test('marks weekly entry as paid without mutating previous entry', () {
      final unpaidEntry = _entry('p1', entryPaid: false);
      final paidEntry = policy.activateWeeklyEntry(unpaidEntry);

      expect(unpaidEntry.entryPaid, isFalse);
      expect(paidEntry.entryPaid, isTrue);
      expect(LeagueDivisionPolicy.weeklyEntryCostGamePoints, 10);
    });
  });

  group('WeeklyLeagueScoreCalculator', () {
    const calculator = WeeklyLeagueScoreCalculator();

    test('inactive score displays inactive instead of zero', () {
      final score = calculator.calculate(
        playerEntry: _entry('p1', entryPaid: false),
        runs: const [],
      );

      expect(score.isActive, isFalse);
      expect(score.displayScore, 'inactive');
    });

    test('calculates weekly score blocks for 1, 5, 6, 10, 11 and 15 runs', () {
      final entry = _entry('p1', entryPaid: true);

      expect(
        calculator
            .calculate(playerEntry: entry, runs: _runs('p1', [100]))
            .baseScore,
        100,
      );
      expect(
        calculator
            .calculate(
              playerEntry: entry,
              runs: _runs('p1', [100, 90, 80, 70, 60]),
            )
            .baseScore,
        100,
      );
      expect(
        calculator
            .calculate(
              playerEntry: entry,
              runs: _runs('p1', [100, 90, 80, 70, 60, 50]),
            )
            .baseScore,
        95,
      );
      expect(
        calculator
            .calculate(
              playerEntry: entry,
              runs: _runs('p1', [100, 90, 80, 70, 60, 50, 40, 30, 20, 10]),
            )
            .baseScore,
        95,
      );
      expect(
        calculator
            .calculate(
              playerEntry: entry,
              runs: _runs('p1', [100, 90, 80, 70, 60, 50, 40, 30, 20, 10, 5]),
            )
            .baseScore,
        90,
      );
      expect(
        calculator
            .calculate(
              playerEntry: entry,
              runs: _runs('p1', [
                100,
                90,
                80,
                70,
                60,
                50,
                40,
                30,
                20,
                10,
                5,
                4,
                3,
                2,
                1,
              ]),
            )
            .baseScore,
        90,
      );
    });

    test('applies activity day multipliers', () {
      expect(calculator.multiplierForActiveDays(1), 1.0);
      expect(calculator.multiplierForActiveDays(2), 1.1);
      expect(calculator.multiplierForActiveDays(3), 1.2);
      expect(calculator.multiplierForActiveDays(4), 1.4);
      expect(calculator.multiplierForActiveDays(5), 1.6);
      expect(calculator.multiplierForActiveDays(6), 1.8);
      expect(calculator.multiplierForActiveDays(7), 2.0);
    });
  });

  group('LeagueRankingCalculator', () {
    const rankingCalculator = LeagueRankingCalculator();

    test('sorts by score and tie breakers in order', () {
      final entries = [
        _entry('active-days', entryPaid: true),
        _entry('more-runs', entryPaid: true),
        _entry('older', entryPaid: true, registeredAt: DateTime(2026)),
      ];
      final runs = [
        _run('active-days', 100, dayOffset: 0),
        _run('active-days', 100, dayOffset: 1),
        _run('more-runs', 100, dayOffset: 0),
        _run('more-runs', 100, dayOffset: 0, minuteOffset: 1),
        _run('older', 100, dayOffset: 0),
      ];

      final rankedEntries = rankingCalculator.rank(
        entries: entries,
        runs: runs,
        divisionNumber: 1,
      );

      expect(rankedEntries.map((entry) => entry.playerEntry.playerId), [
        'active-days',
        'more-runs',
        'older',
      ]);
    });

    test('uses the full tie-breaker chain before registration date', () {
      final entries = [
        _entry('active-days', entryPaid: true),
        _entry('more-runs', entryPaid: true),
        _entry('higher-average', entryPaid: true),
        _entry('higher-best-run', entryPaid: true),
        _entry('more-lifetime-runs', entryPaid: true, lifetimeRuns: 20),
        _entry(
          'higher-lifetime-average',
          entryPaid: true,
          lifetimeAverage: 500,
        ),
        _entry(
          'older-registration',
          entryPaid: true,
          registeredAt: DateTime(2025),
        ),
        _entry(
          'newer-registration',
          entryPaid: true,
          registeredAt: DateTime(2026),
        ),
      ];
      final runs = [
        _run('active-days', 100, dayOffset: 0),
        _run('active-days', 100, dayOffset: 1),
        _run('more-runs', 110),
        _run('more-runs', 20, minuteOffset: 1),
        ..._runs('higher-average', [100, 100, 100, 100, 100, 100]),
        ..._runs('higher-best-run', [150, 50, 50, 50, 50, 50]),
        _run('more-lifetime-runs', 100),
        _run('higher-lifetime-average', 100),
        _run('older-registration', 100),
        _run('newer-registration', 100),
      ];

      final rankedEntries = rankingCalculator.rank(
        entries: entries,
        runs: runs,
        divisionNumber: 1,
      );

      expect(rankedEntries.map((entry) => entry.playerEntry.playerId), [
        'active-days',
        'more-runs',
        'higher-average',
        'higher-best-run',
        'more-lifetime-runs',
        'higher-lifetime-average',
        'older-registration',
        'newer-registration',
      ]);
    });

    test('active player with 0 runs ranks above inactive player', () {
      final rankedEntries = rankingCalculator.rank(
        entries: [
          _entry('inactive', entryPaid: false),
          _entry('active-zero-runs', entryPaid: true),
        ],
        runs: [_run('inactive', 9999)],
        divisionNumber: 1,
      );

      expect(rankedEntries.first.playerEntry.playerId, 'active-zero-runs');
      expect(rankedEntries.first.weeklyScore.displayScore, '0');
      expect(rankedEntries.last.weeklyScore.displayScore, 'inactive');
    });

    test('returns snapshot around current player', () {
      final entries = List.generate(
        12,
        (index) => _entry('p$index', entryPaid: true),
      );
      final runs = [
        for (var index = 0; index < 12; index += 1)
          _run('p$index', 1200 - index * 10),
      ];
      final rankedEntries = rankingCalculator.rank(
        entries: entries,
        runs: runs,
        divisionNumber: 1,
      );

      final snapshot = rankingCalculator.snapshotForPlayer(
        currentPlayerId: 'p6',
        division: const LeagueDivision(number: 2, capacity: 20),
        rankedEntries: rankedEntries,
        promotionCount: 4,
        relegationCount: 4,
      );

      expect(snapshot.currentPlayerRank, 7);
      expect(snapshot.playersAbove.length, 5);
      expect(snapshot.playersBelow.length, 5);

      expect(snapshot.playersAbove.map((entry) => entry.rank), [6, 5, 4, 3, 2]);
      expect(
        snapshot.currentPlayerEntry.weeklyScore.displayScore,
        isNot('inactive'),
      );
      expect(snapshot.scoreNeededForPromotionZone, greaterThan(0));
      expect(snapshot.scoreNeededToStayInDivision, 0);
    });

    test('score needed for promotion requires surpassing the target score', () {
      final entries = [
        _entry('target', entryPaid: true, registeredAt: DateTime(2025)),
        _entry('current', entryPaid: true, registeredAt: DateTime(2026)),
      ];
      final rankedEntries = rankingCalculator.rank(
        entries: entries,
        runs: [_run('target', 100), _run('current', 100)],
        divisionNumber: 1,
      );

      final snapshot = rankingCalculator.snapshotForPlayer(
        currentPlayerId: 'current',
        division: const LeagueDivision(number: 2, capacity: 20),
        rankedEntries: rankedEntries,
        promotionCount: 1,
        relegationCount: 0,
      );

      expect(snapshot.scoreNeededForPromotionZone, 1);
    });

    test('score needed to stay requires surpassing tied relegation cutoff', () {
      final entries = [
        _entry('safe-1', entryPaid: true, registeredAt: DateTime(2025, 1, 1)),
        _entry('safe-2', entryPaid: true, registeredAt: DateTime(2025, 1, 2)),
        _entry('cutoff', entryPaid: true, registeredAt: DateTime(2025, 1, 3)),
        _entry('current', entryPaid: true, registeredAt: DateTime(2025, 1, 4)),
        _entry('below', entryPaid: true, registeredAt: DateTime(2025, 1, 5)),
      ];
      final rankedEntries = rankingCalculator.rank(
        entries: entries,
        runs: [
          _run('safe-1', 200),
          _run('safe-2', 150),
          _run('cutoff', 100),
          _run('current', 100),
          _run('below', 90),
        ],
        divisionNumber: 1,
      );

      final snapshot = rankingCalculator.snapshotForPlayer(
        currentPlayerId: 'current',
        division: const LeagueDivision(number: 1, capacity: 10),
        rankedEntries: rankedEntries,
        promotionCount: 0,
        relegationCount: 2,
      );

      expect(snapshot.scoreNeededToStayInDivision, 1);
    });
  });

  group('LeagueSeasonSettlementCalculator', () {
    const rankingCalculator = LeagueRankingCalculator();
    const settlementCalculator = LeagueSeasonSettlementCalculator();

    test(
      'relegates at least 40 percent and inactive players always relegate',
      () {
        const division = LeagueDivision(number: 1, capacity: 10);
        final entries = [
          for (var index = 0; index < 7; index += 1)
            _entry('a$index', entryPaid: true),
          _entry('i1', entryPaid: false),
          _entry('i2', entryPaid: false),
        ];
        final runs = [
          for (var index = 0; index < 7; index += 1)
            _run('a$index', 100 + index),
        ];
        final rankedEntries = rankingCalculator.rank(
          entries: entries,
          runs: runs,
          divisionNumber: 1,
        );

        final relegatedIds = settlementCalculator.relegatedPlayerIdsForDivision(
          division: division,
          isLastDivision: false,
          rankedEntries: rankedEntries,
        );

        expect(relegatedIds.length, 4);
        expect(relegatedIds, containsAll(['i1', 'i2']));
      },
    );

    test(
      'relegates only inactive players when inactive count exceeds 40 percent',
      () {
        const division = LeagueDivision(number: 1, capacity: 10);
        final entries = [
          for (var index = 0; index < 5; index += 1)
            _entry('active-$index', entryPaid: true),
          for (var index = 0; index < 5; index += 1)
            _entry('inactive-$index', entryPaid: false),
        ];
        final rankedEntries = rankingCalculator.rank(
          entries: entries,
          runs: [
            for (var index = 0; index < 5; index += 1)
              _run('active-$index', 100 + index),
          ],
          divisionNumber: 1,
        );

        final relegatedIds = settlementCalculator.relegatedPlayerIdsForDivision(
          division: division,
          isLastDivision: false,
          rankedEntries: rankedEntries,
        );

        expect(relegatedIds.length, 5);
        expect(
          relegatedIds,
          containsAll([
            for (var index = 0; index < 5; index += 1) 'inactive-$index',
          ]),
        );
        expect(
          relegatedIds.any((playerId) => playerId.startsWith('active-')),
          isFalse,
        );
      },
    );

    test(
      'matches promotion and relegation counts between adjacent divisions',
      () {
        const upperDivision = LeagueDivision(number: 1, capacity: 10);
        const lowerDivision = LeagueDivision(number: 2, capacity: 20);
        final upperRankedEntries = rankingCalculator.rank(
          entries: [
            for (var index = 0; index < 8; index += 1)
              _entry('upper-active-$index', entryPaid: true),
            _entry('upper-inactive-1', entryPaid: false),
            _entry('upper-inactive-2', entryPaid: false),
          ],
          runs: [
            for (var index = 0; index < 8; index += 1)
              _run('upper-active-$index', 100 + index),
          ],
          divisionNumber: 1,
        );
        final relegatedIds = settlementCalculator.relegatedPlayerIdsForDivision(
          division: upperDivision,
          isLastDivision: false,
          rankedEntries: upperRankedEntries,
        );
        final lowerRankedEntries = rankingCalculator.rank(
          entries: [
            for (var index = 0; index < 10; index += 1)
              _entry('lower-$index', divisionNumber: 2, entryPaid: true),
          ],
          runs: [
            for (var index = 0; index < 10; index += 1)
              _run('lower-$index', 1000 - index),
          ],
          divisionNumber: 2,
        );

        final promotedIds = settlementCalculator
            .promotedPlayerIdsForLowerDivision(
              lowerDivision: lowerDivision,
              aboveDivisionRelegationCount: relegatedIds.length,
              lowerDivisionRankedEntries: lowerRankedEntries,
            );

        expect(relegatedIds.length, 4);
        expect(promotedIds.length, relegatedIds.length);
      },
    );

    test(
      'promotes from lower division using above relegation count and 20 percent floor',
      () {
        const lowerDivision = LeagueDivision(number: 2, capacity: 20);
        final entries = [
          for (var index = 0; index < 6; index += 1)
            _entry('p$index', divisionNumber: 2, entryPaid: true),
        ];
        final runs = [
          for (var index = 0; index < 6; index += 1)
            _run('p$index', 1000 - index),
        ];
        final rankedEntries = rankingCalculator.rank(
          entries: entries,
          runs: runs,
          divisionNumber: 2,
        );

        final promotedIds = settlementCalculator
            .promotedPlayerIdsForLowerDivision(
              lowerDivision: lowerDivision,
              aboveDivisionRelegationCount: 2,
              lowerDivisionRankedEntries: rankedEntries,
            );

        expect(promotedIds, ['p0', 'p1', 'p2', 'p3']);
      },
    );

    test('settles penultimate and last division special rules', () {
      const penultimateDivision = LeagueDivision(number: 2, capacity: 20);
      const lastDivision = LeagueDivision(number: 3, capacity: 40);
      final penultimateEntries = [
        _entry('pen-active-best', divisionNumber: 2, entryPaid: true),
        _entry('pen-active-worst', divisionNumber: 2, entryPaid: true),
        _entry('pen-inactive', divisionNumber: 2, entryPaid: false),
      ];
      final lastEntries = [
        _entry('last-best', divisionNumber: 3, entryPaid: true),
        _entry('last-second', divisionNumber: 3, entryPaid: true),
        _entry('last-inactive', divisionNumber: 3, entryPaid: false),
      ];
      final penultimateRanked = rankingCalculator.rank(
        entries: penultimateEntries,
        runs: [_run('pen-active-best', 900), _run('pen-active-worst', 100)],
        divisionNumber: 2,
      );
      final lastRanked = rankingCalculator.rank(
        entries: lastEntries,
        runs: [_run('last-best', 800), _run('last-second', 700)],
        divisionNumber: 3,
      );

      final settlement = settlementCalculator.settlePenultimateAndLastDivision(
        penultimateDivision: penultimateDivision,
        lastDivision: lastDivision,
        penultimateRankedEntries: penultimateRanked,
        lastRankedEntries: lastRanked,
      );

      expect(settlement.promotedPlayerIds, ['last-best', 'last-second']);
      expect(
        settlement.relegatedPlayerIds,
        containsAll(['pen-inactive', 'pen-active-worst']),
      );
      expect(
        settlement.lostReservationPlayerIds,
        containsAll(['pen-inactive', 'last-inactive']),
      );
      expect(settlement.keptPlayerIds, contains('pen-active-best'));
      expect(settlement.keptPlayerIds, isNot(contains('last-best')));
      expect(settlement.keptPlayerIds, isNot(contains('last-second')));
      expect(settlement.closedDivision, isFalse);
    });

    test(
      'promotes extra active last division players to match inactive penultimate relegations',
      () {
        const penultimateDivision = LeagueDivision(number: 2, capacity: 20);
        const lastDivision = LeagueDivision(number: 3, capacity: 40);

        final penultimateEntries = [
          _entry('pen-inactive-1', divisionNumber: 2, entryPaid: false),
          _entry('pen-inactive-2', divisionNumber: 2, entryPaid: false),
          _entry('pen-inactive-3', divisionNumber: 2, entryPaid: false),
        ];

        final lastEntries = [
          _entry('last-1', divisionNumber: 3, entryPaid: true),
          _entry('last-2', divisionNumber: 3, entryPaid: true),
          _entry('last-3', divisionNumber: 3, entryPaid: true),
        ];

        final penultimateRanked = rankingCalculator.rank(
          entries: penultimateEntries,
          runs: const [],
          divisionNumber: 2,
        );

        final lastRanked = rankingCalculator.rank(
          entries: lastEntries,
          runs: [_run('last-1', 900), _run('last-2', 800), _run('last-3', 700)],
          divisionNumber: 3,
        );

        final settlement = settlementCalculator
            .settlePenultimateAndLastDivision(
              penultimateDivision: penultimateDivision,
              lastDivision: lastDivision,
              penultimateRankedEntries: penultimateRanked,
              lastRankedEntries: lastRanked,
            );

        expect(settlement.promotedPlayerIds, ['last-1', 'last-2', 'last-3']);
        expect(
          settlement.relegatedPlayerIds,
          containsAll(['pen-inactive-1', 'pen-inactive-2', 'pen-inactive-3']),
        );
      },
    );

    test(
      'promotes all possible active last players when inactive penultimate players exceed candidates',
      () {
        const penultimateDivision = LeagueDivision(number: 2, capacity: 20);
        const lastDivision = LeagueDivision(number: 3, capacity: 40);
        final penultimateRanked = rankingCalculator.rank(
          entries: [
            _entry('pen-inactive-1', divisionNumber: 2, entryPaid: false),
            _entry('pen-inactive-2', divisionNumber: 2, entryPaid: false),
            _entry('pen-inactive-3', divisionNumber: 2, entryPaid: false),
            _entry('pen-inactive-4', divisionNumber: 2, entryPaid: false),
          ],
          runs: const [],
          divisionNumber: 2,
        );
        final lastRanked = rankingCalculator.rank(
          entries: [
            _entry('last-active-1', divisionNumber: 3, entryPaid: true),
            _entry('last-active-2', divisionNumber: 3, entryPaid: true),
          ],
          runs: [_run('last-active-1', 900), _run('last-active-2', 800)],
          divisionNumber: 3,
        );

        final settlement = settlementCalculator
            .settlePenultimateAndLastDivision(
              penultimateDivision: penultimateDivision,
              lastDivision: lastDivision,
              penultimateRankedEntries: penultimateRanked,
              lastRankedEntries: lastRanked,
            );

        expect(settlement.relegatedPlayerIds.length, 4);
        expect(settlement.promotedPlayerIds, [
          'last-active-1',
          'last-active-2',
        ]);
      },
    );

    test('last division may close when it has no active players', () {
      const penultimateDivision = LeagueDivision(number: 2, capacity: 20);
      const lastDivision = LeagueDivision(number: 3, capacity: 40);
      final settlement = settlementCalculator.settlePenultimateAndLastDivision(
        penultimateDivision: penultimateDivision,
        lastDivision: lastDivision,
        penultimateRankedEntries: const [],
        lastRankedEntries: [
          _rankingEntry(
            _entry('inactive-last', divisionNumber: 3, entryPaid: false),
            1,
          ),
        ],
      );

      expect(settlement.promotedPlayerIds, isEmpty);
      expect(settlement.lostReservationPlayerIds, ['inactive-last']);
      expect(settlement.closedDivision, isTrue);
    });
  });
}

LeaguePlayerEntry _entry(
  String playerId, {
  int divisionNumber = 1,
  bool entryPaid = true,
  DateTime? registeredAt,
  int lifetimeRuns = 0,
  double lifetimeAverage = 0,
}) {
  return LeaguePlayerEntry(
    playerId: playerId,
    username: playerId,
    divisionNumber: divisionNumber,
    entryPaid: entryPaid,
    registeredAt: registeredAt ?? DateTime(2026, 1, 1, 12),
    lifetimeLeagueTournamentRuns: lifetimeRuns,
    lifetimeAverageScorePerRun: lifetimeAverage,
  );
}

WeeklyLeagueRun _run(
  String playerId,
  int score, {
  int dayOffset = 0,
  int minuteOffset = 0,
}) {
  return WeeklyLeagueRun(
    playerId: playerId,
    score: score,
    completedAt: DateTime(
      2026,
      1,
      5,
      12,
      minuteOffset,
    ).add(Duration(days: dayOffset)),
  );
}

List<WeeklyLeagueRun> _runs(String playerId, List<int> scores) {
  return [
    for (var index = 0; index < scores.length; index += 1)
      _run(playerId, scores[index], minuteOffset: index),
  ];
}

LeagueRankingEntry _rankingEntry(LeaguePlayerEntry entry, int rank) {
  const scoreCalculator = WeeklyLeagueScoreCalculator();
  return LeagueRankingEntry(
    rank: rank,
    playerEntry: entry,
    weeklyScore: scoreCalculator.calculate(playerEntry: entry, runs: const []),
  );
}
