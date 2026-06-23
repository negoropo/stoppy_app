import 'api_error.dart';

final class ApiResponse<T> {
const ApiResponse.success(this.data)
    : error = null,
isSuccess = true;

const ApiResponse.failure(this.error)
    : data = null,
isSuccess = false;

final T? data;
final ApiError? error;
final bool isSuccess;

bool get isFailure => !isSuccess;

T requireData() {
final currentData = data;

if (isSuccess && currentData != null) {
return currentData;
}

throw ApiException(
error ??
const ApiError(
code: ApiErrorCode.unknown,
message: 'API response did not contain data.',
),
);
}

ApiError requireError() {
final currentError = error;

if (isFailure && currentError != null) {
return currentError;
}

throw const ApiException(
ApiError(
code: ApiErrorCode.unknown,
message: 'API response did not contain an error.',
),
);
}

factory ApiResponse.fromJson(
Object? json,
T Function(Object? json) decodeData,
) {
final envelope = _normalizeEnvelope(json);

if (envelope == null) {
return const ApiResponse.failure(
ApiError(
code: ApiErrorCode.malformedPayload,
message: 'API response envelope must be a JSON object.',
),
);
}

final success = envelope['success'];

if (success is! bool) {
return const ApiResponse.failure(
ApiError(
code: ApiErrorCode.malformedPayload,
message: 'API response envelope.success must be a boolean.',
),
);
}

if (success) {
if (!envelope.containsKey('data')) {
return const ApiResponse.failure(
ApiError(
code: ApiErrorCode.malformedPayload,
message: 'Successful API response must contain data.',
),
);
}

try {
final decodedData = decodeData(envelope['data']);

if (decodedData == null) {
return const ApiResponse.failure(
ApiError(
code: ApiErrorCode.malformedPayload,
message: 'Successful API response data could not be decoded.',
),
);
}

return ApiResponse.success(decodedData);
} on ApiException catch (exception) {
return ApiResponse.failure(exception.error);
} on FormatException catch (exception) {
return ApiResponse.failure(
ApiError(
code: ApiErrorCode.malformedPayload,
message: exception.message,
),
);
} on TypeError {
return const ApiResponse.failure(
ApiError(
code: ApiErrorCode.malformedPayload,
message: 'Successful API response contained invalid field types.',
),
);
} on ArgumentError catch (exception) {
return ApiResponse.failure(
ApiError(
code: ApiErrorCode.malformedPayload,
message: exception.message?.toString() ?? 'Invalid API data.',
),
);
} on StateError catch (exception) {
return ApiResponse.failure(
ApiError(
code: ApiErrorCode.malformedPayload,
message: exception.message,
),
);
}
}

if (!envelope.containsKey('error')) {
return const ApiResponse.failure(
ApiError(
code: ApiErrorCode.malformedPayload,
message: 'Failed API response must contain an error.',
),
);
}

return ApiResponse.failure(
ApiError.fromJson(envelope['error']),
);
}

Map<String, Object?> toJson(
Object? Function(T data) encodeData,
) {
if (isSuccess) {
return <String, Object?>{
'success': true,
'data': encodeData(requireData()),
};
}

return <String, Object?>{
'success': false,
'error': requireError().toJson(),
};
}

static Map<String, Object?>? _normalizeEnvelope(Object? json) {
if (json is! Map) {
return null;
}

final normalized = <String, Object?>{};

for (final entry in json.entries) {
if (entry.key is! String) {
return null;
}

normalized[entry.key as String] = entry.value;
}

return normalized;
}
}
