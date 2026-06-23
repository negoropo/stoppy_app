import 'package:stoppy_app/core/backend/api_contract.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/api_response.dart';
import 'package:stoppy_app/core/backend/auth_session.dart';
import 'package:stoppy_app/core/backend/backend_api_client.dart';
import 'package:stoppy_app/core/backend/backend_repository_not_configured.dart';
import 'package:stoppy_app/core/backend/domain_error_mapper.dart';

import '../../domain/models/auth_state.dart';
import '../../domain/models/player_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../dto/auth_request_dto.dart';
import '../dto/auth_response_dto.dart';
import '../dto/auth_session_dto.dart';
import '../dto/player_profile_dto.dart';

final class BackendAuthRepository implements AuthRepository {
  BackendAuthRepository({
    required this.apiClient,
    required this.authSessionStore,
    PlayerProfileMapper? playerProfileMapper,
    AuthSessionMapper? authSessionMapper,
    DomainErrorMapper? errorMapper,
    DateTime Function()? now,
  }) : _playerProfileMapper =
           playerProfileMapper ?? const PlayerProfileMapper(),
       _authSessionMapper = authSessionMapper ?? const AuthSessionMapper(),
       _errorMapper = errorMapper ?? const DomainErrorMapper(),
       _now = now ?? DateTime.now;

  final BackendApiClient apiClient;
  final AuthSessionStore authSessionStore;
  final PlayerProfileMapper _playerProfileMapper;
  final AuthSessionMapper _authSessionMapper;
  final DomainErrorMapper _errorMapper;
  final DateTime Function() _now;

  static const registerPath = ApiContract.authRegister;
  static const loginPath = ApiContract.authLogin;
  static const profilePath = ApiContract.playerProfile;

  @override
  Future<AuthState> currentAuthState() async {
    final session = await authSessionStore.read();
    if (session == null) {
      return const AuthState.unauthenticated();
    }

    if (session.isExpired(_now())) {
      await authSessionStore.clear();
      return const AuthState.unauthenticated();
    }

    // Refresh-token execution belongs here in a future session policy. Until
    // then, a valid stored access token is used to restore the profile.
    final response = await _getProfileResponse();
    if (!response.isSuccess) {
      final error = response.requireError();
      if (_invalidatesLocalSession(error.code)) {
        await authSessionStore.clear();
        return const AuthState.unauthenticated();
      }
      throw _errorMapper.toAuthException(error);
    }

    try {
      final profileDto = PlayerProfileDto.fromJson(response.requireData());
      return AuthState.authenticated(_playerProfileMapper.toDomain(profileDto));
    } on ApiException catch (exception) {
      // A malformed profile is not proof that the local session is invalid.
      // Preserve it so a temporary backend contract issue does not log out the
      // player silently.
      throw _errorMapper.toAuthException(exception.error);
    } on FormatException catch (exception) {
      throw _errorMapper.toAuthException(_malformedResponseError(exception));
    }
  }

  @override
  Future<PlayerProfile> register({
    required String username,
    required String password,
  }) async {
    return _authenticate(
      path: registerPath,
      request: _validatedRegistrationRequest(
        username: username,
        password: password,
      ),
    );
  }

  @override
  Future<PlayerProfile> login({
    required String username,
    required String password,
  }) async {
    return _authenticate(
      path: loginPath,
      request: _validatedLoginRequest(
        username: username,
        password: password,
      ),
    );
  }

  @override
  Future<void> logout() async {
    // Local clearing is intentionally idempotent and does not depend on a
    // future backend logout endpoint succeeding.
    await authSessionStore.clear();
  }

  @override
  Future<PlayerProfile> updatePlayerProfile(PlayerProfile playerProfile) {
    // API Plan does not define a player profile update endpoint or request
    // DTO. Sending a full client profile would weaken server authority.
    return backendNotConnected('BackendAuthRepository', 'updatePlayerProfile');
  }

  Future<PlayerProfile> _authenticate({
    required String path,
    required AuthRequestDto request,
  }) async {
    final response = await _postAuthenticationRequest(path, request);
    if (!response.isSuccess) {
      throw _errorMapper.toAuthException(response.requireError());
    }

    try {
      final responseDto = AuthResponseDto.fromJson(response.requireData());
      return await _completeAuthentication(responseDto);
    } on ApiException catch (exception) {
      throw _errorMapper.toAuthException(exception.error);
    } on FormatException catch (exception) {
      throw _errorMapper.toAuthException(_malformedResponseError(exception));
    }
  }

  Future<PlayerProfile> _completeAuthentication(
    AuthResponseDto response,
  ) async {
    // Password and future external-provider login both finish with the same
    // Stoppy AuthResponseDto. Provider credentials never enter domain models.
    final playerProfile = _playerProfileMapper.toDomain(response.playerProfile);
    final session = _authSessionMapper.toDomain(response.session);

    if (session.accessToken.trim().isEmpty || session.isExpired(_now())) {
      throw const ApiException(
        ApiError(
          code: ApiErrorCode.malformedPayload,
          message: 'Authentication response contained an invalid session.',
        ),
      );
    }

    await authSessionStore.save(session);
    return playerProfile;
  }

  AuthRequestDto _validatedRegistrationRequest({
    required String username,
    required String password,
  }) {
    final normalizedUsername = username.trim();

    if (normalizedUsername.isEmpty) {
      throw const AuthException('Username is required.');
    }

    if (password.length < 4) {
      throw const AuthException(
        'Password must be at least 4 characters.',
      );
    }

    return AuthRequestDto(
      username: normalizedUsername,
      password: password,
    );
  }

  AuthRequestDto _validatedLoginRequest({
    required String username,
    required String password,
  }) {
    final normalizedUsername = username.trim();

    if (normalizedUsername.isEmpty) {
      throw const AuthException('Username is required.');
    }

    if (password.trim().isEmpty) {
      throw const AuthException('Password is required.');
    }

    return AuthRequestDto(
      username: normalizedUsername,
      password: password,
    );
  }

  bool _invalidatesLocalSession(ApiErrorCode code) {
    return code == ApiErrorCode.unauthenticated ||
        code == ApiErrorCode.forbidden;
  }

  ApiError _malformedResponseError(FormatException exception) {
    return ApiError(
      code: ApiErrorCode.malformedPayload,
      message: exception.message,
    );
  }

  Future<ApiResponse<Map<String, Object?>>> _getProfileResponse() async {
    try {
      return await apiClient.get(profilePath);
    } on ApiException catch (exception) {
      throw _errorMapper.toAuthException(exception.error);
    }
  }

  Future<ApiResponse<Map<String, Object?>>> _postAuthenticationRequest(
    String path,
    AuthRequestDto request,
  ) async {
    try {
      return await apiClient.post(path, body: request.toJson());
    } on ApiException catch (exception) {
      throw _errorMapper.toAuthException(exception.error);
    }
  }
}
