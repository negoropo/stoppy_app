import 'dart:async';
import 'dart:convert';

import 'api_contract.dart';
import 'api_error.dart';
import 'api_response.dart';
import 'auth_session.dart';
import 'backend_api_client.dart';
import 'backend_api_client_config.dart';
import 'http_transport.dart';

final class BackendConfigurationException extends ApiException {
BackendConfigurationException(String message)
    : super(
ApiError(
code: ApiErrorCode.invalidConfiguration,
message: message,
),
);
}

final class HttpBackendApiClient implements BackendApiClient {
HttpBackendApiClient({
required BackendConfig config,
required HttpTransport transport,
required AuthSessionStore authSessionStore,
DateTime Function()? now,
}) : _baseUri = _parseBaseUri(config.baseUrl),
_timeout = config.timeout,
_transport = transport,
_authSessionStore = authSessionStore,
_now = now ?? DateTime.now {
if (_timeout <= Duration.zero) {
throw BackendConfigurationException(
'Backend request timeout must be greater than zero.',
);
}
}

final Uri _baseUri;
final Duration _timeout;
final HttpTransport _transport;
final AuthSessionStore _authSessionStore;
final DateTime Function() _now;

AuthSessionStore get authSessionStore => _authSessionStore;

@override
Future<ApiResponse<Map<String, Object?>>> get(
String path, {
Map<String, String> queryParameters = const {},
Map<String, String> headers = const {},
}) {
return _request(
HttpMethod.get,
path,
queryParameters: queryParameters,
headers: headers,
);
}

@override
Future<ApiResponse<Map<String, Object?>>> post(
String path, {
Map<String, Object?> body = const {},
Map<String, String> headers = const {},
}) {
return _request(
HttpMethod.post,
path,
body: body,
headers: headers,
);
}

@override
Future<ApiResponse<Map<String, Object?>>> put(
String path, {
Map<String, Object?> body = const {},
Map<String, String> headers = const {},
}) {
return _request(
HttpMethod.put,
path,
body: body,
headers: headers,
);
}

@override
Future<ApiResponse<Map<String, Object?>>> patch(
String path, {
Map<String, Object?> body = const {},
Map<String, String> headers = const {},
}) {
return _request(
HttpMethod.patch,
path,
body: body,
headers: headers,
);
}

@override
Future<ApiResponse<Map<String, Object?>>> delete(
String path, {
Map<String, String> queryParameters = const {},
Map<String, String> headers = const {},
}) {
return _request(
HttpMethod.delete,
path,
queryParameters: queryParameters,
headers: headers,
);
}

Future<ApiResponse<Map<String, Object?>>> _request(
HttpMethod method,
String path, {
Map<String, String> queryParameters = const {},
Map<String, Object?>? body,
Map<String, String> headers = const {},
}) async {
final uri = _resolveUri(
path,
queryParameters,
);

final Map<String, String> requestHeaders;

try {
requestHeaders = await _buildHeaders(
path,
headers,
hasBody: body != null,
);
} on AuthSessionStoreException catch (exception) {
throw ApiException(
ApiError(
  code: ApiErrorCode.localStorageUnavailable,
message: 'Authentication storage is temporarily unavailable.',
details: <String, Object?>{
'storageOperation': exception.operation.name,
},
),
);
}

final String? encodedBody;

try {
encodedBody = body == null
? null
    : jsonEncode(
Map<String, Object?>.of(body),
);
} on JsonUnsupportedObjectError {
return const ApiResponse.failure(
ApiError(
code: ApiErrorCode.malformedPayload,
message: 'Backend request body contains unsupported values.',
),
);
}

final request = HttpTransportRequest(
method: method,
uri: uri,
headers: requestHeaders,
body: encodedBody,
);

final HttpTransportResponse response;

// Automatic retries are intentionally not performed. Retrying a
// competitive submission or economy mutation could duplicate an
// authoritative server operation.
try {
response = await _transport.execute(request).timeout(_timeout);
} on TimeoutException {
return const ApiResponse.failure(
ApiError(
code: ApiErrorCode.requestTimeout,
message: 'Backend request timed out.',
),
);
} on ApiException catch (exception) {
return ApiResponse.failure(exception.error);
} catch (_) {
return const ApiResponse.failure(
ApiError(
code: ApiErrorCode.networkUnavailable,
message: 'Unable to reach the backend service.',
),
);
}

return _decodeResponse(response);
}

Uri _resolveUri(
String path,
Map<String, String> queryParameters,
) {
final trimmedPath = path.trim();

if (trimmedPath.isEmpty) {
throw BackendConfigurationException(
'Backend request path cannot be empty.',
);
}

final parsedPath = Uri.tryParse(trimmedPath);
final containsParentTraversal = _containsParentTraversal(
trimmedPath,
);

if (parsedPath == null ||
parsedPath.hasScheme ||
parsedPath.hasAuthority ||
parsedPath.hasQuery ||
parsedPath.hasFragment ||
containsParentTraversal) {
throw BackendConfigurationException(
'Backend request path must be a relative API path without query '
'parameters, fragments, or parent traversal.',
);
}

final normalizedPath = trimmedPath.startsWith('/')
? trimmedPath.substring(1)
    : trimmedPath;

final baseUri = _baseUri.path.endsWith('/')
? _baseUri
    : _baseUri.replace(
path: '${_baseUri.path}/',
);

final resolvedUri = baseUri.resolve(normalizedPath);

if (queryParameters.isEmpty) {
return resolvedUri;
}

return resolvedUri.replace(
queryParameters: Map<String, String>.of(
queryParameters,
),
);
}

Future<Map<String, String>> _buildHeaders(
String path,
Map<String, String> customHeaders, {
required bool hasBody,
}) async {
final headers = Map<String, String>.of(customHeaders);

_removeHeaderIgnoreCase(
headers,
ApiContract.acceptHeader,
);
_removeHeaderIgnoreCase(
headers,
ApiContract.contentTypeHeader,
);
_removeHeaderIgnoreCase(
headers,
ApiContract.authorizationHeader,
);

headers[ApiContract.acceptHeader] = ApiContract.jsonContentType;

if (hasBody) {
headers[ApiContract.contentTypeHeader] =
ApiContract.jsonContentType;
}

if (!ApiContract.isPublicAuthPath(path)) {
final session = await _authSessionStore.read();

// Expired access tokens are never sent. Session renewal is handled by
// the authentication refresh coordinator before protected restoration
// requests.
if (session != null && !session.isExpired(_now())) {
final accessToken = session.accessToken.trim();

if (accessToken.isNotEmpty) {
headers[ApiContract.authorizationHeader] =
'${ApiContract.bearerScheme} $accessToken';
}
}
}

return Map.unmodifiable(headers);
}

ApiResponse<Map<String, Object?>> _decodeResponse(
HttpTransportResponse response,
) {
final statusCode = response.statusCode;
final body = response.body.trim();

if (_isSuccessStatus(statusCode)) {
if (body.isEmpty) {
if (_allowsEmptySuccessBody(statusCode)) {
return const ApiResponse.success({});
}

return ApiResponse.failure(
ApiError(
code: ApiErrorCode.malformedPayload,
message:
'Backend returned an empty response for HTTP $statusCode.',
details: <String, Object?>{
'httpStatus': statusCode,
},
),
);
}

return _decodeSuccessEnvelope(
body,
statusCode,
);
}

return ApiResponse.failure(
_decodeError(
statusCode,
body,
),
);
}

ApiResponse<Map<String, Object?>> _decodeSuccessEnvelope(
String body,
int statusCode,
) {
try {
final decoded = jsonDecode(body);

return ApiResponse<Map<String, Object?>>.fromJson(
decoded,
(data) {
if (data is! Map) {
throw const ApiException(
ApiError(
code: ApiErrorCode.malformedPayload,
message:
'Successful API response data must be a JSON object.',
),
);
}

return Map<String, Object?>.unmodifiable(
data.cast<String, Object?>(),
);
},
);
} on ApiException catch (exception) {
return ApiResponse.failure(
_withHttpStatus(
exception.error,
statusCode,
),
);
} on FormatException {
return ApiResponse.failure(
ApiError(
code: ApiErrorCode.malformedPayload,
message: 'Backend response was not valid JSON.',
details: <String, Object?>{
'httpStatus': statusCode,
},
),
);
} on TypeError {
return ApiResponse.failure(
ApiError(
code: ApiErrorCode.malformedPayload,
message:
'Backend response contained invalid JSON field types.',
details: <String, Object?>{
'httpStatus': statusCode,
},
),
);
}
}

ApiError _decodeError(
int statusCode,
String body,
) {
if (body.isNotEmpty) {
try {
final decoded = jsonDecode(body);

if (decoded is Map) {
final json = decoded.cast<String, Object?>();

try {
final envelope =
ApiResponse<Map<String, Object?>>.fromJson(
json,
(data) {
if (data is! Map) {
return const <String, Object?>{};
}

return data.cast<String, Object?>();
},
);

final envelopeError = envelope.error;

if (!envelope.isSuccess &&
envelopeError != null &&
envelopeError.code !=
ApiErrorCode.malformedPayload) {
return _withHttpStatus(
envelopeError,
statusCode,
);
}
} on ApiException {
// A malformed error envelope falls back to direct error decoding
// and ultimately to HTTP status mapping.
} on TypeError {
// Invalid envelope field types also fall back to status mapping.
}

try {
final rawError = ApiError.fromJson(json);

if (rawError.code != ApiErrorCode.unknown) {
return _withHttpStatus(
rawError,
statusCode,
);
}
} on ApiException {
// Invalid direct error payload falls back to HTTP status mapping.
} on TypeError {
// Invalid direct error field types fall back to status mapping.
}
}
} on FormatException {
// Non-JSON error responses are represented using their HTTP status.
} on TypeError {
// Invalid JSON object key or field types fall back to status mapping.
}
}

return ApiError(
code: _errorCodeForStatus(statusCode),
message: _messageForStatus(statusCode),
details: <String, Object?>{
'httpStatus': statusCode,
},
);
}

static Uri _parseBaseUri(String value) {
final uri = Uri.tryParse(
value.trim(),
);

if (uri == null ||
uri.host.isEmpty ||
(uri.scheme != 'http' && uri.scheme != 'https') ||
uri.hasQuery ||
uri.hasFragment ||
uri.userInfo.isNotEmpty) {
throw BackendConfigurationException(
'Backend base URL must be a valid HTTP(S) URL without credentials, '
'query parameters, or fragments.',
);
}

return uri;
}

static bool _containsParentTraversal(String path) {
  try {
    return path
        .split('/')
        .map(Uri.decodeComponent)
        .any((segment) => segment == '..');
  } on FormatException {
    throw BackendConfigurationException(
      'Backend request path contains invalid percent encoding.',
    );
  } on ArgumentError {
    throw BackendConfigurationException(
      'Backend request path contains invalid percent encoding.',
    );
  }
}

static bool _isSuccessStatus(int statusCode) {
return statusCode >= 200 && statusCode < 300;
}

static bool _allowsEmptySuccessBody(int statusCode) {
return statusCode == 204 || statusCode == 205;
}

static ApiErrorCode _errorCodeForStatus(int statusCode) {
return switch (statusCode) {
401 => ApiErrorCode.unauthenticated,
403 => ApiErrorCode.forbidden,
404 => ApiErrorCode.notFound,
409 => ApiErrorCode.conflict,
422 => ApiErrorCode.validationFailed,
429 => ApiErrorCode.rateLimited,
>= 500 && <= 599 => ApiErrorCode.serverError,
_ => ApiErrorCode.unexpectedResponse,
};
}

static String _messageForStatus(int statusCode) {
return switch (_errorCodeForStatus(statusCode)) {
ApiErrorCode.unauthenticated =>
'Authentication is required.',
ApiErrorCode.forbidden =>
'You do not have permission to do that.',
ApiErrorCode.notFound =>
'The requested resource was not found.',
ApiErrorCode.conflict =>
'The request conflicts with current state.',
ApiErrorCode.validationFailed =>
'The request could not be validated.',
ApiErrorCode.rateLimited =>
'Too many requests. Please try again later.',
ApiErrorCode.serverError =>
'The backend service returned an error.',
_ =>
'The backend returned an unexpected HTTP response.',
};
}

static ApiError _withHttpStatus(
ApiError error,
int statusCode,
) {
return error.copyWith(
details: <String, Object?>{
...error.details,
'httpStatus': statusCode,
},
);
}

static void _removeHeaderIgnoreCase(
Map<String, String> headers,
String name,
) {
final normalizedName = name.toLowerCase();

final matchingKeys = headers.keys
    .where(
(key) => key.toLowerCase() == normalizedName,
)
    .toList(
growable: false,
);

for (final key in matchingKeys) {
headers.remove(key);
}
}
}