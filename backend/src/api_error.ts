export class ApiError extends Error {
  constructor(
    readonly code: 'notFound' | 'validationFailed' | 'serverError' | 'unauthenticated' | 'conflict' | 'rateLimited' | 'notImplemented',
    message: string,
    readonly statusCode: number,
    readonly details?: Readonly<Record<string, string>>,
  ) {
    super(message);
  }
}

export function failure(code: ApiError['code'], message: string, details?: ApiError['details']) {
  return { success: false as const, error: { code, message, ...(details ? { details } : {}) } };
}
