import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
} from '@nestjs/common';
import { Response, Request } from 'express';

@Catch(HttpException)
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: HttpException, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();
    const status = exception.getStatus();

    const exceptionResponse = exception.getResponse();

    let errMessage: string | string[] = exception.message;

    if (typeof exceptionResponse === 'object' && exceptionResponse !== null) {
      const responseObj = exceptionResponse as { message: string };
      if (responseObj.message) {
        errMessage = responseObj.message;
      }
    }

    response.status(status).json({
      statusCode: status,
      isSuccess: false,
      timestamp: new Date().toISOString(),
      path: request.url,
      error: errMessage,
    });
  }
}
