import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/game/domain/models/difficulty_state.dart';
import 'package:stoppy_app/features/game/domain/models/game_level_config.dart';
import 'package:stoppy_app/features/game/domain/models/movement_direction.dart';
import 'package:stoppy_app/features/game/game_screen.dart';
import 'package:stoppy_app/features/game/rendering/game_area_painter.dart';
import 'package:stoppy_app/main.dart';

void main() {
  testWidgets('Stoppy app shows the game rendering surface', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const StoppyApp());

    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.byType(CustomPaint), findsOneWidget);
  });

  testWidgets('Game screen uses the game area painter', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const StoppyApp());
    await tester.pump(const Duration(milliseconds: 100));

    final customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));

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
    expect(find.text('ballSpeedLevel: 1'), findsOneWidget);
  });

  testWidgets('Game screen shows the temporary difficulty debug overlay', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const StoppyApp());

    expect(find.text('DEBUG ONLY - Difficulty'), findsOneWidget);
    expect(find.text('ballSpeedLevel: 0'), findsOneWidget);
    expect(find.text('ballSizeLevel: 0'), findsOneWidget);
    expect(find.text('stopTimeLevel: 0'), findsOneWidget);
    expect(find.text('safeZoneSizeLevel: 0'), findsOneWidget);
    expect(find.text('safeZoneSpeedLevel: 0'), findsOneWidget);
    expect(find.text('targetSpeedLevel: 0'), findsOneWidget);
    expect(find.text('lives: 0'), findsOneWidget);
    expect(find.text('last increased: none'), findsOneWidget);
  });
}
