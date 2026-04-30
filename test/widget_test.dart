import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('Tapping the game screen shows hit validation feedback', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const StoppyApp());

    await tester.tap(find.byType(GameScreen));
    await tester.pump();

    expect(find.textContaining('SAFE ZONE'), findsOneWidget);
    expect(find.textContaining('TARGET'), findsOneWidget);
  });
}
