import 'package:flutter/material.dart';

class AuthFormCard extends StatefulWidget {
  const AuthFormCard({
    super.key,
    required this.title,
    required this.primaryButtonLabel,
    required this.secondaryButtonLabel,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onSubmit,
    required this.onSecondaryPressed,
  });

  final String title;
  final String primaryButtonLabel;
  final String secondaryButtonLabel;
  final bool isSubmitting;
  final String? errorMessage;
  final Future<void> Function({
    required String username,
    required String password,
  })
  onSubmit;
  final VoidCallback onSecondaryPressed;

  @override
  State<AuthFormCard> createState() => _AuthFormCardState();
}

class _AuthFormCardState extends State<AuthFormCard> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await widget.onSubmit(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xEE101418),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD166)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFD166),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _usernameController,
                  enabled: !widget.isSubmitting,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    labelStyle: TextStyle(color: Color(0xFFFFD166)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFFFD166)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFFFD166), width: 2),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Color(0xFFFFD166),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Username is required.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  enabled: !widget.isSubmitting,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: Color(0xFFFFD166)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFFFD166)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFFFD166), width: 2),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Color(0xFFFFD166),
                  validator: (value) {
                    if (value == null || value.length < 4) {
                      return 'Password must be at least 4 characters.';
                    }

                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (!widget.isSubmitting) {
                      _submit();
                    }
                  },
                ),
                if (widget.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: widget.isSubmitting ? null : _submit,
                  child: widget.isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.primaryButtonLabel),
                ),
                TextButton(
                  onPressed: widget.isSubmitting
                      ? null
                      : widget.onSecondaryPressed,
                  child: Text(widget.secondaryButtonLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
