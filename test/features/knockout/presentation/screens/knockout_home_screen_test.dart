import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/domain_error_mapper.dart';
import 'package:stoppy_app/core/backend/idempotency_key.dart';
import 'package:stoppy_app/features/auth/domain/models/auth_state.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:stoppy_app/features/knockout/data/mock_knockout_repository.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_duel_snapshot.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_hall_of_fame_entry.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_entry.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_records.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_player_status.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_registration_result.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_run.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament_history_entry.dart';
import 'package:stoppy_app/features/knockout/domain/repositories/knockout_repository.dart';
import 'package:stoppy_app/features/knockout/presentation/screens/knockout_home_screen.dart';
import 'package:stoppy_app/features/league/domain/models/league_player_entry.dart';
import 'package:stoppy_app/features/league/domain/models/league_ranking_entry.dart';
import 'package:stoppy_app/features/league/domain/models/league_ranking_snapshot.dart';
import 'package:stoppy_app/features/league/domain/models/league_season_id.dart';
import 'package:stoppy_app/features/league/domain/models/league_season_settlement_result.dart';
import 'package:stoppy_app/features/league/domain/models/player_league_achievements.dart';
import 'package:stoppy_app/features/league/domain/models/player_league_records.dart';
import 'package:stoppy_app/features/league/domain/models/weekly_league_history_entry.dart';
import 'package:stoppy_app/features/league/domain/models/weekly_league_run.dart';
import 'package:stoppy_app/features/league/domain/repositories/league_repository.dart';

void main() {
  testWidgets('shows tournament state and registration status', (
    WidgetTester tester,
  ) async {
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 25,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnockoutHomeScreen(
          playerProfile: playerProfile,
          authRepository: _UpdatingAuthRepository(playerProfile),
          knockoutRepository: MockKnockoutRepository(
            now: () => DateTime(2026, 5, 22),
          ),
          onPlayerProfileUpdated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('June Knockout'), findsOneWidget);
    expect(find.text('Status: Registration open'), findsOneWidget);
    expect(find.text('Entry cost: 25 GP'), findsOneWidget);
    expect(find.text('Registration closes: 2026-05-31 23:59'), findsOneWidget);
    expect(find.text('Tournament starts: 2026-06-01 00:00'), findsOneWidget);
    expect(find.text('You are not registered.'), findsOneWidget);
    expect(find.text('Register for Knockout'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Matches will be generated after registration closes.'),
      300,
    );
    expect(
      find.text('Matches will be generated after registration closes.'),
      findsOneWidget,
    );
  });

  testWidgets('successful registration deducts GP and updates status', (
    WidgetTester tester,
  ) async {
    PlayerProfile? updatedProfile;
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 30,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnockoutHomeScreen(
          playerProfile: playerProfile,
          authRepository: _UpdatingAuthRepository(playerProfile),
          knockoutRepository: MockKnockoutRepository(
            now: () => DateTime(2026, 5, 22, 9, 30),
          ),
          onPlayerProfileUpdated: (profile) {
            updatedProfile = profile;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Register for Knockout'));
    await tester.pumpAndSettle();

    expect(updatedProfile?.gamePoints, 5);
    expect(
      find.text('You are registered for this monthly Knockout.'),
      findsOneWidget,
    );
    expect(find.text('Registered'), findsOneWidget);
    expect(find.text('Registered at: 2026-05-22 09:30'), findsOneWidget);
  });

  testWidgets('backend registration uses authoritative profile projection', (
    WidgetTester tester,
  ) async {
    PlayerProfile? updatedProfile;
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 100,
    );
    final authoritativeProfile = playerProfile.copyWith(gamePoints: 80);
    final repository = _ServerAuthoritativeKnockoutScreenRepository(
      initialTournament: _registrationTournament(),
      registrationOutcomes: [
        _registrationSuccess(
          tournament: _registrationTournamentWithEntry(),
          playerProfile: authoritativeProfile,
          remainingGamePoints: 80,
        ),
      ],
    );
    final authRepository = _UpdatingAuthRepository(playerProfile);

    await tester.pumpWidget(
      MaterialApp(
        home: KnockoutHomeScreen(
          playerProfile: playerProfile,
          authRepository: authRepository,
          knockoutRepository: repository,
          onPlayerProfileUpdated: (profile) {
            updatedProfile = profile;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Register for Knockout'));
    await tester.pumpAndSettle();

    expect(updatedProfile?.gamePoints, 80);
    expect(authRepository.updateCalls, 0);
    expect(find.text('Your GP: 80'), findsOneWidget);
    expect(
      find.text('You are registered for this monthly Knockout.'),
      findsOneWidget,
    );
  });

  testWidgets('backend registration uses remaining GP without profile', (
    WidgetTester tester,
  ) async {
    PlayerProfile? updatedProfile;
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 100,
    );
    final repository = _ServerAuthoritativeKnockoutScreenRepository(
      initialTournament: _registrationTournament(),
      registrationOutcomes: [
        _registrationSuccess(
          tournament: _registrationTournamentWithEntry(),
          playerProfile: null,
          remainingGamePoints: 75,
        ),
      ],
    );
    final authRepository = _UpdatingAuthRepository(playerProfile);

    await tester.pumpWidget(
      MaterialApp(
        home: KnockoutHomeScreen(
          playerProfile: playerProfile,
          authRepository: authRepository,
          knockoutRepository: repository,
          onPlayerProfileUpdated: (profile) {
            updatedProfile = profile;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Register for Knockout'));
    await tester.pumpAndSettle();

    expect(updatedProfile?.gamePoints, 75);
    expect(authRepository.updateCalls, 0);
    expect(find.text('Your GP: 75'), findsOneWidget);
    expect(
      find.text('You are registered for this monthly Knockout.'),
      findsOneWidget,
    );
    expect(find.text('Registered'), findsOneWidget);
  });

  testWidgets('ambiguous backend registration retry reuses same key', (
    WidgetTester tester,
  ) async {
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 100,
    );
    final repository = _ServerAuthoritativeKnockoutScreenRepository(
      initialTournament: _registrationTournament(),
      registrationOutcomes: [
        const _AsynchronousRegistrationFailure(
          RepositoryDomainException(
            'Network unavailable. Please try again.',
            code: ApiErrorCode.networkUnavailable,
          ),
        ),
        _registrationSuccess(
          tournament: _registrationTournamentWithEntry(),
          playerProfile: playerProfile.copyWith(gamePoints: 75),
          remainingGamePoints: 75,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnockoutHomeScreen(
          playerProfile: playerProfile,
          authRepository: _UpdatingAuthRepository(playerProfile),
          knockoutRepository: repository,
          onPlayerProfileUpdated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Register for Knockout'));
    await tester.pumpAndSettle();
    expect(find.text('Network unavailable. Please try again.'), findsOneWidget);

    await tester.tap(find.text('Register for Knockout'));
    await tester.pumpAndSettle();

    expect(repository.registrationKeys.length, 2);
    expect(repository.registrationKeys[1], repository.registrationKeys[0]);
    final reusedKey = repository.registrationKeys.first!.value;
    expect(reusedKey, isNot(contains(playerProfile.id)));
    expect(reusedKey, isNot(contains('2026-06')));
    expect(IdempotencyKey(reusedKey).value, reusedKey);
    expect(
      find.text('You are registered for this monthly Knockout.'),
      findsOneWidget,
    );
  });

  testWidgets('malformed backend registration response keeps retry key', (
    WidgetTester tester,
  ) async {
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 100,
    );
    final repository = _ServerAuthoritativeKnockoutScreenRepository(
      initialTournament: _registrationTournament(),
      registrationOutcomes: [
        const _AsynchronousRegistrationFailure(
          RepositoryDomainException(
            'Received an invalid response. Please try again later.',
            code: ApiErrorCode.malformedPayload,
          ),
        ),
        _registrationSuccess(
          tournament: _registrationTournamentWithEntry(),
          playerProfile: playerProfile.copyWith(gamePoints: 75),
          remainingGamePoints: 75,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnockoutHomeScreen(
          playerProfile: playerProfile,
          authRepository: _UpdatingAuthRepository(playerProfile),
          knockoutRepository: repository,
          onPlayerProfileUpdated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Register for Knockout'));
    await tester.pumpAndSettle();
    expect(
      find.text('Received an invalid response. Please try again later.'),
      findsOneWidget,
    );
    expect(repository.registrationKeys.length, 1);

    await tester.tap(find.text('Register for Knockout'));
    await tester.pumpAndSettle();

    expect(repository.registrationKeys.length, 2);
    expect(repository.registrationKeys[1], repository.registrationKeys[0]);
    expect(
      find.text('You are registered for this monthly Knockout.'),
      findsOneWidget,
    );
  });

  testWidgets('unexpected backend registration response keeps retry key', (
    WidgetTester tester,
  ) async {
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 100,
    );
    final repository = _ServerAuthoritativeKnockoutScreenRepository(
      initialTournament: _registrationTournament(),
      registrationOutcomes: [
        const _AsynchronousRegistrationFailure(
          RepositoryDomainException(
            'Unexpected backend response. Please try again.',
            code: ApiErrorCode.unexpectedResponse,
          ),
        ),
        _registrationSuccess(
          tournament: _registrationTournamentWithEntry(),
          playerProfile: playerProfile.copyWith(gamePoints: 75),
          remainingGamePoints: 75,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnockoutHomeScreen(
          playerProfile: playerProfile,
          authRepository: _UpdatingAuthRepository(playerProfile),
          knockoutRepository: repository,
          onPlayerProfileUpdated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Register for Knockout'));
    await tester.pumpAndSettle();
    expect(
      find.text('Unexpected backend response. Please try again.'),
      findsOneWidget,
    );
    expect(repository.registrationKeys.length, 1);

    await tester.tap(find.text('Register for Knockout'));
    await tester.pumpAndSettle();

    expect(repository.registrationKeys.length, 2);
    expect(repository.registrationKeys[1], repository.registrationKeys[0]);
    expect(
      find.text('You are registered for this monthly Knockout.'),
      findsOneWidget,
    );
  });

  testWidgets('definitive backend registration rejection clears retry key', (
    WidgetTester tester,
  ) async {
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 100,
    );
    final repository = _ServerAuthoritativeKnockoutScreenRepository(
      initialTournament: _registrationTournament(),
      registrationOutcomes: [
        KnockoutRegistrationResult.failure(
          tournament: _registrationTournament(),
          failureReason:
              KnockoutRegistrationFailureReason.insufficientGamePoints,
          message: 'You need 25 GP to register.',
        ),
        _registrationSuccess(
          tournament: _registrationTournamentWithEntry(),
          playerProfile: playerProfile.copyWith(gamePoints: 75),
          remainingGamePoints: 75,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnockoutHomeScreen(
          playerProfile: playerProfile,
          authRepository: _UpdatingAuthRepository(playerProfile),
          knockoutRepository: repository,
          onPlayerProfileUpdated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Register for Knockout'));
    await tester.pumpAndSettle();
    expect(find.text('You need 25 GP to register.'), findsOneWidget);

    await tester.tap(find.text('Register for Knockout'));
    await tester.pumpAndSettle();

    expect(repository.registrationKeys.length, 2);
    expect(
      repository.registrationKeys[1],
      isNot(repository.registrationKeys[0]),
    );
    expect(
      find.text('You are registered for this monthly Knockout.'),
      findsOneWidget,
    );
  });

  testWidgets('backend registration ignores duplicate taps while pending', (
    WidgetTester tester,
  ) async {
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 100,
    );
    final completer = Completer<KnockoutRegistrationResult>();
    final repository = _ServerAuthoritativeKnockoutScreenRepository(
      initialTournament: _registrationTournament(),
      registrationOutcomes: [completer.future],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnockoutHomeScreen(
          playerProfile: playerProfile,
          authRepository: _UpdatingAuthRepository(playerProfile),
          knockoutRepository: repository,
          onPlayerProfileUpdated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Register for Knockout'));
    await tester.pump();
    await tester.tap(find.text('Register for Knockout'), warnIfMissed: false);

    expect(repository.registrationKeys.length, 1);

    completer.complete(
      _registrationSuccess(
        tournament: _registrationTournamentWithEntry(),
        playerProfile: playerProfile.copyWith(gamePoints: 75),
        remainingGamePoints: 75,
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('synchronous backend registration failure is handled', (
    WidgetTester tester,
  ) async {
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 100,
    );
    final repository = _ServerAuthoritativeKnockoutScreenRepository(
      initialTournament: _registrationTournament(),
      registrationOutcomes: [
        const _SynchronousRegistrationFailure(
          RepositoryDomainException(
            'Received an invalid response. Please try again later.',
            code: ApiErrorCode.malformedPayload,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnockoutHomeScreen(
          playerProfile: playerProfile,
          authRepository: _UpdatingAuthRepository(playerProfile),
          knockoutRepository: repository,
          onPlayerProfileUpdated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Register for Knockout'));
    await tester.pumpAndSettle();

    expect(
      find.text('Received an invalid response. Please try again later.'),
      findsOneWidget,
    );
    expect(find.text('Register for Knockout'), findsOneWidget);
    expect(repository.registrationKeys.length, 1);
  });

  testWidgets('updates local player profile when parent profile changes', (
    WidgetTester tester,
  ) async {
    final repository = MockKnockoutRepository(now: () => DateTime(2026, 5, 22));

    final initialProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 25,
    );

    final updatedProfile = initialProfile.copyWith(gamePoints: 75);

    await tester.pumpWidget(
      MaterialApp(
        home: KnockoutHomeScreen(
          playerProfile: initialProfile,
          authRepository: _UpdatingAuthRepository(initialProfile),
          knockoutRepository: repository,
          onPlayerProfileUpdated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your GP: 25'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: KnockoutHomeScreen(
          playerProfile: updatedProfile,
          authRepository: _UpdatingAuthRepository(updatedProfile),
          knockoutRepository: repository,
          onPlayerProfileUpdated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your GP: 75'), findsOneWidget);
    expect(find.text('Your GP: 25'), findsNothing);
  });

  testWidgets('insufficient GP shows registration error', (
    WidgetTester tester,
  ) async {
    PlayerProfile? updatedProfile;
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 24,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnockoutHomeScreen(
          playerProfile: playerProfile,
          authRepository: _UpdatingAuthRepository(playerProfile),
          knockoutRepository: MockKnockoutRepository(
            now: () => DateTime(2026, 5, 22),
          ),
          onPlayerProfileUpdated: (profile) {
            updatedProfile = profile;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Register for Knockout'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('You need 25 GP to register.'), findsOneWidget);
    expect(updatedProfile, isNull);
    expect(find.text('You are not registered.'), findsOneWidget);
  });

  testWidgets('shows active duel score details', (WidgetTester tester) async {
    final repository = MockKnockoutRepository(
      now: () => DateTime(2026, 5, 22, 9),
    );
    final tournament = await repository.fetchCurrentTournament();
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 50,
    );
    final opponentProfile = PlayerProfile(
      id: 'opponent-id',
      username: 'Opponent',
      createdAt: DateTime(2026),
      gamePoints: 50,
    );

    await repository.registerPlayer(
      tournament: tournament,
      playerProfile: playerProfile,
    );
    await repository.registerPlayer(
      tournament: tournament,
      playerProfile: opponentProfile,
    );
    final startedTournament = await repository.startTournament(
      tournamentId: tournament.id,
    );
    final duel = await repository.fetchActiveDuel(
      tournamentId: startedTournament.id,
      playerId: playerProfile.id,
    );
    await repository.submitKnockoutRun(
      KnockoutRun(
        id: 'run-1',
        playerId: playerProfile.id,
        matchId: duel!.match.id,
        roundNumber: duel.roundNumber,
        score: 700,
        completedAt: DateTime(2026, 6, 1, 9),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnockoutHomeScreen(
          playerProfile: playerProfile,
          authRepository: _UpdatingAuthRepository(playerProfile),
          knockoutRepository: repository,
          onPlayerProfileUpdated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tournament Status'), findsOneWidget);
    expect(find.text('Active duel'), findsOneWidget);
    expect(find.text('Opponent: Opponent'), findsOneWidget);
    expect(find.text('Your score: 700 (1 runs)'), findsOneWidget);
    expect(find.text('Opponent score: 0 (0 runs)'), findsOneWidget);
    expect(find.text('Round settles: 2026-06-01 23:59'), findsOneWidget);
    expect(find.text('Play tournament run'), findsOneWidget);
  });

  testWidgets('shows registered waiting state before tournament start', (
    WidgetTester tester,
  ) async {
    final repository = MockKnockoutRepository(
      now: () => DateTime(2026, 5, 22, 9),
    );
    final tournament = await repository.fetchCurrentTournament();
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 50,
    );
    await repository.registerPlayer(
      tournament: tournament,
      playerProfile: playerProfile,
    );

    await _pumpKnockoutHome(tester, repository, playerProfile);

    expect(
      find.text('Registered - waiting for tournament start'),
      findsOneWidget,
    );
    expect(
      find.text('Your duel will appear when the tournament starts.'),
      findsOneWidget,
    );
  });

  testWidgets('shows bye waiting state', (WidgetTester tester) async {
    final repository = MockKnockoutRepository(
      now: () => DateTime(2026, 5, 22, 9),
    );
    final tournament = await repository.fetchCurrentTournament();
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 50,
    );
    await repository.registerPlayer(
      tournament: tournament,
      playerProfile: playerProfile,
    );
    await repository.startTournament(tournamentId: tournament.id);

    await _pumpKnockoutHome(tester, repository, playerProfile);

    expect(find.text('Bye - waiting for next round'), findsOneWidget);
    expect(find.text('Round 1: bye advanced'), findsOneWidget);
  });

  testWidgets('shows eliminated state', (WidgetTester tester) async {
    var now = DateTime(2026, 5, 22, 9);
    final repository = MockKnockoutRepository(now: () => now);
    final tournament = await repository.fetchCurrentTournament();
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 50,
    );
    final opponentProfile = PlayerProfile(
      id: 'opponent-id',
      username: 'Opponent',
      createdAt: DateTime(2026),
      gamePoints: 50,
    );
    await repository.registerPlayer(
      tournament: tournament,
      playerProfile: playerProfile,
    );
    await repository.registerPlayer(
      tournament: tournament,
      playerProfile: opponentProfile,
    );
    final startedTournament = await repository.startTournament(
      tournamentId: tournament.id,
    );
    final duel = await repository.fetchActiveDuel(
      tournamentId: startedTournament.id,
      playerId: opponentProfile.id,
    );
    await repository.submitKnockoutRun(
      KnockoutRun(
        id: 'opponent-run',
        playerId: opponentProfile.id,
        matchId: duel!.match.id,
        roundNumber: duel.roundNumber,
        score: 1000,
        completedAt: DateTime(2026, 6, 1, 10),
      ),
    );
    now = DateTime(2026, 6, 1, 23, 59);
    await repository.settleCurrentRound(tournamentId: startedTournament.id);

    await _pumpKnockoutHome(tester, repository, playerProfile);

    expect(find.text('Eliminated'), findsOneWidget);
    expect(find.text('Your tournament run has ended.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Tournament History'), 300);
    expect(find.text('June Knockout: Eliminated • Round 1'), findsOneWidget);
  });

  testWidgets('shows champion state', (WidgetTester tester) async {
    var now = DateTime(2026, 5, 22, 9);
    final repository = MockKnockoutRepository(now: () => now);
    final tournament = await repository.fetchCurrentTournament();
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 50,
    );
    final opponentProfile = PlayerProfile(
      id: 'opponent-id',
      username: 'Opponent',
      createdAt: DateTime(2026),
      gamePoints: 50,
    );
    await repository.registerPlayer(
      tournament: tournament,
      playerProfile: playerProfile,
    );
    await repository.registerPlayer(
      tournament: tournament,
      playerProfile: opponentProfile,
    );
    final startedTournament = await repository.startTournament(
      tournamentId: tournament.id,
    );
    final duel = await repository.fetchActiveDuel(
      tournamentId: startedTournament.id,
      playerId: playerProfile.id,
    );
    await repository.submitKnockoutRun(
      KnockoutRun(
        id: 'winner-run',
        playerId: playerProfile.id,
        matchId: duel!.match.id,
        roundNumber: duel.roundNumber,
        score: 1000,
        completedAt: DateTime(2026, 6, 1, 10),
      ),
    );
    now = DateTime(2026, 6, 1, 23, 59);
    await repository.settleCurrentRound(tournamentId: startedTournament.id);

    await _pumpKnockoutHome(tester, repository, playerProfile);

    expect(find.text('Tournament champion'), findsOneWidget);
    expect(find.text('You won this monthly Knockout.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Personal Knockout Records'),
      300,
    );
    expect(find.text('Tournaments played: 1'), findsOneWidget);
    expect(find.text('Titles won: 1'), findsOneWidget);
    expect(find.text('Best tournament result: Champion'), findsOneWidget);
    expect(find.text('Tournaments participated: 1'), findsWidgets);
    expect(find.text('Total duels played: 1'), findsWidgets);
    expect(find.text('Total duels won: 1'), findsOneWidget);
    expect(find.text('Duel win percentage: 100.0%'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Knockout Hall of Fame'), 300);
    expect(find.text('Tester • 1 title'), findsOneWidget);
    expect(find.text('Won: June 2026'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Tournament History'), 300);
    expect(find.text('June Knockout: Champion • Round 1'), findsOneWidget);
  });

  testWidgets('shows combined competitive achievements from repositories', (
    WidgetTester tester,
  ) async {
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 50,
    );
    final repository = MockKnockoutRepository(
      initialRecordsByPlayerId: {
        playerProfile.id: const KnockoutPlayerRecords(
          playerId: 'player-id',
          tournamentsPlayed: 4,
          tournamentsWon: 1,
          highestRoundReached: 5,
          totalDuelsPlayed: 12,
          totalDuelsWon: 9,
        ),
      },
    );
    final leagueRepository = _AchievementLeagueRepository(
      PlayerLeagueAchievements(
        playerId: playerProfile.id,
        bestDivisionReached: 2,
        promotions: 3,
        relegations: 1,
      ),
    );

    await _pumpKnockoutHome(
      tester,
      repository,
      playerProfile,
      leagueRepository: leagueRepository,
    );

    await tester.scrollUntilVisible(find.text('Competitive Achievements'), 300);

    expect(find.text('League'), findsOneWidget);
    expect(find.text('Best division reached: Division 2'), findsOneWidget);
    expect(find.text('Promotions: 3'), findsOneWidget);
    expect(find.text('Relegations: 1'), findsOneWidget);
    expect(find.text('Knockout'), findsWidgets);
    expect(find.text('Best round reached: Round 5'), findsOneWidget);
    expect(find.text('Tournaments participated: 4'), findsWidgets);
    expect(find.text('Duel win percentage: 75.0%'), findsWidgets);
    expect(find.text('Total duels played: 12'), findsWidgets);
  });

  testWidgets('limits visible tournament history entries', (
    WidgetTester tester,
  ) async {
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 50,
    );

    final history = [
      for (var index = 0; index < 12; index += 1)
        KnockoutTournamentHistoryEntry(
          tournamentId: '2026-${index + 1}',
          tournamentName: 'Tournament $index',
          tournamentMonth: DateTime(2026, index + 1),
          playerId: playerProfile.id,
          outcome: KnockoutTournamentOutcome.eliminated,
          finalRoundNumber: 1,
          completedAt: DateTime(2026, index + 1, 1),
        ),
    ];

    final repository = MockKnockoutRepository(
      initialHistoryByPlayerId: {playerProfile.id: history},
    );

    await _pumpKnockoutHome(tester, repository, playerProfile);

    await tester.scrollUntilVisible(find.text('Tournament History'), 300);

    for (var index = 2; index < 12; index += 1) {
      expect(
        find.text('Tournament $index: Eliminated • Round 1'),
        findsOneWidget,
      );
    }

    expect(find.text('Tournament 0: Eliminated • Round 1'), findsNothing);
    expect(find.text('Tournament 1: Eliminated • Round 1'), findsNothing);

    expect(find.text('+2 older tournament results hidden'), findsOneWidget);
  });

  testWidgets('shows empty champion-only Hall of Fame', (
    WidgetTester tester,
  ) async {
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026),
      gamePoints: 50,
    );

    final repository = MockKnockoutRepository(
      initialHistoryByPlayerId: {
        playerProfile.id: [
          KnockoutTournamentHistoryEntry(
            tournamentId: '2026-06',
            tournamentName: 'June Knockout',
            tournamentMonth: DateTime(2026, 6),
            playerId: playerProfile.id,
            playerUsername: playerProfile.username,
            outcome: KnockoutTournamentOutcome.eliminated,
            finalRoundNumber: 1,
            completedAt: DateTime(2026, 6, 1),
          ),
        ],
      },
    );

    await _pumpKnockoutHome(tester, repository, playerProfile);

    await tester.scrollUntilVisible(find.text('Knockout Hall of Fame'), 300);

    expect(find.text('No Knockout champions yet.'), findsOneWidget);
    expect(find.text('Tester: 1 title'), findsNothing);
  });

  testWidgets(
    'keeps non-registered player as not registered after completion',
    (WidgetTester tester) async {
      final playerProfile = PlayerProfile(
        id: 'player-id',
        username: 'Tester',
        createdAt: DateTime(2026),
        gamePoints: 50,
      );
      final repository = MockKnockoutRepository(
        initialTournament: KnockoutTournament(
          id: '2026-06',
          name: 'June Knockout',
          entryCostGamePoints: 25,
          tournamentMonth: DateTime(2026, 6),
          registrationOpensAt: DateTime(2026, 5),
          registrationClosesAt: DateTime(2026, 5, 31, 23, 59),
          startsAt: DateTime(2026, 6),
          status: KnockoutTournamentStatus.completed,
        ),
        now: () => DateTime(2026, 6, 30),
      );

      await _pumpKnockoutHome(tester, repository, playerProfile);

      expect(find.text('Not registered'), findsOneWidget);
      expect(
        find.text('Register while the monthly window is open.'),
        findsOneWidget,
      );
    },
  );
}

Future<void> _pumpKnockoutHome(
  WidgetTester tester,
  MockKnockoutRepository repository,
  PlayerProfile playerProfile, {
  LeagueRepository? leagueRepository,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: KnockoutHomeScreen(
        playerProfile: playerProfile,
        authRepository: _UpdatingAuthRepository(playerProfile),
        knockoutRepository: repository,
        onPlayerProfileUpdated: (_) {},
        leagueRepository: leagueRepository,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _AchievementLeagueRepository implements LeagueRepository {
  const _AchievementLeagueRepository(this.achievements);

  final PlayerLeagueAchievements achievements;

  @override
  Future<LeaguePlayerEntry?> currentEntry(String playerId) async {
    return null;
  }

  @override
  Future<LeaguePlayerEntry> enterWeeklyLeague(
    PlayerProfile profile, {
    IdempotencyKey? idempotencyKey,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<LeagueRankingEntry>> fetchDivisionRanking(
    int divisionNumber,
  ) async {
    return const [];
  }

  @override
  Future<PlayerLeagueAchievements> fetchPlayerAchievements(
    String playerId,
  ) async {
    return achievements;
  }

  @override
  Future<PlayerLeagueRecords> fetchPlayerRecords(String playerId) async {
    return PlayerLeagueRecords.empty(playerId);
  }

  @override
  Future<List<WeeklyLeagueHistoryEntry>> fetchPlayerHistory(
    String playerId,
  ) async {
    return const [];
  }

  @override
  Future<List<WeeklyLeagueRun>> fetchPlayerWeeklyRuns({
    required String playerId,
    required LeagueSeasonId seasonId,
  }) async {
    return const [];
  }

  @override
  Future<LeagueRankingSnapshot> fetchPlayerSnapshot({
    required String playerId,
    required int divisionNumber,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<LeagueSeasonSettlementResult> settleCurrentSeason({
    required DateTime now,
  }) async {
    return LeagueSeasonSettlementResult(
      seasonId: LeagueSeasonId.fromDate(now),
      settledAt: now,
      executed: false,
    );
  }

  @override
  Future<LeagueRunSubmissionResult> submitLeagueRun(
    WeeklyLeagueRun run, {
    IdempotencyKey? idempotencyKey,
  }) async {
    return LeagueRunSubmissionResult(
      accepted: false,
      playerRecords: PlayerLeagueRecords.empty(run.playerId),
    );
  }
}

class _UpdatingAuthRepository implements AuthRepository {
  _UpdatingAuthRepository(this.playerProfile);

  PlayerProfile playerProfile;
  int updateCalls = 0;

  @override
  Future<AuthState> currentAuthState() async {
    return AuthState.authenticated(playerProfile);
  }

  @override
  Future<PlayerProfile> login({
    required String username,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {}

  @override
  Future<PlayerProfile> register({
    required String username,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PlayerProfile> updatePlayerProfile(PlayerProfile playerProfile) async {
    updateCalls += 1;
    this.playerProfile = playerProfile;
    return playerProfile;
  }
}

class _ServerAuthoritativeKnockoutScreenRepository
    implements
        KnockoutRepository,
        ServerAuthoritativeKnockoutRegistrationRepository {
  _ServerAuthoritativeKnockoutScreenRepository({
    required KnockoutTournament initialTournament,
    required List<Object> registrationOutcomes,
  }) : _tournament = initialTournament,
       _registrationOutcomes = [...registrationOutcomes];

  KnockoutTournament _tournament;
  KnockoutPlayerEntry? _entry;
  final List<Object> _registrationOutcomes;
  final List<IdempotencyKey?> registrationKeys = [];

  @override
  Future<KnockoutTournament> fetchCurrentTournament() async => _tournament;

  @override
  Future<KnockoutPlayerEntry?> currentEntry({
    required String tournamentId,
    required String playerId,
  }) async {
    final entry = _entry;
    if (entry == null ||
        entry.tournamentId != tournamentId ||
        entry.playerId != playerId) {
      return null;
    }
    return entry;
  }

  @override
  Future<KnockoutPlayerStatus> fetchPlayerStatus({
    required String tournamentId,
    required String playerId,
  }) async {
    return KnockoutPlayerStatus(
      state: _entry == null
          ? KnockoutPlayerTournamentState.notRegistered
          : KnockoutPlayerTournamentState.registeredWaitingStart,
    );
  }

  @override
  Future<KnockoutRegistrationResult> registerPlayer({
    required KnockoutTournament tournament,
    required PlayerProfile playerProfile,
    IdempotencyKey? idempotencyKey,
  }) {
    registrationKeys.add(idempotencyKey);
    if (_registrationOutcomes.isEmpty) {
      throw StateError('No Knockout registration outcome queued.');
    }

    final outcome = _registrationOutcomes.removeAt(0);
    if (outcome is _SynchronousRegistrationFailure) {
      throw outcome.error;
    }
    if (outcome is _AsynchronousRegistrationFailure) {
      return Future<KnockoutRegistrationResult>.error(outcome.error);
    }
    if (outcome is Future<KnockoutRegistrationResult>) {
      return outcome.then(_recordRegistrationResult);
    }
    if (outcome is KnockoutRegistrationResult) {
      return Future.value(_recordRegistrationResult(outcome));
    }
    throw StateError('Unsupported Knockout registration outcome.');
  }

  KnockoutRegistrationResult _recordRegistrationResult(
    KnockoutRegistrationResult result,
  ) {
    if (result.isSuccess && result.playerEntry != null) {
      _entry = result.playerEntry;
      _tournament = result.tournament;
    }
    return result;
  }

  @override
  Future<KnockoutDuelSnapshot?> fetchActiveDuel({
    required String tournamentId,
    required String playerId,
  }) async {
    return null;
  }

  @override
  Future<KnockoutPlayerRecords> fetchPlayerRecords(String playerId) async {
    return KnockoutPlayerRecords.empty(playerId);
  }

  @override
  Future<List<KnockoutTournamentHistoryEntry>> fetchPlayerHistory(
    String playerId,
  ) async {
    return const [];
  }

  @override
  Future<List<KnockoutHallOfFameEntry>> fetchHallOfFame() async {
    return const [];
  }

  @override
  Future<KnockoutTournament> closeRegistration({required String tournamentId}) {
    throw UnimplementedError();
  }

  @override
  Future<KnockoutTournament> startTournament({required String tournamentId}) {
    throw UnimplementedError();
  }

  @override
  Future<bool> submitKnockoutRun(
    KnockoutRun run, {
    IdempotencyKey? idempotencyKey,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<KnockoutTournament> settleCurrentRound({
    required String tournamentId,
  }) {
    throw UnimplementedError();
  }
}

final class _SynchronousRegistrationFailure {
  const _SynchronousRegistrationFailure(this.error);

  final Exception error;
}

final class _AsynchronousRegistrationFailure {
  const _AsynchronousRegistrationFailure(this.error);

  final Exception error;
}

KnockoutRegistrationResult _registrationSuccess({
  required KnockoutTournament tournament,
  required PlayerProfile? playerProfile,
  required int remainingGamePoints,
}) {
  return KnockoutRegistrationResult.success(
    tournament: tournament,
    playerEntry: tournament.entries.single,
    remainingGamePoints: remainingGamePoints,
    playerProfile: playerProfile,
  );
}

KnockoutTournament _registrationTournament() {
  return KnockoutTournament(
    id: '2026-06',
    name: 'June Knockout',
    entryCostGamePoints: 25,
    tournamentMonth: DateTime(2026, 6),
    registrationOpensAt: DateTime(2026, 5),
    registrationClosesAt: DateTime(2026, 5, 31, 23, 59),
    startsAt: DateTime(2026, 6),
  );
}

KnockoutTournament _registrationTournamentWithEntry() {
  return _registrationTournament().copyWith(
    entries: [
      KnockoutPlayerEntry(
        playerId: 'player-id',
        username: 'Tester',
        tournamentId: '2026-06',
        registeredAt: DateTime(2026, 5, 22, 9, 30),
        accountCreatedAt: DateTime(2026),
        entryCostGamePoints: 25,
      ),
    ],
  );
}
