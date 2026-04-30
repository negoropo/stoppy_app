import 'package:flutter/material.dart';

import 'rendering/game_area_painter.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ballController;

  @override
  void initState() {
    super.initState();
    _ballController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ballController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      body: SafeArea(
        child: Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AnimatedBuilder(
                animation: _ballController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: GameAreaPainter(
                      ballProgress: _ballController.value,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
