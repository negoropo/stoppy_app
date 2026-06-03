import 'api_error.dart';

Never backendNotConnected(String repositoryName, String methodName) {
  throw ApiException(
    ApiError(
      code: ApiErrorCode.notImplemented,
      message:
          '$repositoryName.$methodName is prepared for the future REST backend '
          'but is not connected yet.',
    ),
  );
}
