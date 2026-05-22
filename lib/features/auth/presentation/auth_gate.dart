import 'package:flutter/material.dart';

import '../../ads/data/mock_ad_repository.dart';
import '../../ads/domain/repositories/ad_repository.dart';
import '../../game/game_screen.dart';
import '../../knockout/data/mock_knockout_repository.dart';
import '../../knockout/domain/repositories/knockout_repository.dart';
import '../../league/data/mock_league_repository.dart';
import '../../league/domain/repositories/league_repository.dart';
import '../../purchases/data/mock_purchase_repository.dart';
import '../../purchases/domain/repositories/purchase_repository.dart';
import '../data/mock_auth_repository.dart';
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
  }) : authRepository = authRepository ?? const _DefaultAuthRepository(),
       purchaseRepository =
           purchaseRepository ?? const MockPurchaseRepository(),
       adRepository = adRepository ?? MockAdRepository(),
       leagueRepository = leagueRepository ?? MockLeagueRepository(),
       knockoutRepository = knockoutRepository ?? MockKnockoutRepository();

  final AuthRepository authRepository;
  final PurchaseRepository purchaseRepository;
  final AdRepository adRepository;
  final LeagueRepository leagueRepository;
  final KnockoutRepository knockoutRepository;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<AuthState> _initialAuthStateFuture;
  AuthState _authState = const AuthState.unauthenticated();
  bool _isRegisterMode = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialAuthStateFuture = widget.authRepository.currentAuthState();
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
    return FutureBuilder<AuthState>(
      future: _initialAuthStateFuture,
      builder: (context, snapshot) {
        final snapshotAuthState = snapshot.data;
        final effectiveAuthState = _authState.isAuthenticated
            ? _authState
            : snapshotAuthState ?? _authState;

        if (snapshot.connectionState != ConnectionState.done &&
            !effectiveAuthState.isAuthenticated) {
          return const Scaffold(
            backgroundColor: Color(0xFF101418),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (effectiveAuthState.isAuthenticated) {
          return GameScreen(
            playerProfile: effectiveAuthState.playerProfile,
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
      },
    );
  }
}

class _DefaultAuthRepository implements AuthRepository {
  const _DefaultAuthRepository();

  static final MockAuthRepository _repository = MockAuthRepository();

  @override
  Future<AuthState> currentAuthState() {
    return _repository.currentAuthState();
  }

  @override
  Future<PlayerProfile> login({
    required String username,
    required String password,
  }) {
    return _repository.login(username: username, password: password);
  }

  @override
  Future<void> logout() {
    return _repository.logout();
  }

  @override
  Future<PlayerProfile> updatePlayerProfile(PlayerProfile playerProfile) {
    return _repository.updatePlayerProfile(playerProfile);
  }

  @override
  Future<PlayerProfile> register({
    required String username,
    required String password,
  }) {
    return _repository.register(username: username, password: password);
  }
}
