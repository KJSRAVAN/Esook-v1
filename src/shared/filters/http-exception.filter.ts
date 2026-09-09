import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

interface ErrorBody {
  error: {
    code: string;
    message: string;
    details?: unknown[];
  };
}

@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(GlobalExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let body: ErrorBody;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const exceptionResponse = exception.getResponse();

      body = this.buildBody(exceptionResponse, status);
    } else {
      this.logger.error(
        `Unhandled exception on ${request.method} ${request.url}`,
        exception instanceof Error ? exception.stack : String(exception),
      );
      body = {
        error: {
          code: 'INTERNAL_ERROR',
          message: 'An unexpected error occurred',
        },
      };
    }

    response.status(status).json(body);
  }

  private buildBody(exceptionResponse: string | object, status: number): ErrorBody {
    if (typeof exceptionResponse === 'string') {
      return { error: { code: this.statusToCode(status), message: exceptionResponse } };
    }

    const obj = exceptionResponse as Record<string, unknown>;

    return {
      error: {
        code: (obj['code'] as string) ?? this.statusToCode(status),
        message: (obj['message'] as string) ?? 'An error occurred',
        details: Array.isArray(obj['message']) ? (obj['message'] as unknown[]) : undefined,
      },
    };
  }

  private statusToCode(status: number): string {
    const map: Record<number, string> = {
      400: 'INVALID_INPUT',
      401: 'UNAUTHORIZED',
      403: 'FORBIDDEN',
      404: 'NOT_FOUND',
      409: 'CONFLICT',
      422: 'UNPROCESSABLE',
      429: 'TOO_MANY_REQUESTS',
      500: 'INTERNAL_ERROR',
    };
    return map[status] ?? 'ERROR';
  }
}
