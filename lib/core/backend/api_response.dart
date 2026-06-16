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
    Map<String, Object?> json,
    T Function(Object? json) decodeData,
  ) {
    final success = json['success'] as bool? ?? false;
    if (success) {
      return ApiResponse.success(decodeData(json['data']));
    }

    return ApiResponse.failure(
      ApiError.fromJson(
        (json['error'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
    );
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
