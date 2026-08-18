# Express Error Handler Implementation

Loaded by `secure-error-handling` when wiring up (or reviewing) the concrete Express error
layer. The response envelope shape below is owned by `api-contract-design` — mirror it, don't
redefine it.

---

## Error class hierarchy

```ts
// Base: safe to expose to clients
export class AppError extends Error {
  constructor(
    public readonly code: string,       // machine-readable, e.g. 'NOT_FOUND'
    public readonly message: string,    // human-readable, safe to log and return
    public readonly statusCode: number, // HTTP status
    public readonly details?: unknown,  // optional field-level detail (validation only)
  ) {
    super(message);
    this.name = this.constructor.name;
  }
}

// Specific operational errors
export class NotFoundError extends AppError {
  constructor(resource = 'Resource') {
    super('NOT_FOUND', `${resource} not found`, 404);
  }
}
export class ValidationError extends AppError {
  constructor(details: unknown) {
    super('VALIDATION_ERROR', 'Invalid request', 400, details);
  }
}
export class ForbiddenError extends AppError {
  constructor() { super('FORBIDDEN', 'Access denied', 403); }
}
export class UnauthorizedError extends AppError {
  constructor() { super('UNAUTHORIZED', 'Authentication required', 401); }
}
```

---

## Global error handler (Express)

```ts
export function errorHandler(
  err: unknown,
  req: Request,
  res: Response,
  next: NextFunction
): void {
  const requestId = req.headers['x-request-id'] as string ?? crypto.randomUUID();

  if (err instanceof AppError) {
    // Operational error — safe to describe to client
    logger.warn('Operational error', {
      requestId,
      code: err.code,
      message: err.message,
      path: req.path,
      userId: req.session?.userId,
    });

    res.status(err.statusCode).json({
      ok: false,
      error: {
        code: err.code,
        message: err.message,
        ...(err.details ? { details: err.details } : {}),
      },
      meta: { requestId, timestamp: new Date().toISOString() },
    });
    return;
  }

  // Programmer error or unexpected failure — log full details, return generic message
  logger.error('Unhandled error', {
    requestId,
    error: err instanceof Error ? {
      message: err.message,
      stack: err.stack,      // logged internally only
      name: err.name,
    } : String(err),
    path: req.path,
    method: req.method,
  });

  res.status(500).json({
    ok: false,
    error: {
      code: 'INTERNAL_ERROR',
      message: 'An unexpected error occurred.',
    },
    meta: { requestId, timestamp: new Date().toISOString() },
  });
}
```

The 500 branch emits the canonical internal-error payload: the same three fields on every
unexpected failure, so no 500 body varies with the underlying error.

---

## Wiring

```ts
app.use(routes);
app.use(errorHandler); // last app.use in the entrypoint — catches everything above it

process.on('unhandledRejection', (reason) => { logger.error('Unhandled rejection', { reason }); });
process.on('uncaughtException', (err) => { logger.error('Uncaught exception', { err }); process.exit(1); });
```
