import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/auth/data/mock_auth_repository.dart';
import 'package:stoppy_app/features/auth/domain/models/auth_state.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:stoppy_app/features/auth/presentation/auth_gate.dart';
import 'package:stoppy_app/features/auth/presentation/screens/login_screen.dart';
import 'package:stoppy_app/features/game/game_screen.dart';

void main() {
  group('AuthGate startup restoration', () {
    testWidgets('shows loading until the startup state resolves', (
      tester,
    ) async {
      final startupState = Completer<AuthState>();
      final repository = _ControlledAuthRepository([() => startupState.future]);

      await tester.pumpWidget(_authApp(repository));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(GameScreen), findsNothing);

      startupState.complete(const AuthState.unauthenticated());
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets(
      'shows a recoverable error when the repository returns a loading state',
      (tester) async {
        final repository = _ControlledAuthRepository([
          () async => const AuthState.loading(),
        ]);

        await tester.pumpWidget(_authApp(repository));
        await tester.pump();

        expect(find.text('Unable to restore session'), findsOneWidget);
        expect(
          find.text('Your session could not be restored. Please try again.'),
          findsOneWidget,
        );
        expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
        expect(find.byType(GameScreen), findsNothing);
        expect(repository.currentAuthStateCalls, 1);
      },
    );

    testWidgets('opens login after an unauthenticated startup state', (
      tester,
    ) async {
      final repository = _ControlledAuthRepository([
        () async => const AuthState.unauthenticated(),
      ]);

      await tester.pumpWidget(_authApp(repository));
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(GameScreen), findsNothing);
    });

    testWidgets('opens the game after an authenticated startup state', (
      tester,
    ) async {
      final repository = _ControlledAuthRepository([
        () async => AuthState.authenticated(_playerProfile),
      ]);

      await tester.pumpWidget(_authApp(repository));
      await tester.pump();

      expect(find.byType(GameScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(
        tester.widget<GameScreen>(find.byType(GameScreen)).playerProfile,
        _playerProfile,
      );
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('restores authentication once during normal rebuilds', (
      tester,
    ) async {
      final repository = _ControlledAuthRepository([
        () async => const AuthState.unauthenticated(),
      ]);
      final gateKey = GlobalKey();

      await tester.pumpWidget(_authApp(repository, key: gateKey));
      await tester.pump();
      await tester.pumpWidget(_authApp(repository, key: gateKey));
      await tester.pump();

      expect(repository.currentAuthStateCalls, 1);
    });

    testWidgets('shows a recoverable error when startup restoration fails', (
      tester,
    ) async {
      final repository = _ControlledAuthRepository([
        () => Future<AuthState>.error(
          const AuthException('Session storage failed.'),
        ),
      ]);

      await tester.pumpWidget(_authApp(repository));
      await tester.pump();

      expect(find.text('Unable to restore session'), findsOneWidget);
      expect(find.text('Session storage failed.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('retries restoration and clears the startup error on success', (
      tester,
    ) async {
      final repository = _ControlledAuthRepository([
        () => Future<AuthState>.error(
          const AuthException('Session storage failed.'),
        ),
        () async => const AuthState.unauthenticated(),
      ]);

      await tester.pumpWidget(_authApp(repository));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pump();

      expect(repository.currentAuthStateCalls, 2);
      expect(find.text('Unable to restore session'), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('ignores a stale result after the auth repository changes', (
      tester,
    ) async {
      final oldStartupState = Completer<AuthState>();
      final oldRepository = _ControlledAuthRepository([
        () => oldStartupState.future,
      ]);
      final newRepository = _ControlledAuthRepository([
        () async => const AuthState.unauthenticated(),
      ]);
      final gateKey = GlobalKey();

      await tester.pumpWidget(_authApp(oldRepository, key: gateKey));
      await tester.pump();
      await tester.pumpWidget(_authApp(newRepository, key: gateKey));
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);

      oldStartupState.complete(AuthState.authenticated(_playerProfile));
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(GameScreen), findsNothing);
      expect(oldRepository.currentAuthStateCalls, 1);
      expect(newRepository.currentAuthStateCalls, 1);
    });

    testWidgets('mock startup does not require secure storage initialization', (
      tester,
    ) async {
      final unauthenticatedRepository = MockAuthRepository();

      await tester.pumpWidget(_authApp(unauthenticatedRepository));
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);

      final authenticatedRepository = MockAuthRepository();
      await authenticatedRepository.register(
        username: 'MockPlayer',
        password: 'pass123',
      );

      await tester.pumpWidget(_authApp(authenticatedRepository));
      await tester.pump();

      expect(find.byType(GameScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}

Widget _authApp(AuthRepository repository, {Key? key}) {
  return MaterialApp(
    home: AuthGate(key: key, authRepository: repository),
  );
}

final _playerProfile = PlayerProfile(
  id: 'player-1',
  username: 'Tester',
  createdAt: DateTime(2026, 1, 1),
);

final class _ControlledAuthRepository implements AuthRepository {
  _ControlledAuthRepository(List<Future<AuthState> Function()> startupStates)
    : _startupStates = List<Future<AuthState> Function()>.from(startupStates);

  final List<Future<AuthState> Function()> _startupStates;
  int currentAuthStateCalls = 0;

  @override
  Future<AuthState> currentAuthState() {
    currentAuthStateCalls += 1;
    if (_startupStates.isEmpty) {
      throw StateError('No startup state was configured.');
    }

    return _startupStates.removeAt(0)();
  }

  @override
  Future<PlayerProfile> login({
    required String username,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PlayerProfile> register({
    required String username,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() {
    throw UnimplementedError();
  }

  @override
  Future<PlayerProfile> updatePlayerProfile(PlayerProfile playerProfile) {
    throw UnimplementedError();
  }
}
