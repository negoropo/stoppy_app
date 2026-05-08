import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/auth/data/mock_auth_repository.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/auth/presentation/screens/login_screen.dart';
import 'package:stoppy_app/features/auth/presentation/screens/register_screen.dart';
import 'package:stoppy_app/features/game/domain/economy/run_mode.dart';
import 'package:stoppy_app/features/game/domain/models/difficulty_state.dart';
import 'package:stoppy_app/features/game/domain/models/game_level_config.dart';
import 'package:stoppy_app/features/game/domain/models/movement_direction.dart';
import 'package:stoppy_app/features/game/game_screen.dart';
import 'package:stoppy_app/features/game/rendering/game_area_painter.dart';
import 'package:stoppy_app/features/purchases/data/mock_purchase_repository.dart';
import 'package:stoppy_app/features/purchases/presentation/screens/store_screen.dart';
import 'package:stoppy_app/main.dart';

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

  testWidgets('Game screen uses the game area painter', (
    WidgetTester tester,
  ) async {
    final repository = await authenticatedRepository();

    await tester.pumpWidget(StoppyApp(authRepository: repository));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));

    final customPaint = tester.widget<CustomPaint>(_gameAreaPainterFinder());

    expect(customPaint.painter, isA<GameAreaPainter>());
  });

  testWidgets('Tapping the game screen shows summary before reward overlay', (
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
    expect(find.text('Reward'), findsNothing);
    expect(find.text('Next level'), findsNothing);

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Reward Summary'), findsOneWidget);
    expect(find.text('Safe Zone RP earned: 3'), findsOneWidget);
    expect(find.text('Target RP bonus earned: 0'), findsOneWidget);
    expect(find.text('Total RP earned: 3'), findsOneWidget);
    expect(find.text('Next level'), findsNothing);

    await tester.tap(find.text('OK'));
    await tester.pump();

    expect(find.text('Reward Summary'), findsNothing);
    expect(find.text('Accumulated RP: 3'), findsOneWidget);
    expect(find.textContaining('Accumulated PP:'), findsOneWidget);
    expect(find.textContaining('RP gained:'), findsNothing);
    expect(find.text('Precision Points'), findsNothing);
    expect(find.text('Next level'), findsOneWidget);
    expect(find.text('Do not increase difficulty'), findsOneWidget);
    expect(find.text('Decrease random difficulty'), findsOneWidget);
    expect(find.text('Buy life'), findsOneWidget);
    expect(find.text('Decrease chosen difficulty (15 RP)'), findsOneWidget);
    expect(find.text('Increase ball speed (0)'), findsOneWidget);
    expect(find.text('Increase ball size (0)'), findsOneWidget);
    expect(find.text('Increase stop time (0)'), findsOneWidget);
    expect(find.text('Increase safe zone size (0)'), findsOneWidget);
    expect(find.text('Increase safe zone speed (0)'), findsOneWidget);
    expect(find.text('Increase target speed (0)'), findsOneWidget);
    expect(find.text('Ball speed (0)'), findsOneWidget);
    expect(find.text('Ball size (0)'), findsOneWidget);
    expect(find.text('Stop time (0)'), findsOneWidget);
    expect(find.text('Safe zone size (0)'), findsOneWidget);
    expect(find.text('Safe zone speed (0)'), findsOneWidget);
    expect(find.text('Target speed (0)'), findsOneWidget);
    expect(find.text('last increased: none'), findsOneWidget);

    await tester.ensureVisible(find.text('Increase ball speed (0)'));
    await tester.tap(find.text('Increase ball speed (0)'));
    await tester.pump();

    expect(find.text('Reward'), findsNothing);
    expect(find.text('Next level'), findsNothing);
    expect(find.text('Level: 2'), findsOneWidget);
    expect(find.text('ballSpeedLevel: 1'), findsOneWidget);
  });

  testWidgets('Game screen shows the temporary difficulty debug overlay', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));

    expect(find.text('DEBUG ONLY - Difficulty'), findsOneWidget);
    expect(find.text('Level: 1'), findsOneWidget);
    expect(find.text('PP: 0'), findsOneWidget);
    expect(find.text('Time: 30s'), findsOneWidget);
    expect(find.text('ballSpeedLevel: 0'), findsOneWidget);
    expect(find.text('ballSizeLevel: 0'), findsOneWidget);
    expect(find.text('stopTimeLevel: 0'), findsOneWidget);
    expect(find.text('safeZoneSizeLevel: 0'), findsOneWidget);
    expect(find.text('safeZoneSpeedLevel: 0'), findsOneWidget);
    expect(find.text('targetSpeedLevel: 0'), findsOneWidget);
    expect(find.text('lives: 0'), findsOneWidget);
    expect(find.text('last increased: none'), findsOneWidget);
  });

  testWidgets('Safe zone edge hit with no RP still shows reward summary', (
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
    expect(find.text('Safe Zone RP earned: 0'), findsOneWidget);
    expect(find.text('Target RP bonus earned: 0'), findsOneWidget);
    expect(find.text('Total RP earned: 0'), findsOneWidget);
    expect(find.text('Reward'), findsNothing);
    expect(find.text('Game Over'), findsNothing);

    await tester.tap(find.text('OK'));
    await tester.pump();

    expect(find.text('Accumulated RP: 0'), findsOneWidget);
    expect(find.text('RP gained: 0'), findsNothing);
    expect(find.text('Precision Points'), findsNothing);
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
    expect(find.text('Safe Zone RP earned: 0'), findsOneWidget);
    expect(find.text('Target RP bonus earned: 10'), findsOneWidget);
    expect(find.text('Total RP earned: 10'), findsOneWidget);
    expect(
      find.text('1000 PP × Level Multiplier 1.01 = 1010 PP'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Perfect hit! You stopped the center of the ball exactly on the '
        'target and earned +10 RP.',
      ),
      findsOneWidget,
    );
    expect(find.text('Reward'), findsNothing);
    expect(find.text('Game Over'), findsNothing);

    await tester.tap(find.text('OK'));
    await tester.pump();

    expect(find.text('Reward'), findsOneWidget);
    expect(find.text('Accumulated RP: 10'), findsOneWidget);
    expect(find.text('Accumulated PP: 1010'), findsOneWidget);
    expect(find.text('Precision Points'), findsNothing);
    expect(find.text('Game Over'), findsNothing);
    expect(find.text('Level: 1'), findsOneWidget);
  });

  testWidgets('Safe Zone and Target RP rewards are combined in summary', (
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
    expect(find.text('Safe Zone RP earned: 3'), findsOneWidget);
    expect(find.text('Target RP bonus earned: 10'), findsOneWidget);
    expect(find.text('Total RP earned: 13'), findsOneWidget);
  });

  testWidgets('Failed hit with no lives shows game over and can restart', (
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
    expect(find.text('No lives left. Game Over!'), findsOneWidget);
    expect(find.text('Watch ad to continue'), findsOneWidget);
    expect(find.text('Exit run'), findsOneWidget);
    expect(find.text('Reward'), findsNothing);

    await _exitRunAndShowFinalResults(tester);

    expect(find.text('Restart run'), findsOneWidget);
    expect(find.text('Run mode: League'), findsOneWidget);
    expect(find.text('Completion GP: 1'), findsOneWidget);
    expect(find.text('Daily GP: 2'), findsOneWidget);
    expect(find.text('Total GP earned: 3'), findsOneWidget);
    expect(find.text('Current total GP: 3'), findsOneWidget);

    await tester.tap(find.text('Restart run'));
    await tester.pump();

    expect(find.text('Game Over'), findsNothing);
    expect(find.text('total RP: 0'), findsNothing);
    expect(find.text('lives: 0'), findsOneWidget);
    expect(find.text('ballSpeedLevel: 0'), findsOneWidget);
  });

  testWidgets('Stop time expiry with no lives shows timeout game over', (
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

    expect(find.text('Time: 1s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Time: 0s'), findsOneWidget);
    expect(find.text('Game Over'), findsOneWidget);
    expect(find.text("Time's up! No lives left. Game Over!"), findsOneWidget);
    expect(find.text('Reward'), findsNothing);

    await _exitRunAndShowFinalResults(tester);

    await tester.tap(find.text('Restart run'));
    await tester.pump();

    expect(find.text('Game Over'), findsNothing);
    expect(find.text('Time: 30s'), findsOneWidget);
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
