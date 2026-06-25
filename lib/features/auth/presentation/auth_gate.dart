import 'dart:async';

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
  AuthState _authState = const AuthState.unauthenticated();
  bool _isRestoringAuthState = true;
  String? _startupErrorMessage;
  int _authLifecycleGeneration = 0;
  bool _isRegisterMode = false;
  bool _isSubmitting = false;
  bool _isLoggingOut = false;
  String? _errorMessage;
  String? _logoutErrorMessage;

  @override
  void initState() {
    super.initState();
    _beginAuthStateRestoration(notifyListeners: false);
  }

  @override
  void didUpdateWidget(covariant AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.authRepository, widget.authRepository)) {
      _beginAuthStateRestoration();
    }
  }

  void _beginAuthStateRestoration({bool notifyListeners = true}) {
    final generation = ++_authLifecycleGeneration;

    void resetStartupState() {
      _authState = const AuthState.unauthenticated();
      _isRestoringAuthState = true;
      _startupErrorMessage = null;
      _isRegisterMode = false;
      _isSubmitting = false;
      _isLoggingOut = false;
      _errorMessage = null;
      _logoutErrorMessage = null;
    }

    if (notifyListeners) {
      setState(resetStartupState);
    } else {
      resetStartupState();
    }

    unawaited(_restoreAuthState(generation));
  }

  Future<void> _restoreAuthState(int generation) async {
    try {
      final authState = await widget.authRepository.currentAuthState();

      if (!mounted || generation != _authLifecycleGeneration) {
        return;
      }

      switch (authState.status) {
        case AuthStatus.authenticated:
        case AuthStatus.unauthenticated:
          setState(() {
            _authState = authState;
            _isRestoringAuthState = false;
          });
          return;

        case AuthStatus.error:
          _showStartupError(
            generation,
            authState.errorMessage ?? 'Your session could not be restored.',
          );
          return;

        case AuthStatus.loading:
          _showStartupError(
            generation,
            'Your session could not be restored. Please try again.',
          );
          return;
      }
    } on AuthException catch (error) {
      _showStartupError(generation, error.message);
    } catch (_) {
      _showStartupError(
        generation,
        'Your session could not be restored. Please try again.',
      );
    }
  }

  void _showStartupError(int generation, String message) {
    if (!mounted || generation != _authLifecycleGeneration) {
      return;
    }

    setState(() {
      _isRestoringAuthState = false;
      _startupErrorMessage = message;
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
    final generation = ++_authLifecycleGeneration;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _logoutErrorMessage = null;
    });

    try {
      final playerProfile = await action();

      if (!mounted || generation != _authLifecycleGeneration) {
        return;
      }

      setState(() {
        _authState = AuthState.authenticated(playerProfile);
        _isSubmitting = false;
      });
    } on AuthException catch (error) {
      if (!mounted || generation != _authLifecycleGeneration) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
        _isSubmitting = false;
      });
    } catch (_) {
      if (!mounted || generation != _authLifecycleGeneration) {
        return;
      }

      setState(() {
        _errorMessage = 'Authentication failed. Please try again.';
        _isSubmitting = false;
      });
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    final generation = ++_authLifecycleGeneration;

    setState(() {
      _isLoggingOut = true;
      _logoutErrorMessage = null;
      _errorMessage = null;
    });

    try {
      await widget.authRepository.logout();

      if (!mounted || generation != _authLifecycleGeneration) {
        return;
      }

      setState(() {
        _authState = const AuthState.unauthenticated();
        _isRegisterMode = false;
        _isSubmitting = false;
        _isLoggingOut = false;
        _logoutErrorMessage = null;
      });
    } on AuthException catch (error) {
      if (!mounted || generation != _authLifecycleGeneration) {
        return;
      }

      setState(() {
        _isLoggingOut = false;
        _logoutErrorMessage = error.message;
      });
    } catch (_) {
      if (!mounted || generation != _authLifecycleGeneration) {
        return;
      }

      setState(() {
        _isLoggingOut = false;
        _logoutErrorMessage = 'Logout failed. Please try again.';
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
    if (_isRestoringAuthState) {
      return const _AuthStartupLoadingScreen();
    }

    final startupErrorMessage = _startupErrorMessage;
    if (startupErrorMessage != null) {
      return _AuthStartupErrorScreen(
        message: startupErrorMessage,
        onRetry: _beginAuthStateRestoration,
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
        onLogout: _logout,
        isLoggingOut: _isLoggingOut,
        logoutErrorMessage: _logoutErrorMessage,
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

class _AuthStartupLoadingScreen extends StatelessWidget {
  const _AuthStartupLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF101418),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _AuthStartupErrorScreen extends StatelessWidget {
  const _AuthStartupErrorScreen({required this.message, required this.onRetry});

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
                Text(
                  'Unable to restore session',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
