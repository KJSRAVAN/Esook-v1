import {
  ExceptionFilter, Catch, ArgumentsHost, HttpException, HttpStatus, Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { Prisma } from '@prisma/client';

interface ErrorBody {
  error: { code: string; message: string; retryable?: boolean; details?: unknown[] };
}

/**
 * Global exception filter — handles ALL thrown exceptions and normalizes them
 * into consistent { error: { code, message } } JSON responses.
 *
 * Prisma error codes handled explicitly:
 *   P2024 — connection pool timeout (DB overloaded)  → 503 retryable
 *   P1001 — DB unreachable                           → 503 retryable
 *   P1008 — operation timed out                      → 503 retryable
 *   P2002 — unique constraint violation              → 409 conflict
 *   P2025 — record not found                         → 404
 *   P2034 — transaction conflict (write skew)        → 409 retryable
 *
 * By returning 503 with retryable:true for infrastructure errors, clients
 * know to retry with backoff rather than treating it as a permanent failure.
 */
@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(GlobalExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx      = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request  = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let body: ErrorBody;

    // -------------------------------------------------------------------------
    // 1. NestJS HttpException (most of our app throws these)
    // -------------------------------------------------------------------------
    if (exception instanceof HttpException) {
      status = exception.getStatus();
      body   = this.buildBody(exception.getResponse(), status);

    // -------------------------------------------------------------------------
    // 2. Prisma known request errors (query-level errors)
    // -------------------------------------------------------------------------
    } else if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      ({ status, body } = this.handlePrismaKnownError(exception));
      this.logger.warn(
        `Prisma ${exception.code} on ${request.method} ${request.url}: ${exception.message}`,
      );

    // -------------------------------------------------------------------------
    // 3. Prisma initialization / connection errors
    // -------------------------------------------------------------------------
    } else if (
      exception instanceof Prisma.PrismaClientInitializationError ||
      exception instanceof Prisma.PrismaClientRustPanicError
    ) {
      this.logger.error(
        `Prisma connection error on ${request.method} ${request.url}`,
        exception instanceof Error ? exception.stack : String(exception),
      );
      status = HttpStatus.SERVICE_UNAVAILABLE;
      body = {
        error: {
          code: 'DB_UNAVAILABLE',
          message: 'Database is temporarily unavailable. Please try again.',
          retryable: true,
        },
      };

    // -------------------------------------------------------------------------
    // 4. Unknown / unhandled errors
    // -------------------------------------------------------------------------
    } else {
      this.logger.error(
        `Unhandled exception on ${request.method} ${request.url}`,
        exception instanceof Error ? exception.stack : String(exception),
      );
      body = {
        error: { code: 'INTERNAL_ERROR', message: 'An unexpected error occurred' },
      };
    }

    response.status(status).json(body);
  }

  private handlePrismaKnownError(
    err: Prisma.PrismaClientKnownRequestError,
  ): { status: number; body: ErrorBody } {
    switch (err.code) {
      // Connection pool timed out — DB is overloaded, tell client to retry
      case 'P2024':
        return {
          status: HttpStatus.SERVICE_UNAVAILABLE,
          body: {
            error: {
              code: 'DB_POOL_TIMEOUT',
              message: 'Server is busy. Please retry in a moment.',
              retryable: true,
            },
          },
        };

      // DB unreachable
      case 'P1001':
      case 'P1008':
        return {
          status: HttpStatus.SERVICE_UNAVAILABLE,
          body: {
            error: {
              code: 'DB_UNAVAILABLE',
              message: 'Database is temporarily unavailable. Please try again.',
              retryable: true,
            },
          },
        };

      // Unique constraint — e.g. duplicate phone/email on registration
      case 'P2002': {
        const field = (err.meta?.['target'] as string[])?.join(', ') ?? 'field';
        return {
          status: HttpStatus.CONFLICT,
          body: { error: { code: 'DUPLICATE_VALUE', message: `${field} is already in use` } },
        };
      }

      // Record not found (e.g. update/delete a row that doesn't exist)
      case 'P2025':
        return {
          status: HttpStatus.NOT_FOUND,
          body: { error: { code: 'NOT_FOUND', message: 'Record not found' } },
        };

      // Transaction conflict / write skew — safe to retry
      case 'P2034':
        return {
          status: HttpStatus.CONFLICT,
          body: {
            error: {
              code: 'TRANSACTION_CONFLICT',
              message: 'Concurrent update conflict. Please retry.',
              retryable: true,
            },
          },
        };

      default:
        return {
          status: HttpStatus.INTERNAL_SERVER_ERROR,
          body: { error: { code: 'DB_ERROR', message: 'A database error occurred' } },
        };
    }
  }

  private buildBody(exceptionResponse: string | object, status: number): ErrorBody {
    if (typeof exceptionResponse === 'string') {
      return { error: { code: this.statusToCode(status), message: exceptionResponse } };
    }
    const obj = exceptionResponse as Record<string, unknown>;
    return {
      error: {
        code:    (obj['code'] as string) ?? this.statusToCode(status),
        message: (obj['message'] as string) ?? 'An error occurred',
        details: Array.isArray(obj['message']) ? (obj['message'] as unknown[]) : undefined,
      },
    };
  }

  private statusToCode(status: number): string {
    const map: Record<number, string> = {
      400: 'INVALID_INPUT',   401: 'UNAUTHORIZED',      403: 'FORBIDDEN',
      404: 'NOT_FOUND',       408: 'REQUEST_TIMEOUT',   409: 'CONFLICT',
      422: 'UNPROCESSABLE',   429: 'TOO_MANY_REQUESTS',
      500: 'INTERNAL_ERROR',  503: 'SERVICE_UNAVAILABLE',
    };
    return map[status] ?? 'ERROR';
  }
}