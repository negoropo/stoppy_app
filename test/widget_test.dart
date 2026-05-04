import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/auth/data/mock_auth_repository.dart';
import 'package:stoppy_app/features/auth/presentation/screens/login_screen.dart';
import 'package:stoppy_app/features/auth/presentation/screens/register_screen.dart';
import 'package:stoppy_app/features/game/domain/models/difficulty_state.dart';
import 'package:stoppy_app/features/game/domain/models/game_level_config.dart';
import 'package:stoppy_app/features/game/domain/models/movement_direction.dart';
import 'package:stoppy_app/features/game/game_screen.dart';
import 'package:stoppy_app/features/game/rendering/game_area_painter.dart';
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

  testWidgets('Tapping the game screen shows the post-hit reward overlay', (
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

    expect(find.text('Reward'), findsOneWidget);
    expect(find.textContaining('RP gained:'), findsOneWidget);
    expect(find.textContaining('+'), findsOneWidget);
    expect(find.text('Precision Points'), findsOneWidget);
    expect(find.textContaining('total RP:'), findsOneWidget);
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

  testWidgets('Safe zone edge hit with no RP still shows reward overlay', (
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

    expect(find.text('Reward'), findsOneWidget);
    expect(find.text('RP gained: 0'), findsOneWidget);
    expect(find.textContaining('+'), findsOneWidget);
    expect(find.text('Precision Points'), findsOneWidget);
    expect(find.text('total RP: 0'), findsOneWidget);
    expect(
      find.text(
        'Ball is touching the Safe Zone! No RP gained because the ball '
        'center is outside the Safe Zone.',
      ),
      findsOneWidget,
    );
    expect(find.text('Game Over'), findsNothing);
  });

  testWidgets('Target hit outside safe zone advances without reward menu', (
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

    expect(
      find.text(
        "You've hit the target outside the Safe Zone! Congratulations! "
        'You earned 5 RP and your reward is Level Advance with NO difficulty increase!',
      ),
      findsOneWidget,
    );
    expect(find.text('+1010 PP'), findsOneWidget);
    expect(find.text('Precision Points'), findsOneWidget);
    expect(find.text('1000 PP × 1.01 = 1010 PP'), findsOneWidget);
    expect(find.text('Reward'), findsNothing);
    expect(find.text('Game Over'), findsNothing);

    await tester.tap(find.text('OK'));
    await tester.pump();

    expect(find.text('Reward'), findsNothing);
    expect(find.text('Game Over'), findsNothing);
    expect(find.text('Level: 2'), findsOneWidget);
    expect(find.text('PP: 1010'), findsOneWidget);
    expect(find.text('last increased: none'), findsOneWidget);
    expect(find.text('ballSpeedLevel: 0'), findsOneWidget);
    expect(find.text('total RP: 5'), findsNothing);
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
    expect(find.text('Restart run'), findsOneWidget);
    expect(find.text('Reward'), findsNothing);

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

    await tester.tap(find.text('Restart run'));
    await tester.pump();

    expect(find.text('Game Over'), findsNothing);
    expect(find.text('Time: 30s'), findsOneWidget);
    expect(find.text('Level: 1'), findsOneWidget);
    expect(find.text('PP: 0'), findsOneWidget);
  });
}

Finder _gameAreaPainterFinder() {
  return find.byWidgetPredicate((widget) {
    return widget is CustomPaint && widget.painter is GameAreaPainter;
  });
}
