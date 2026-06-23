import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/core/backend/api_error.dart';
import 'package:stoppy_app/core/backend/api_response.dart';

void main() {
group('ApiResponse', () {
test('serializes success response', () {
const response = ApiResponse.success(<String, Object?>{
'value': 7,
});

expect(
response.toJson((data) => data),
{
'success': true,
'data': {
'value': 7,
},
},
);
});

test('serializes failure response', () {
const response = ApiResponse<Map<String, Object?>>.failure(
ApiError(
code: ApiErrorCode.validationFailed,
message: 'Invalid input.',
details: {
'field': 'username',
},
),
);

expect(
response.toJson((data) => data),
{
'success': false,
'error': {
'code': 'validationFailed',
'message': 'Invalid input.',
'details': {
'field': 'username',
},
},
},
);
});

test('deserializes successful API response', () {
final response = ApiResponse<Map<String, Object?>>.fromJson(
{
'success': true,
'data': {
'value': 7,
},
},
(json) => (json as Map).cast<String, Object?>(),
);

expect(response.isSuccess, isTrue);
expect(response.isFailure, isFalse);
expect(response.requireData(), {
'value': 7,
});
});

test('deserializes standardized API error', () {
final response = ApiResponse<Map<String, Object?>>.fromJson(
{
'success': false,
'error': {
'code': 'validationFailed',
'message': 'Invalid input.',
'details': {
'field': 'username',
},
},
},
(json) => (json as Map).cast<String, Object?>(),
);

expect(response.isSuccess, isFalse);
expect(response.isFailure, isTrue);
expect(response.requireError().code, ApiErrorCode.validationFailed);
expect(response.requireError().message, 'Invalid input.');
expect(response.requireError().details['field'], 'username');
});

test('rejects a non-object response envelope', () {
final response = ApiResponse<Map<String, Object?>>.fromJson(
['invalid'],
(json) => (json as Map).cast<String, Object?>(),
);

expect(response.isFailure, isTrue);
expect(response.requireError().code, ApiErrorCode.malformedPayload);
expect(
response.requireError().message,
'API response envelope must be a JSON object.',
);
});

test('rejects response envelopes with non-string keys', () {
final response = ApiResponse<Map<String, Object?>>.fromJson(
{
1: 'invalid',
'success': true,
'data': <String, Object?>{},
},
(json) => (json as Map).cast<String, Object?>(),
);

expect(response.isFailure, isTrue);
expect(response.requireError().code, ApiErrorCode.malformedPayload);
});

test('rejects a missing success flag', () {
final response = ApiResponse<Map<String, Object?>>.fromJson(
{
'data': <String, Object?>{},
},
(json) => (json as Map).cast<String, Object?>(),
);

expect(response.isFailure, isTrue);
expect(response.requireError().code, ApiErrorCode.malformedPayload);
expect(
response.requireError().message,
'API response envelope.success must be a boolean.',
);
});

test('rejects a non-boolean success flag', () {
final response = ApiResponse<Map<String, Object?>>.fromJson(
{
'success': 'yes',
},
(json) => json! as Map<String, Object?>,
);

expect(response.isFailure, isTrue);
expect(response.requireError().code, ApiErrorCode.malformedPayload);
});

test('rejects successful responses without data', () {
final response = ApiResponse<Map<String, Object?>>.fromJson(
{
'success': true,
},
(json) => (json as Map).cast<String, Object?>(),
);

expect(response.isFailure, isTrue);
expect(response.requireError().code, ApiErrorCode.malformedPayload);
expect(
response.requireError().message,
'Successful API response must contain data.',
);
});

test('rejects failed responses without an error', () {
final response = ApiResponse<Map<String, Object?>>.fromJson(
{
'success': false,
},
(json) => (json as Map).cast<String, Object?>(),
);

expect(response.isFailure, isTrue);
expect(response.requireError().code, ApiErrorCode.malformedPayload);
expect(
response.requireError().message,
'Failed API response must contain an error.',
);
});

test('converts decoder API exceptions into failure envelopes', () {
final response = ApiResponse<String>.fromJson(
{
'success': true,
'data': <String, Object?>{},
},
(_) => throw const ApiException(
ApiError(
code: ApiErrorCode.malformedPayload,
message: 'Missing token.',
),
),
);

expect(response.isFailure, isTrue);
expect(response.requireError().message, 'Missing token.');
});

test('converts decoder FormatException into malformed payload', () {
final response = ApiResponse<String>.fromJson(
{
'success': true,
'data': 'invalid',
},
(_) => throw const FormatException('Invalid format.'),
);

expect(response.isFailure, isTrue);
expect(response.requireError().code, ApiErrorCode.malformedPayload);
expect(response.requireError().message, 'Invalid format.');
});

test('converts decoder ArgumentError into malformed payload', () {
final response = ApiResponse<String>.fromJson(
{
'success': true,
'data': 'invalid',
},
(_) => throw ArgumentError('Invalid argument.'),
);

expect(response.isFailure, isTrue);
expect(response.requireError().code, ApiErrorCode.malformedPayload);
expect(
response.requireError().message,
contains('Invalid argument.'),
);
});

test('converts decoder StateError into malformed payload', () {
final response = ApiResponse<String>.fromJson(
{
'success': true,
'data': 'invalid',
},
(_) => throw StateError('Invalid state.'),
);

expect(response.isFailure, isTrue);
expect(response.requireError().code, ApiErrorCode.malformedPayload);
expect(response.requireError().message, 'Invalid state.');
});

test('converts decoder TypeError into malformed payload', () {
final response = ApiResponse<String>.fromJson(
{
'success': true,
'data': 7,
},
(json) {
final value = json as String;
return value;
},
);

expect(response.isFailure, isTrue);
expect(response.requireError().code, ApiErrorCode.malformedPayload);
expect(
response.requireError().message,
'Successful API response contained invalid field types.',
);
});

test('requireData returns data for a successful response', () {
const response = ApiResponse.success('value');

expect(response.requireData(), 'value');
});

test('requireData throws the response error for a failure', () {
const error = ApiError(
code: ApiErrorCode.serverError,
message: 'Server error.',
);

const response = ApiResponse<String>.failure(error);

expect(
response.requireData,
throwsA(
isA<ApiException>().having(
(exception) => exception.error,
'error',
same(error),
),
),
);
});

test('requireError returns the error for a failed response', () {
const error = ApiError(
code: ApiErrorCode.serverError,
message: 'Server error.',
);

const response = ApiResponse<String>.failure(error);

expect(response.requireError(), same(error));
});

test('requireError throws for a successful response', () {
const response = ApiResponse.success('value');

expect(
response.requireError,
throwsA(
isA<ApiException>().having(
(exception) => exception.error.code,
'code',
ApiErrorCode.unknown,
),
),
);
});
});
}