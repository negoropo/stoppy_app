import 'api_error.dart';

class ApiResponse<T> {
  const ApiResponse.success(this.data) : error = null, isSuccess = true;

  const ApiResponse.failure(this.error) : data = null, isSuccess = false;

  final T? data;
  final ApiError? error;
  final bool isSuccess;

  T requireData() {
    final value = data;
    if (isSuccess && value != null) {
      return value;
    }

    throw ApiException(
      error ??
          const ApiError(
            code: ApiErrorCode.unknown,
            message: 'API response did not contain data.',
          ),
    );
  }

  factory ApiResponse.fromJson(
      Object? json,
      T Function(Object? json) decodeData,
      ) {
    if (json is! Map) {
      return const ApiResponse.failure(
        ApiError(
          code: ApiErrorCode.malformedPayload,
          message: 'API response envelope must be a JSON object.',
        ),
      );
    }

    final success = json['success'];
    if (success is! bool) {
      return const ApiResponse.failure(
        ApiError(
          code: ApiErrorCode.malformedPayload,
          message: 'API response envelope.success must be a boolean.',
        ),
      );
    }

    if (success) {
      if (!json.containsKey('data')) {
        return const ApiResponse.failure(
          ApiError(
            code: ApiErrorCode.malformedPayload,
            message: 'Successful API response must contain data.',
          ),
        );
      }

      try {
        final decodedData = decodeData(json['data']);
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
      }
    }

    try {
      return ApiResponse.failure(ApiError.fromJson(json['error']));
    } on ApiException catch (exception) {
      return ApiResponse.failure(exception.error);
    } on FormatException catch (exception) {
      return ApiResponse.failure(
        ApiError(
          code: ApiErrorCode.malformedPayload,
          message: exception.message,
        ),
      );
    }
  }

  Map<String, Object?> toJson(Object? Function(T data) encodeData) {
    if (isSuccess) {
      return {'success': true, 'data': encodeData(requireData())};
    }

    return {
      'success': false,
      'error':
      (error ??
          const ApiError(
            code: ApiErrorCode.unknown,
            message: 'Unknown API error.',
          ))
          .toJson(),
    };
  }
}