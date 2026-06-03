import 'api_error.dart';

class ApiResult<T> {
  const ApiResult.success(this.data) : error = null, isSuccess = true;

  const ApiResult.failure(this.error) : data = null, isSuccess = false;

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
            message: 'API result did not contain data.',
          ),
    );
  }
}
