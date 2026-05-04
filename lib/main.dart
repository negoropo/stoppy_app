import 'package:flutter/material.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/purchases/domain/repositories/purchase_repository.dart';

void main() {
  runApp(const StoppyApp());
}

class StoppyApp extends StatelessWidget {
  const StoppyApp({super.key, this.authRepository, this.purchaseRepository});

  final AuthRepository? authRepository;
  final PurchaseRepository? purchaseRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stoppy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: AuthGate(
        authRepository: authRepository,
        purchaseRepository: purchaseRepository,
      ),
    );
  }
}
