import '../../features/auth/domain/repositories/auth_repository.dart';
import 'api_error.dart';

class RepositoryDomainException implements Exception {
  const RepositoryDomainException(
      this.message, {
        required this.code,
        this.details = const {},
      });

  final String message;
  final ApiErrorCode code;
  final Map<String, Object?> details;

  @override
  String toString() {
    return message;
  }
}

class AuthDomainException extends AuthException {
  AuthDomainException(
      super.message, {
        required this.code,
        this.details = const {},
      });

  final ApiErrorCode code;
  final Map<String, Object?> details;
}

class DomainErrorMapper {
  const DomainErrorMapper();

  RepositoryDomainException toRepositoryException(ApiError error) {
    return RepositoryDomainException(
      _messageFor(error),
      code: error.code,
      details: error.details,
    );
  }

  AuthDomainException toAuthException(ApiError error) {
    return AuthDomainException(
      _messageFor(error),
      code: error.code,
      details: error.details,
    );
  }

  String _messageFor(ApiError error) {
    return switch (error.code) {
      ApiErrorCode.unauthenticated => 'Please log in again.',
      ApiErrorCode.forbidden => 'You do not have permission to do that.',
      ApiErrorCode.notFound => 'The requested resource was not found.',
      ApiErrorCode.validationFailed => error.message,
      ApiErrorCode.conflict => error.message,
      ApiErrorCode.rateLimited => 'Too many attempts. Please try again later.',
      ApiErrorCode.networkUnavailable =>
      'Network unavailable. Please try again.',
      ApiErrorCode.serverError => 'Server error. Please try again later.',
      ApiErrorCode.notImplemented => error.message,
      ApiErrorCode.unknown => 'Something went wrong. Please try again.',
    };
  }
}