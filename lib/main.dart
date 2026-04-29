import 'package:flutter/material.dart';

import 'features/game/game_screen.dart';

void main() {
  runApp(const StoppyApp());
}

class StoppyApp extends StatelessWidget {
  const StoppyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stoppy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const GameScreen(),
    );
  }
}