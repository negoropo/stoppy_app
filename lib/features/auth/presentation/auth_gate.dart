import 'package:flutter/material.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/repositories/app_repositories.dart';
import '../../../core/repositories/repository_factory.dart';
import '../../ads/domain/repositories/ad_repository.dart';
import '../../game/game_screen.dart';
import '../../knockout/domain/repositories/knockout_repository.dart';
import '../../league/domain/repositories/league_repository.dart';
import '../../purchases/domain/repositories/purchase_repository.dart';
import '../domain/models/auth_state.dart';
import '../domain/models/player_profile.dart';
import '../domain/repositories/auth_repository.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';

class AuthGate extends StatefulWidget {
  AuthGate({
    super.key,
    AuthRepository? authRepository,
    PurchaseRepository? purchaseRepository,
    AdRepository? adRepository,
    LeagueRepository? leagueRepository,
    KnockoutRepository? knockoutRepository,
  }) : authRepository = authRepository ?? _defaultRepositories.authRepository,
       purchaseRepository =
           purchaseRepository ?? _defaultRepositories.purchaseRepository,
       adRepository = adRepository ?? _defaultRepositories.adRepository,
       leagueRepository =
           leagueRepository ?? _defaultRepositories.leagueRepository,
       knockoutRepository =
           knockoutRepository ?? _defaultRepositories.knockoutRepository;

  static final AppRepositories _defaultRepositories = RepositoryFactory(
    environment: AppEnvironment.fromDartDefines(),
  ).createRepositories();

  final AuthRepository authRepository;
  final PurchaseRepository purchaseRepository;
  final AdRepository adRepository;
  final LeagueRepository leagueRepository;
  final KnockoutRepository knockoutRepository;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AuthState _authState = const AuthState.loading();
  bool _isRegisterMode = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  int _startupAttempt = 0;

  @override
  void initState() {
    super.initState();
    _restoreInitialAuthState();
  }

  @override
  void didUpdateWidget(covariant AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.authRepository, widget.authRepository)) {
      _restoreInitialAuthState();
    }
  }

  Future<void> _restoreInitialAuthState() async {
    final attempt = ++_startupAttempt;

    setState(() {
      _authState = const AuthState.loading();
      _errorMessage = null;
    });

    try {
      final restoredState = await widget.authRepository.currentAuthState();
      if (!mounted || attempt != _startupAttempt) {
        return;
      }

      setState(() {
        _authState = restoredState;
      });
    } on AuthException catch (error) {
      _setStartupError(attempt, error.message);
    } catch (_) {
      _setStartupError(
        attempt,
        'Unable to restore your session. Please try again.',
      );
    }
  }

  void _setStartupError(int attempt, String message) {
    if (!mounted || attempt != _startupAttempt) {
      return;
    }

    setState(() {
      _authState = AuthState.error(message);
    });
  }

  Future<void> _login({
    required String username,
    required String password,
  }) async {
    await _submitAuthAction(
      () => widget.authRepository.login(username: username, password: password),
    );
  }

  Future<void> _register({
    required String username,
    required String password,
  }) async {
    await _submitAuthAction(
      () => widget.authRepository.register(
        username: username,
        password: password,
      ),
    );
  }

  Future<void> _submitAuthAction(
    Future<PlayerProfile> Function() action,
  ) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final playerProfile = await action();
      if (!mounted) {
        return;
      }

      setState(() {
        _authState = AuthState.authenticated(playerProfile);
        _isSubmitting = false;
      });
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
        _isSubmitting = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Authentication failed. Please try again.';
        _isSubmitting = false;
      });
    }
  }

  void _showLogin() {
    setState(() {
      _isRegisterMode = false;
      _errorMessage = null;
    });
  }

  void _showRegister() {
    setState(() {
      _isRegisterMode = true;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_authState.status == AuthStatus.loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF101418),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_authState.status == AuthStatus.error) {
      return _AuthStartupError(
        message:
            _authState.errorMessage ??
            'Unable to restore your session. Please try again.',
        onRetry: _restoreInitialAuthState,
      );
    }

    if (_authState.isAuthenticated) {
      return GameScreen(
        playerProfile: _authState.playerProfile,
        authRepository: widget.authRepository,
        purchaseRepository: widget.purchaseRepository,
        adRepository: widget.adRepository,
        leagueRepository: widget.leagueRepository,
        knockoutRepository: widget.knockoutRepository,
      );
    }

    if (_isRegisterMode) {
      return RegisterScreen(
        isSubmitting: _isSubmitting,
        errorMessage: _errorMessage,
        onRegister: _register,
        onShowLogin: _showLogin,
      );
    }

    return LoginScreen(
      isSubmitting: _isSubmitting,
      errorMessage: _errorMessage,
      onLogin: _login,
      onShowRegister: _showRegister,
    );
  }
}

class _AuthStartupError extends StatelessWidget {
  const _AuthStartupError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48, color: Colors.white70),
                const SizedBox(height: 16),
                const Text(
                  'Session restore failed',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
