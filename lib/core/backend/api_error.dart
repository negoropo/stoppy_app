enum ApiErrorCode {
  invalidConfiguration,
  requestTimeout,
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
  unexpectedResponse,
  unknown,
}

final class ApiError {
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
      final key = entry.key;

      if (key is String) {
        normalized[key] = entry.value;
      }
    }

    final message = normalized['message'];

    return ApiError(
      code: _codeFromString(
        normalized['code'] is String
            ? normalized['code'] as String
            : null,
      ),
      message: message is String && message.trim().isNotEmpty
          ? message.trim()
          : 'Unknown API error.',
      details: _detailsFromJson(normalized['details']),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'code': code.name,
      'message': message,
      if (details.isNotEmpty) 'details': details,
    };
  }

  ApiError copyWith({
    ApiErrorCode? code,
    String? message,
    Map<String, Object?>? details,
  }) {
    return ApiError(
      code: code ?? this.code,
      message: message ?? this.message,
      details: details ?? this.details,
    );
  }

  static ApiErrorCode _codeFromString(String? value) {
    final normalizedValue = value?.trim().toLowerCase();

    if (normalizedValue == null || normalizedValue.isEmpty) {
      return ApiErrorCode.unknown;
    }

    for (final code in ApiErrorCode.values) {
      if (code.name.toLowerCase() == normalizedValue ||
          _toSnakeCase(code.name) == normalizedValue) {
        return code;
      }
    }

    return ApiErrorCode.unknown;
  }

  static String _toSnakeCase(String value) {
    return value
        .replaceAllMapped(
      RegExp('[A-Z]'),
          (match) => '_${match.group(0)!.toLowerCase()}',
    )
        .toLowerCase();
  }

  static Map<String, Object?> _detailsFromJson(Object? value) {
    if (value is! Map) {
      return const <String, Object?>{};
    }

    final details = <String, Object?>{};

    for (final entry in value.entries) {
      final key = entry.key;

      if (key is String) {
        details[key] = entry.value;
      }
    }

    return Map<String, Object?>.unmodifiable(details);
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