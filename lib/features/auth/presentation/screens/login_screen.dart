import 'package:flutter/material.dart';

import '../widgets/auth_form_card.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onLogin,
    required this.onShowRegister,
  });

  final bool isSubmitting;
  final String? errorMessage;
  final Future<void> Function({
  required String username,
  required String password,
  }) onLogin;

  final VoidCallback onShowRegister;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AuthFormCard(
              title: 'Login',
              primaryButtonLabel: 'Login',
              secondaryButtonLabel: 'Create account',
              isSubmitting: isSubmitting,
              errorMessage: errorMessage,
              onSubmit: onLogin,
              onSecondaryPressed: onShowRegister,
            ),
          ),
        ),
      ),
    );
  }
}