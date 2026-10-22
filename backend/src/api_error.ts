export class ApiError extends Error {
  constructor(
    readonly code: 'notFound' | 'validationFailed' | 'serverError',
    message: string,
    readonly statusCode: number,
  ) {
    super(message);
  }
}

export function failure(code: ApiError['code'], message: string) {
  return { success: false as const, error: { code, message } };
}
