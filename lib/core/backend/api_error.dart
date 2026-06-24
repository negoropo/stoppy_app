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

/// Local secure or persistent storage could not be accessed.
localStorageUnavailable,

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

/// Additional structured information supplied by the backend or generated
/// by a local infrastructure boundary.
///
/// Callers should treat this map as immutable. The constructor remains
/// const so errors can be declared as compile-time constants.
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

// Error decoding is intentionally tolerant. Invalid keys are ignored so
// an HTTP status can still be used as a fallback by the API client.
if (key is String) {
normalized[key] = entry.value;
}
}

final rawMessage = normalized['message'];

return ApiError(
code: _codeFromString(
normalized['code'] is String
? normalized['code'] as String
    : null,
),
message: rawMessage is String && rawMessage.trim().isNotEmpty
? rawMessage.trim()
    : 'Unknown API error.',
details: _detailsFromJson(
normalized['details'],
),
);
}

Map<String, Object?> toJson() {
return <String, Object?>{
'code': code.name,
'message': message,
if (details.isNotEmpty)
'details': Map<String, Object?>.unmodifiable(details),
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
details: details == null
? this.details
    : Map<String, Object?>.unmodifiable(details),
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