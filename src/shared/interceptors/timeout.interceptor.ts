import {
  Injectable, NestInterceptor, ExecutionContext, CallHandler, RequestTimeoutException,
} from '@nestjs/common';
import { Observable, throwError, TimeoutError } from 'rxjs';
import { catchError, timeout } from 'rxjs/operators';

/**
 * Global request timeout interceptor.
 *
 * Timeline coordination:
 *   pool_timeout (DATABASE_URL) = 15s  — Prisma throws P2024 after 15s waiting for a connection
 *   Timeout interceptor           = 20s — catches anything that still hasn't resolved
 *   Client-facing timeout         = 503 with retryable:true
 *
 * The gap (15s → 20s) ensures that a Prisma pool timeout (P2024) is caught
 * and handled by the GlobalExceptionFilter first, giving a meaningful
 * DB_POOL_TIMEOUT 503. The interceptor is a final safety net for anything
 * that doesn't respect the pool timeout (e.g. a hung external HTTP call).
 *
 * DO NOT set this below pool_timeout — that would race and return a generic
 * 408 before Prisma can throw its specific P2024 error.
 */
@Injectable()
export class TimeoutInterceptor implements NestInterceptor {
  private readonly TIMEOUT_MS = 20_000; // 20s — 5s after pool_timeout=15s

  intercept(_context: ExecutionContext, next: CallHandler): Observable<unknown> {
    return next.handle().pipe(
      timeout(this.TIMEOUT_MS),
      catchError((err) => {
        if (err instanceof TimeoutError) {
          return throwError(
            () => new RequestTimeoutException('Request timed out. Please retry.'),
          );
        }
        return throwError(() => err);
      }),
    );
  }
}