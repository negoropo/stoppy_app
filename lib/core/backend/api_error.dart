enum ApiErrorCode {
  unauthenticated,
  forbidden,
  notFound,
  validationFailed,
  conflict,
  rateLimited,
  serverError,
  networkUnavailable,
  notImplemented,
  unknown,
}

class ApiError {
  const ApiError({
    required this.code,
    required this.message,
    this.details = const {},
  });

  final ApiErrorCode code;
  final String message;
  final Map<String, Object?> details;

  factory ApiError.fromJson(Map<String, Object?> json) {
    return ApiError(
      code: _codeFromString(json['code'] as String?),
      message: json['message'] as String? ?? 'Unknown API error.',
      details: (json['details'] as Map?)?.cast<String, Object?>() ?? const {},
    );
  }

  Map<String, Object?> toJson() {
    return {
      'code': code.name,
      'message': message,
      if (details.isNotEmpty) 'details': details,
    };
  }

  static ApiErrorCode _codeFromString(String? value) {
    for (final code in ApiErrorCode.values) {
      if (code.name == value) {
        return code;
      }
    }
    return ApiErrorCode.unknown;
  }
}

class ApiException implements Exception {
  const ApiException(this.error);

  final ApiError error;

  @override
  String toString() {
    return '${error.code.name}: ${error.message}';
  }
}
