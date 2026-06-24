import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/auth/domain/models/auth_state.dart';
import 'package:stoppy_app/features/auth/domain/models/player_profile.dart';
import 'package:stoppy_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:stoppy_app/features/auth/presentation/auth_gate.dart';
import 'package:stoppy_app/features/auth/presentation/screens/login_screen.dart';
import 'package:stoppy_app/features/game/game_screen.dart';

void main() {
  const unauthenticatedState = AuthState.unauthenticated();
  final player = PlayerProfile(
    id: 'startup-player',
    username: 'StartupPlayer',
    createdAt: DateTime.utc(2026, 6, 1),
  );

  testWidgets('shows loading while startup authentication is unresolved', (
    tester,
  ) async {
    final startup = Completer<AuthState>();
    final repository = _StartupAuthRepository(
      currentAuthState: () => startup.future,
    );

    await tester.pumpWidget(
      MaterialApp(home: AuthGate(authRepository: repository)),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(repository.currentAuthStateCalls, 1);

    startup.complete(unauthenticatedState);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(repository.currentAuthStateCalls, 1);
  });

  testWidgets('restores an authenticated session during startup', (
    tester,
  ) async {
    final repository = _StartupAuthRepository(
      currentAuthState: () async => AuthState.authenticated(player),
    );

    await tester.pumpWidget(
      MaterialApp(home: AuthGate(authRepository: repository)),
    );
    await tester.pump();

    expect(find.byType(GameScreen), findsOneWidget);
    expect(repository.currentAuthStateCalls, 1);
  });

  testWidgets('shows a recoverable startup error and retries restoration', (
    tester,
  ) async {
    var shouldFail = true;
    final repository = _StartupAuthRepository(
      currentAuthState: () async {
        if (shouldFail) {
          throw const AuthException('Secure session storage is unavailable.');
        }
        return unauthenticatedState;
      },
    );

    await tester.pumpWidget(
      MaterialApp(home: AuthGate(authRepository: repository)),
    );
    await tester.pump();

    expect(find.text('Session restore failed'), findsOneWidget);
    expect(find.text('Secure session storage is unavailable.'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(repository.currentAuthStateCalls, 1);

    shouldFail = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(repository.currentAuthStateCalls, 2);
  });

  testWidgets('ignores stale restoration after the repository changes', (
    tester,
  ) async {
    final staleStartup = Completer<AuthState>();
    final firstRepository = _StartupAuthRepository(
      currentAuthState: () => staleStartup.future,
    );
    final secondRepository = _StartupAuthRepository(
      currentAuthState: () async => unauthenticatedState,
    );

    await tester.pumpWidget(
      MaterialApp(home: AuthGate(authRepository: firstRepository)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(home: AuthGate(authRepository: secondRepository)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(firstRepository.currentAuthStateCalls, 1);
    expect(secondRepository.currentAuthStateCalls, 1);

    staleStartup.complete(AuthState.authenticated(player));
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(GameScreen), findsNothing);
  });
}

class _StartupAuthRepository implements AuthRepository {
  _StartupAuthRepository({required this.currentAuthState});

  final Future<AuthState> Function() currentAuthState;
  int currentAuthStateCalls = 0;

  @override
  Future<AuthState> currentAuthState() {
    currentAuthStateCalls += 1;
    return currentAuthState();
  }

  @override
  Future<PlayerProfile> login({
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
  Future<PlayerProfile> register({
    required String username,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PlayerProfile> updatePlayerProfile(PlayerProfile playerProfile) {
    throw UnimplementedError();
  }
}
