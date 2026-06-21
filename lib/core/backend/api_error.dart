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
  malformedPayload,
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

  factory ApiError.fromJson(Object? json) {
    if (json is! Map) {
      return const ApiError(
        code: ApiErrorCode.malformedPayload,
        message: 'API error payload must be a JSON object.',
      );
    }

    final normalized = <String, Object?>{};
    for (final entry in json.entries) {
      if (entry.key is String) {
        normalized[entry.key as String] = entry.value;
      }
    }

    final message = normalized['message'];
    return ApiError(
      code: _codeFromString(
        normalized['code'] is String ? normalized['code'] as String : null,
      ),
      message: message is String && message.trim().isNotEmpty
          ? message
          : 'Unknown API error.',
      details: _detailsFromJson(normalized['details']),
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
    final normalizedValue = value?.trim();

    if (normalizedValue == null || normalizedValue.isEmpty) {
      return ApiErrorCode.unknown;
    }

    for (final code in ApiErrorCode.values) {
      if (code.name == normalizedValue ||
          _toSnakeCase(code.name) == normalizedValue) {
        return code;
      }
    }

    return ApiErrorCode.unknown;
  }

  static String _toSnakeCase(String value) {
    return value.replaceAllMapped(
      RegExp('[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );
  }

  static Map<String, Object?> _detailsFromJson(Object? value) {
    if (value is! Map) {
      return const {};
    }

    final details = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is String) {
        details[entry.key as String] = entry.value;
      }
    }
    return Map.unmodifiable(details);
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
