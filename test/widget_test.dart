import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/auth/data/mock_auth_repository.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/auth/presentation/screens/login_screen.dart';
import 'package:stoppy_app/features/auth/presentation/screens/register_screen.dart';
import 'package:stoppy_app/features/ads/data/mock_ad_repository.dart';
import 'package:stoppy_app/features/ads/domain/models/ad_type.dart';
import 'package:stoppy_app/features/game/domain/economy/run_mode.dart';
import 'package:stoppy_app/features/game/domain/models/difficulty_state.dart';
import 'package:stoppy_app/features/game/domain/models/game_level_config.dart';
import 'package:stoppy_app/features/game/domain/models/movement_direction.dart';
import 'package:stoppy_app/features/game/game_screen.dart';
import 'package:stoppy_app/features/game/rendering/game_area_painter.dart';
import 'package:stoppy_app/features/knockout/presentation/screens/knockout_home_screen.dart';
import 'package:stoppy_app/features/league/domain/models/league_player_entry.dart';
import 'package:stoppy_app/features/league/domain/models/league_ranking_entry.dart';
import 'package:stoppy_app/features/league/domain/models/league_ranking_snapshot.dart';
import 'package:stoppy_app/features/league/domain/models/league_season_id.dart';
import 'package:stoppy_app/features/league/domain/models/league_season_settlement_result.dart';
import 'package:stoppy_app/features/league/domain/models/player_league_records.dart';
import 'package:stoppy_app/features/league/domain/models/weekly_league_history_entry.dart';
import 'package:stoppy_app/features/league/domain/models/weekly_league_run.dart';
import 'package:stoppy_app/features/league/domain/repositories/league_repository.dart';
import 'package:stoppy_app/features/purchases/data/mock_purchase_repository.dart';
import 'package:stoppy_app/features/purchases/presentation/screens/store_screen.dart';
import 'package:stoppy_app/main.dart';
import 'package:stoppy_app/features/knockout/data/mock_knockout_repository.dart';
import 'package:stoppy_app/features/knockout/domain/models/knockout_tournament.dart';

void main() {
  Future<MockAuthRepository> authenticatedRepository() async {
    final repository = MockAuthRepository();
    await repository.register(username: 'Tester', password: 'pass123');
    return repository;
  }

  testWidgets('Stoppy app shows auth flow before login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(StoppyApp(authRepository: MockAuthRepository()));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(GameScreen), findsNothing);
    expect(find.text('Login'), findsWidgets);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('Registering a player opens the game screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(StoppyApp(authRepository: MockAuthRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'NewPlayer');
    await tester.enterText(find.byType(TextFormField).at(1), 'pass123');
    await tester.tap(find.widgetWithText(FilledButton, 'Register'));
    await tester.pumpAndSettle();

    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.text('Mode: Warmup'), findsOneWidget);
    expect(_gameAreaPainterFinder(), findsOneWidget);
  });

  testWidgets('Stoppy app shows the game rendering surface', (
    WidgetTester tester,
  ) async {
    final repository = await authenticatedRepository();

    await tester.pumpWidget(StoppyApp(authRepository: repository));
    await tester.pumpAndSettle();

    expect(find.byType(GameScreen), findsOneWidget);
    expect(_gameAreaPainterFinder(), findsOneWidget);
  });

  testWidgets('Player with weekly entry starts in league mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          playerProfile: PlayerProfile(
            id: 'league-player',
            username: 'LeaguePlayer',
            createdAt: DateTime(2026, 5, 1),
            gamePoints: 5,
            hasWeeklyLeagueEntry: true,
          ),
        ),
      ),
    );

    expect(find.text('Mode: League'), findsOneWidget);
  });

  testWidgets('Player below 10 GP without weekly entry starts in warmup mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          playerProfile: PlayerProfile(
            id: 'warmup-player',
            username: 'WarmupPlayer',
            createdAt: DateTime(2026, 5, 1),
            gamePoints: 5,
            hasWeeklyLeagueEntry: false,
          ),
        ),
      ),
    );

    expect(find.text('Mode: Warmup'), findsOneWidget);
  });

  testWidgets('Store button opens store products for authenticated player', (
    WidgetTester tester,
  ) async {
    final repository = await authenticatedRepository();

    await tester.pumpWidget(
      StoppyApp(
        authRepository: repository,
        purchaseRepository: const MockPurchaseRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Store'), findsOneWidget);

    await tester.tap(find.text('Store'));
    await tester.pumpAndSettle();

    expect(find.byType(StoreScreen), findsOneWidget);
    expect(find.text('Small GP Pack'), findsOneWidget);
    expect(find.text('Large GP Pack'), findsOneWidget);
    expect(find.text('Remove Ads'), findsOneWidget);
    expect(find.textContaining('GP:'), findsAtLeastNWidgets(1));
    expect(find.text('Ads removed: No'), findsOneWidget);
  });

  testWidgets('Knockout button opens knockout registration screen', (
    WidgetTester tester,
  ) async {
    final repository = await authenticatedRepository();

    await tester.pumpWidget(StoppyApp(authRepository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Knockout'));
    await tester.pumpAndSettle();

    expect(find.byType(KnockoutHomeScreen), findsOneWidget);
    expect(find.text('Register for Knockout'), findsOneWidget);
  });

  testWidgets('Knockout screen shows generated tournament rounds after start', (
    WidgetTester tester,
  ) async {
    final repository = await authenticatedRepository();
    final knockoutRepository = MockKnockoutRepository(
      now: () => DateTime(2026, 6),
    );

    final tournament = await knockoutRepository.fetchCurrentTournament();

    for (var index = 0; index < 35; index += 1) {
      await knockoutRepository.registerPlayer(
        tournament: tournament,
        playerProfile: PlayerProfile(
          id: 'player-$index',
          username: 'Player $index',
          createdAt: DateTime(2026),
          gamePoints: 100,
        ),
      );
    }

    final startedTournament = await knockoutRepository.startTournament(
      tournamentId: tournament.id,
    );

    expect(startedTournament.status, KnockoutTournamentStatus.inProgress);

    await tester.pumpWidget(
      StoppyApp(
        authRepository: repository,
        knockoutRepository: knockoutRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Knockout'));
    await tester.pumpAndSettle();

    expect(find.byType(KnockoutHomeScreen), findsOneWidget);
    expect(find.textContaining('Status:'), findsWidgets);
    await tester.scrollUntilVisible(find.textContaining('Round 1'), 300);
    expect(find.textContaining('Round 1'), findsOneWidget);
    expect(find.textContaining('3 matches'), findsOneWidget);
    expect(find.textContaining('29 byes'), findsOneWidget);
  });

  testWidgets('Game screen uses the game area painter', (
    WidgetTester tester,
  ) async {
    final repository = await authenticatedRepository();

    await tester.pumpWidget(StoppyApp(authRepository: repository));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));

    final customPaint = tester.widget<CustomPaint>(_gameAreaPainterFinder());

    expect(customPaint.painter, isA<GameAreaPainter>());
    expect(find.text('Max PP\n100'), findsOneWidget);
  });

  testWidgets('Tapping the game screen shows PP summary before next level', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GameScreen(
          initialDifficultyState: DifficultyState.initial(),
          initialLevelConfig: GameLevelConfig(
            ballRotationDuration: Duration(seconds: 3),
            ballRadius: 18,
            stopTimeLimit: Duration(seconds: 30),
            safeZoneSweepAngle: 1,
            safeZoneRotationDuration: null,
            targetRotationDuration: null,
            ballStartAngle: -0.45,
            safeZoneStartAngle: -0.5,
            targetStartAngle: 2,
            ballDirection: MovementDirection.clockwise,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(GameScreen));
    await tester.pump();

    expect(find.text('Reward Summary'), findsNothing);
    expect(find.text('Next Level'), findsNothing);

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Reward Summary'), findsOneWidget);
    expect(find.textContaining('PP earned:'), findsOneWidget);
    expect(find.textContaining('Total PP:'), findsOneWidget);
    expect(find.textContaining('Target hit! Next level max PP:'), findsNothing);
    expect(find.text('Next Level'), findsOneWidget);

    await tester.tap(find.text('Next Level'));
    await tester.pump();

    expect(find.text('Reward Summary'), findsNothing);
    expect(find.text('Level: 2'), findsOneWidget);
  });

  testWidgets('Game screen shows the temporary difficulty debug overlay', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));

    expect(find.text('DEBUG ONLY - Difficulty'), findsOneWidget);
    expect(find.text('Level: 1'), findsOneWidget);
    expect(find.text('PP: 0'), findsOneWidget);
    expect(find.text('ballSpeedLevel: 0'), findsOneWidget);
    expect(find.text('ballSizeLevel: 0'), findsOneWidget);
    expect(find.text('stopTimeLevel: 0'), findsOneWidget);
    expect(find.text('safeZoneSizeLevel: 0'), findsOneWidget);
    expect(find.text('safeZoneSpeedLevel: 0'), findsOneWidget);
    expect(find.text('targetSpeedLevel: 0'), findsOneWidget);
    expect(find.text('last increased: none'), findsOneWidget);
  });

  testWidgets('Safe zone edge hit still shows PP reward summary', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GameScreen(
          initialDifficultyState: DifficultyState.initial(),
          initialLevelConfig: GameLevelConfig(
            ballRotationDuration: Duration(seconds: 3),
            ballRadius: 18,
            stopTimeLimit: Duration(seconds: 30),
            safeZoneSweepAngle: 1,
            safeZoneRotationDuration: null,
            targetRotationDuration: null,
            ballStartAngle: -0.53,
            safeZoneStartAngle: -0.5,
            targetStartAngle: 2,
            ballDirection: MovementDirection.clockwise,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(GameScreen));
    await tester.pump();

    expect(find.text('Reward Summary'), findsNothing);

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Reward Summary'), findsOneWidget);
    expect(find.textContaining('PP earned:'), findsOneWidget);
    expect(find.text('Game Over'), findsNothing);

    await tester.tap(find.text('Next Level'));
    await tester.pump();

    expect(find.text('Level: 2'), findsOneWidget);
  });

  testWidgets('Target hit outside safe zone succeeds and opens summary first', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GameScreen(
          initialDifficultyState: DifficultyState.initial(),
          initialLevelConfig: GameLevelConfig(
            ballRotationDuration: Duration(seconds: 3),
            ballRadius: 18,
            stopTimeLimit: Duration(seconds: 30),
            safeZoneSweepAngle: 1,
            safeZoneRotationDuration: null,
            targetRotationDuration: null,
            ballStartAngle: 2,
            safeZoneStartAngle: -0.5,
            targetStartAngle: 2,
            ballDirection: MovementDirection.clockwise,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(GameScreen));
    await tester.pump();

    expect(find.text('Reward Summary'), findsNothing);
    expect(find.text('Next level'), findsNothing);

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Reward Summary'), findsOneWidget);
    expect(find.text('PP earned: 100 / 100'), findsOneWidget);
    expect(find.text('Target hit! Next level max PP: 200'), findsOneWidget);
    expect(find.text('Game Over'), findsNothing);

    await tester.tap(find.text('Next Level'));
    await tester.pump();

    expect(find.text('Game Over'), findsNothing);
    expect(find.text('Level: 2'), findsOneWidget);
    expect(find.text('PP: 100'), findsWidgets);
  });

  testWidgets('Safe Zone and Target success shows PP summary', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GameScreen(
          initialDifficultyState: DifficultyState.initial(),
          initialLevelConfig: GameLevelConfig(
            ballRotationDuration: Duration(seconds: 3),
            ballRadius: 18,
            stopTimeLimit: Duration(seconds: 30),
            safeZoneSweepAngle: 1,
            safeZoneRotationDuration: null,
            targetRotationDuration: null,
            ballStartAngle: 0,
            safeZoneStartAngle: -0.05,
            targetStartAngle: 0,
            ballDirection: MovementDirection.clockwise,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(GameScreen));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Reward Summary'), findsOneWidget);
    expect(find.textContaining('PP earned:'), findsOneWidget);
    expect(find.text('Target hit! Next level max PP: 200'), findsOneWidget);
  });

  testWidgets('Completing level 60 finalizes the run instead of level 61', (
    WidgetTester tester,
  ) async {
    final adRepository = MockAdRepository(
      preloadDelay: Duration.zero,
      showDelay: Duration.zero,
    );
    final leagueRepository = _FakeLeagueRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          playerProfile: PlayerProfile(
            id: 'player-id',
            username: 'Tester',
            createdAt: DateTime(2026, 5, 1),
            gamePoints: 5,
            hasWeeklyLeagueEntry: true,
            reservedLeagueSlot: true,
            currentLeagueDivision: 2,
          ),
          adRepository: adRepository,
          leagueRepository: leagueRepository,
          initialRunMode: RunMode.league,
          initialRunLevel: 60,
          initialDifficultyState: const DifficultyState.initial(),
          initialLevelConfig: const GameLevelConfig(
            ballRotationDuration: Duration(seconds: 3),
            ballRadius: 18,
            stopTimeLimit: Duration(seconds: 30),
            safeZoneSweepAngle: 1,
            safeZoneRotationDuration: null,
            targetRotationDuration: null,
            ballStartAngle: 0,
            safeZoneStartAngle: -0.05,
            targetStartAngle: 0,
            ballDirection: MovementDirection.clockwise,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    await tester.tap(find.byType(GameScreen));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Reward Summary'), findsOneWidget);

    await tester.tap(find.text('Next Level'));
    await tester.pump();

    expect(find.text('Calculating your score... 🚀'), findsOneWidget);
    expect(find.text('Level: 60'), findsOneWidget);
    expect(find.text('Level: 61'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();

    expect(find.text('Game Over'), findsOneWidget);
    expect(find.text('Completed level 60.'), findsOneWidget);
    expect(find.text('PP: 100'), findsWidgets);
    expect(find.text('Completion GP: 1'), findsOneWidget);
    expect(find.text('Daily GP: 2'), findsOneWidget);
    expect(find.text('Current total GP: 8'), findsOneWidget);
    expect(leagueRepository.submittedRuns, hasLength(1));
    expect(leagueRepository.submittedRuns.single.score, 100);
    expect(adRepository.showCounts[AdType.interstitial], 1);
  });

  testWidgets('Failed hit shows game over and can restart', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GameScreen(
          initialDifficultyState: DifficultyState.initial(),
          initialLevelConfig: GameLevelConfig(
            ballRotationDuration: Duration(seconds: 3),
            ballRadius: 18,
            stopTimeLimit: Duration(seconds: 30),
            safeZoneSweepAngle: 1,
            safeZoneRotationDuration: null,
            targetRotationDuration: null,
            ballStartAngle: 3,
            safeZoneStartAngle: -0.5,
            targetStartAngle: 1.5,
            ballDirection: MovementDirection.clockwise,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(GameScreen));
    await tester.pump();

    expect(find.text('Game Over'), findsOneWidget);
    expect(find.text('Missed safe zone and target.'), findsOneWidget);
    expect(find.text('Game Over!'), findsOneWidget);
    expect(find.text('Watch ad to continue'), findsOneWidget);
    expect(find.text('Exit run'), findsOneWidget);
    expect(find.text('Reward Summary'), findsNothing);

    await _exitRunAndShowFinalResults(tester);

    expect(find.text('Restart run'), findsOneWidget);
    expect(find.text('Run mode: Warmup'), findsOneWidget);
    expect(find.text('Completion GP: 0'), findsOneWidget);
    expect(find.text('Daily GP: 2'), findsOneWidget);
    expect(find.text('Total GP earned: 2'), findsOneWidget);
    expect(find.text('Current total GP: 2'), findsOneWidget);

    await tester.tap(find.text('Restart run'));
    await tester.pump();

    expect(find.text('Game Over'), findsNothing);
    expect(find.text('ballSpeedLevel: 0'), findsOneWidget);
  });

  testWidgets('Rewarded continue can be used only once per run', (
    WidgetTester tester,
  ) async {
    final adRepository = MockAdRepository(
      preloadDelay: Duration.zero,
      showDelay: Duration.zero,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          adRepository: adRepository,
          initialDifficultyState: const DifficultyState.initial(),
          initialLevelConfig: _failingLevelConfig,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    await tester.tap(find.byType(GameScreen));
    await tester.pump();
    expect(find.text('Watch ad to continue'), findsOneWidget);

    await tester.tap(find.text('Watch ad to continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Game Over'), findsNothing);
    expect(find.text('Level: 1'), findsOneWidget);
    expect(adRepository.showCounts[AdType.rewarded], 1);

    await tester.tap(find.byType(GameScreen));
    await tester.pump();

    expect(find.text('Watch ad to continue'), findsNothing);
    expect(find.text('Calculating your score... 🚀'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();

    expect(find.text('Restart run'), findsOneWidget);
    expect(adRepository.showCounts[AdType.rewarded], 1);
    expect(adRepository.showCounts[AdType.interstitial], 1);
  });

  testWidgets('Stop time expiry shows timeout game over', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GameScreen(
          initialDifficultyState: DifficultyState.initial(),
          initialLevelConfig: GameLevelConfig(
            ballRotationDuration: Duration(seconds: 3),
            ballRadius: 18,
            stopTimeLimit: Duration(seconds: 1),
            safeZoneSweepAngle: 1,
            safeZoneRotationDuration: null,
            targetRotationDuration: null,
            ballStartAngle: 0,
            safeZoneStartAngle: -0.5,
            targetStartAngle: 2,
            ballDirection: MovementDirection.clockwise,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Game Over'), findsOneWidget);
    expect(find.text("Time's up! Game Over!"), findsOneWidget);
    expect(find.text('Reward Summary'), findsNothing);

    await _exitRunAndShowFinalResults(tester);

    await tester.tap(find.text('Restart run'));
    await tester.pump();

    expect(find.text('Game Over'), findsNothing);
    expect(find.text('Level: 1'), findsOneWidget);
    expect(find.text('PP: 0'), findsOneWidget);
  });

  testWidgets('Run is forced to Game Over after one hour and finalizes GP', (
    WidgetTester tester,
  ) async {
    var currentTime = DateTime(2026, 5, 4, 10);

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          initialRunMode: RunMode.league,
          now: () => currentTime,
          initialDifficultyState: const DifficultyState.initial(),
          initialLevelConfig: const GameLevelConfig(
            ballRotationDuration: Duration(seconds: 3),
            ballRadius: 18,
            stopTimeLimit: Duration(hours: 2),
            safeZoneSweepAngle: 1,
            safeZoneRotationDuration: null,
            targetRotationDuration: null,
            ballStartAngle: 0,
            safeZoneStartAngle: -0.5,
            targetStartAngle: 2,
            ballDirection: MovementDirection.clockwise,
          ),
        ),
      ),
    );

    currentTime = currentTime.add(const Duration(hours: 1));
    await tester.pump(const Duration(hours: 1));

    expect(find.text('Game Over'), findsOneWidget);
    expect(find.text('Run duration limit reached.'), findsOneWidget);

    await _exitRunAndShowFinalResults(tester);

    expect(find.text('Completion GP: 1'), findsOneWidget);
    expect(find.text('Daily GP: 2'), findsOneWidget);
    expect(find.text('Total GP earned: 3'), findsOneWidget);
    expect(find.text('Current total GP: 3'), findsOneWidget);
  });

  testWidgets('Daily GP uses Game Over timestamp instead of run start', (
    WidgetTester tester,
  ) async {
    final runStartedAt = DateTime(2026, 5, 4, 23, 30);
    var currentTime = runStartedAt;

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          playerProfile: PlayerProfile(
            id: 'player-id',
            username: 'Tester',
            createdAt: DateTime(2026, 5, 1),
            gamePoints: 5,
            lastDailyGpAwardedAt: DateTime(2026, 5, 4, 10),
          ),
          initialRunMode: RunMode.league,
          now: () => currentTime,
          initialDifficultyState: const DifficultyState.initial(),
          initialLevelConfig: const GameLevelConfig(
            ballRotationDuration: Duration(seconds: 3),
            ballRadius: 18,
            stopTimeLimit: Duration(hours: 2),
            safeZoneSweepAngle: 1,
            safeZoneRotationDuration: null,
            targetRotationDuration: null,
            ballStartAngle: 0,
            safeZoneStartAngle: -0.5,
            targetStartAngle: 2,
            ballDirection: MovementDirection.clockwise,
          ),
        ),
      ),
    );

    currentTime = runStartedAt.add(const Duration(hours: 1));
    await tester.pump(const Duration(hours: 1));

    expect(find.text('Game Over'), findsOneWidget);
    expect(find.text('Run duration limit reached.'), findsOneWidget);

    await _exitRunAndShowFinalResults(tester);

    expect(find.text('Daily GP: 2'), findsOneWidget);
    expect(find.text('Current total GP: 8'), findsOneWidget);
  });

  testWidgets('League run is not submitted without weekly entry', (
    WidgetTester tester,
  ) async {
    final leagueRepository = _FakeLeagueRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          playerProfile: PlayerProfile(
            id: 'player-id',
            username: 'Tester',
            createdAt: DateTime(2026, 5, 1),
            gamePoints: 12,
            hasWeeklyLeagueEntry: false,
          ),
          leagueRepository: leagueRepository,
          initialRunMode: RunMode.league,
          initialDifficultyState: const DifficultyState.initial(),
          initialLevelConfig: _failingLevelConfig,
        ),
      ),
    );

    await _failRunAndShowFinalResults(tester);

    expect(leagueRepository.submittedRuns, isEmpty);
  });

  testWidgets('League run finalization submits final score once', (
    WidgetTester tester,
  ) async {
    final leagueRepository = _FakeLeagueRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          playerProfile: PlayerProfile(
            id: 'player-id',
            username: 'Tester',
            createdAt: DateTime(2026, 5, 1),
            hasWeeklyLeagueEntry: true,
            reservedLeagueSlot: true,
            currentLeagueDivision: 2,
          ),
          leagueRepository: leagueRepository,
          initialRunMode: RunMode.league,
          initialDifficultyState: const DifficultyState.initial(),
          initialLevelConfig: _failingLevelConfig,
        ),
      ),
    );

    await _failRunAndShowFinalResults(tester);

    expect(leagueRepository.submittedRuns, hasLength(1));
    expect(leagueRepository.submittedRuns.single.playerId, 'player-id');
    expect(leagueRepository.submittedRuns.single.score, 0);

    await tester.pump(const Duration(seconds: 2));

    expect(leagueRepository.submittedRuns, hasLength(1));
  });

  testWidgets('Warmup run never submits league score', (
    WidgetTester tester,
  ) async {
    final leagueRepository = _FakeLeagueRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          playerProfile: PlayerProfile(
            id: 'player-id',
            username: 'Tester',
            createdAt: DateTime(2026, 5, 1),
            hasWeeklyLeagueEntry: true,
          ),
          leagueRepository: leagueRepository,
          initialRunMode: RunMode.warmup,
          initialDifficultyState: const DifficultyState.initial(),
          initialLevelConfig: _failingLevelConfig,
        ),
      ),
    );

    await _failRunAndShowFinalResults(tester);

    expect(leagueRepository.submittedRuns, isEmpty);
  });

  testWidgets('Tournament run finalization submits knockout score once', (
    WidgetTester tester,
  ) async {
    final knockoutRepository = MockKnockoutRepository(
      now: () => DateTime(2026, 5, 22, 10),
    );
    final tournament = await knockoutRepository.fetchCurrentTournament();
    final playerProfile = PlayerProfile(
      id: 'player-id',
      username: 'Tester',
      createdAt: DateTime(2026, 5, 1),
      gamePoints: 50,
    );
    await knockoutRepository.registerPlayer(
      tournament: tournament,
      playerProfile: playerProfile,
    );
    await knockoutRepository.registerPlayer(
      tournament: tournament,
      playerProfile: PlayerProfile(
        id: 'opponent-id',
        username: 'Opponent',
        createdAt: DateTime(2026, 5, 1),
        gamePoints: 50,
      ),
    );
    final startedTournament = await knockoutRepository.startTournament(
      tournamentId: tournament.id,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          playerProfile: playerProfile,
          knockoutRepository: knockoutRepository,
          initialRunMode: RunMode.tournament,
          initialDifficultyState: const DifficultyState.initial(),
          initialLevelConfig: _failingLevelConfig,
        ),
      ),
    );

    await _failRunAndShowFinalResults(tester);
    await tester.pump();

    final duel = await knockoutRepository.fetchActiveDuel(
      tournamentId: startedTournament.id,
      playerId: playerProfile.id,
    );

    expect(duel?.playerRunCount, 1);
    expect(duel?.playerScore, 0);

    await tester.pump(const Duration(seconds: 2));
    final stillOneRunDuel = await knockoutRepository.fetchActiveDuel(
      tournamentId: startedTournament.id,
      playerId: playerProfile.id,
    );

    expect(stillOneRunDuel?.playerRunCount, 1);
  });

  testWidgets('Restart resets league run submission guard', (
    WidgetTester tester,
  ) async {
    final leagueRepository = _FakeLeagueRepository();
    var currentTime = DateTime(2026, 5, 8, 10);

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          playerProfile: PlayerProfile(
            id: 'player-id',
            username: 'Tester',
            createdAt: DateTime(2026, 5, 1),
            hasWeeklyLeagueEntry: true,
            reservedLeagueSlot: true,
            currentLeagueDivision: 2,
          ),
          leagueRepository: leagueRepository,
          initialRunMode: RunMode.league,
          initialDifficultyState: const DifficultyState.initial(),
          initialLevelConfig: _failingLevelConfig,
          now: () => currentTime,
        ),
      ),
    );

    await _failRunAndShowFinalResults(tester);
    expect(leagueRepository.submittedRuns, hasLength(1));

    await tester.tap(find.text('Restart run'));
    await tester.pump();

    currentTime = currentTime.add(const Duration(hours: 1));
    await tester.pump(const Duration(hours: 1));
    await _exitRunAndShowFinalResults(tester);

    expect(leagueRepository.submittedRuns, hasLength(2));
  });
}

Future<void> _failRunAndShowFinalResults(WidgetTester tester) async {
  await tester.tap(find.byType(GameScreen));
  await tester.pump();
  await _exitRunAndShowFinalResults(tester);
}

Future<void> _exitRunAndShowFinalResults(WidgetTester tester) async {
  await tester.tap(find.text('Exit run'));
  await tester.pump();
  expect(find.text('Calculating your score... 🚀'), findsOneWidget);
  await tester.pump(const Duration(milliseconds: 1500));
}

Finder _gameAreaPainterFinder() {
  return find.byWidgetPredicate((widget) {
    return widget is CustomPaint && widget.painter is GameAreaPainter;
  });
}

const _failingLevelConfig = GameLevelConfig(
  ballRotationDuration: Duration(seconds: 3),
  ballRadius: 18,
  stopTimeLimit: Duration(seconds: 30),
  safeZoneSweepAngle: 1,
  safeZoneRotationDuration: null,
  targetRotationDuration: null,
  ballStartAngle: 3,
  safeZoneStartAngle: -0.5,
  targetStartAngle: 1.5,
  ballDirection: MovementDirection.clockwise,
);

class _FakeLeagueRepository implements LeagueRepository {
  final submittedRuns = <WeeklyLeagueRun>[];

  @override
  Future<LeaguePlayerEntry?> currentEntry(String playerId) async {
    return null;
  }

  @override
  Future<LeaguePlayerEntry> enterWeeklyLeague(PlayerProfile profile) {
    throw UnimplementedError();
  }

  @override
  Future<List<LeagueRankingEntry>> fetchDivisionRanking(
    int divisionNumber,
  ) async {
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
  Future<LeagueRunSubmissionResult> submitLeagueRun(WeeklyLeagueRun run) async {
    submittedRuns.add(run);

    return LeagueRunSubmissionResult(
      accepted: true,
      playerRecords: PlayerLeagueRecords.empty(run.playerId),
    );
  }
}
