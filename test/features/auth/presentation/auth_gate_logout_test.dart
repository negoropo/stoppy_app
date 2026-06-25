import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/ads/domain/models/ad_load_state.dart';
import 'package:stoppy_app/features/ads/domain/models/ad_show_result.dart';
import 'package:stoppy_app/features/ads/domain/models/ad_type.dart';
import 'package:stoppy_app/features/ads/domain/repositories/ad_repository.dart';
import 'package:stoppy_app/features/auth/domain/models/auth_state.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:stoppy_app/features/auth/presentation/auth_gate.dart';
import 'package:stoppy_app/features/auth/presentation/screens/login_screen.dart';
import 'package:stoppy_app/features/game/game_screen.dart';

void main() {
  group('AuthGate logout lifecycle', () {
    testWidgets('authenticated user can log out and reaches login', (
      tester,
    ) async {
      final repository = _LifecycleAuthRepository(
        startupStates: [AuthState.authenticated(_firstPlayer)],
      );

      await tester.pumpWidget(_authApp(repository));
      await tester.pump();

      expect(find.byType(GameScreen), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(GameScreen), findsNothing);
      expect(repository.logoutCalls, 1);
    });

    testWidgets('removes the authenticated player profile after logout', (
      tester,
    ) async {
      final repository = _LifecycleAuthRepository(
        startupStates: [AuthState.authenticated(_firstPlayer)],
      );

      await tester.pumpWidget(_authApp(repository));
      await tester.pump();

      expect(
        tester.widget<GameScreen>(find.byType(GameScreen)).playerProfile,
        _firstPlayer,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
      await tester.pump();

      expect(find.byType(GameScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('login logout login logout works without replacing AuthGate', (
      tester,
    ) async {
      final repository = _LifecycleAuthRepository(
        startupStates: [const AuthState.unauthenticated()],
        loginProfiles: [_firstPlayer, _secondPlayer],
      );

      await tester.pumpWidget(_authApp(repository));
      await tester.pump();

      await _submitLogin(tester, username: 'First', password: 'pass123');
      await tester.pump();

      expect(find.byType(GameScreen), findsOneWidget);
      expect(
        tester.widget<GameScreen>(find.byType(GameScreen)).playerProfile,
        _firstPlayer,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);

      await _submitLogin(tester, username: 'Second', password: 'pass123');
      await tester.pump();

      expect(find.byType(GameScreen), findsOneWidget);
      expect(
        tester.widget<GameScreen>(find.byType(GameScreen)).playerProfile,
        _secondPlayer,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(GameScreen), findsNothing);
      expect(repository.loginCalls, 2);
      expect(repository.logoutCalls, 2);
    });

    testWidgets('rapid repeated logout taps trigger one repository logout', (
      tester,
    ) async {
      final logout = Completer<void>();
      final repository = _LifecycleAuthRepository(
        startupStates: [AuthState.authenticated(_firstPlayer)],
        logoutResults: [() => logout.future],
      );

      await tester.pumpWidget(_authApp(repository));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
      await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
      await tester.pump();

      expect(repository.logoutCalls, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('game_logout_button')),
            )
            .onPressed,
        isNull,
      );

      logout.complete();
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('failed logout keeps authenticated UI active', (tester) async {
      final repository = _LifecycleAuthRepository(
        startupStates: [AuthState.authenticated(_firstPlayer)],
        logoutResults: [
          () => Future<void>.error(
            const AuthException('Could not clear session.'),
          ),
        ],
      );

      await tester.pumpWidget(_authApp(repository));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
      await tester.pump();

      expect(find.byType(GameScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('Could not clear session.'), findsOneWidget);
      expect(repository.logoutCalls, 1);
    });

    testWidgets('stale login completion cannot restore authenticated state', (
      tester,
    ) async {
      final pendingLogin = Completer<PlayerProfile>();
      final oldRepository = _LifecycleAuthRepository(
        startupStates: [const AuthState.unauthenticated()],
        loginResults: [pendingLogin.future],
      );
      final newRepository = _LifecycleAuthRepository(
        startupStates: [const AuthState.unauthenticated()],
      );
      final gateKey = GlobalKey();

      await tester.pumpWidget(_authApp(oldRepository, key: gateKey));
      await tester.pump();

      await _submitLogin(tester, username: 'Tester', password: 'pass123');
      await tester.pump();

      await tester.pumpWidget(_authApp(newRepository, key: gateKey));
      await tester.pump();

      pendingLogin.complete(_firstPlayer);
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(GameScreen), findsNothing);
      expect(oldRepository.loginCalls, 1);
      expect(newRepository.currentAuthStateCalls, 1);
    });

    testWidgets('old repository result cannot overwrite replacement state', (
      tester,
    ) async {
      final pendingLogout = Completer<void>();
      final oldRepository = _LifecycleAuthRepository(
        startupStates: [AuthState.authenticated(_firstPlayer)],
        logoutResults: [() => pendingLogout.future],
      );
      final newRepository = _LifecycleAuthRepository(
        startupStates: [AuthState.authenticated(_secondPlayer)],
      );
      final gateKey = GlobalKey();

      await tester.pumpWidget(_authApp(oldRepository, key: gateKey));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
      await tester.pump();

      await tester.pumpWidget(_authApp(newRepository, key: gateKey));
      await tester.pump();

      expect(find.byType(GameScreen), findsOneWidget);
      expect(
        tester.widget<GameScreen>(find.byType(GameScreen)).playerProfile,
        _secondPlayer,
      );

      pendingLogout.complete();
      await tester.pump();

      expect(find.byType(GameScreen), findsOneWidget);
      expect(
        tester.widget<GameScreen>(find.byType(GameScreen)).playerProfile,
        _secondPlayer,
      );
      expect(find.byType(LoginScreen), findsNothing);
      expect(oldRepository.logoutCalls, 1);
      expect(newRepository.currentAuthStateCalls, 1);
    });
  });
}

Widget _authApp(AuthRepository repository, {Key? key}) {
  return MaterialApp(
    home: AuthGate(
      key: key,
      authRepository: repository,
      adRepository: const _NoOpAdRepository(),
    ),
  );
}

Future<void> _submitLogin(
  WidgetTester tester, {
  required String username,
  required String password,
}) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Username'),
    username,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    password,
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Login'));
}

final _firstPlayer = PlayerProfile(
  id: 'player-1',
  username: 'First',
  createdAt: DateTime(2026, 1, 1),
);

final _secondPlayer = PlayerProfile(
  id: 'player-2',
  username: 'Second',
  createdAt: DateTime(2026, 1, 2),
);

final class _LifecycleAuthRepository implements AuthRepository {
  _LifecycleAuthRepository({
    required List<AuthState> startupStates,
    List<PlayerProfile> loginProfiles = const [],
    List<Future<PlayerProfile>> loginResults = const [],
    List<Future<void> Function()> logoutResults = const [],
  }) : _startupStates = List<AuthState>.of(startupStates),
       _loginProfiles = List<PlayerProfile>.of(loginProfiles),
       _loginResults = List<Future<PlayerProfile>>.of(loginResults),
       _logoutResults = List<Future<void> Function()>.of(logoutResults);

  final List<AuthState> _startupStates;
  final List<PlayerProfile> _loginProfiles;
  final List<Future<PlayerProfile>> _loginResults;
  final List<Future<void> Function()> _logoutResults;
  PlayerProfile? _currentPlayer;

  int currentAuthStateCalls = 0;
  int loginCalls = 0;
  int logoutCalls = 0;

  @override
  Future<AuthState> currentAuthState() async {
    currentAuthStateCalls += 1;
    if (_startupStates.isNotEmpty) {
      final state = _startupStates.removeAt(0);
      _currentPlayer = state.playerProfile;
      return state;
    }

    final currentPlayer = _currentPlayer;
    if (currentPlayer == null) {
      return const AuthState.unauthenticated();
    }

    return AuthState.authenticated(currentPlayer);
  }

  @override
  Future<PlayerProfile> login({
    required String username,
    required String password,
  }) async {
    loginCalls += 1;

    if (_loginResults.isNotEmpty) {
      final playerProfile = await _loginResults.removeAt(0);
      _currentPlayer = playerProfile;
      return playerProfile;
    }

    if (_loginProfiles.isNotEmpty) {
      final playerProfile = _loginProfiles.removeAt(0);
      _currentPlayer = playerProfile;
      return playerProfile;
    }

    throw const AuthException('No login result was configured.');
  }

  @override
  Future<PlayerProfile> register({
    required String username,
    required String password,
  }) {
    return login(username: username, password: password);
  }

  @override
  Future<void> logout() async {
    logoutCalls += 1;
    if (_logoutResults.isNotEmpty) {
      await _logoutResults.removeAt(0)();
    }

    _currentPlayer = null;
  }

  @override
  Future<PlayerProfile> updatePlayerProfile(PlayerProfile playerProfile) {
    _currentPlayer = playerProfile;
    return Future.value(playerProfile);
  }
}

final class _NoOpAdRepository implements AdRepository {
  const _NoOpAdRepository();

  @override
  AdLoadState getAdLoadState(AdType adType) {
    return AdLoadState(adType: adType, status: AdLoadStatus.failed);
  }

  @override
  bool isAdLoaded(AdType adType) {
    return false;
  }

  @override
  Future<AdLoadState> preloadAd(AdType adType) async {
    return getAdLoadState(adType);
  }

  @override
  Future<AdShowResult> showAd(AdType adType) async {
    return const AdShowResult(shown: false, rewardGranted: false);
  }
}
