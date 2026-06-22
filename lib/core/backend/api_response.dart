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
      }
    }

    if (!json.containsKey('error')) {
      return const ApiResponse.failure(
        ApiError(
          code: ApiErrorCode.malformedPayload,
          message: 'Failed API response must contain an error.',
        ),
      );
    }

    try {
      final decodedError = ApiError.fromJson(json['error']);

      if (decodedError.code == ApiErrorCode.malformedPayload) {
        return ApiResponse.failure(decodedError);
      }

      return ApiResponse.failure(decodedError);
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
          message: 'API error response contained invalid field types.',
        ),
      );
    }
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
}