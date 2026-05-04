import 'package:flutter/material.dart';

import '../widgets/auth_form_card.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({
    super.key,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onRegister,
    required this.onShowLogin,
  });

  final bool isSubmitting;
  final String? errorMessage;
  final Future<void> Function({
    required String username,
    required String password,
  })
  onRegister;
  final VoidCallback onShowLogin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AuthFormCard(
              title: 'Register',
              primaryButtonLabel: 'Register',
              secondaryButtonLabel: 'Back to login',
              isSubmitting: isSubmitting,
              errorMessage: errorMessage,
              onSubmit: onRegister,
              onSecondaryPressed: onShowLogin,
            ),
          ),
        ),
      ),
    );
  }
}
