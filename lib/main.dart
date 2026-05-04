import 'package:flutter/material.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/auth_gate.dart';

void main() {
  runApp(const StoppyApp());
}

class StoppyApp extends StatelessWidget {
  const StoppyApp({super.key, this.authRepository});

  final AuthRepository? authRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stoppy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: AuthGate(authRepository: authRepository),
    );
  }
}