import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { SafeUser } from 'src/auth/types/auth.types';

export const CurrentUser = createParamDecorator<keyof SafeUser | undefined>(
  (data, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest<{ user: SafeUser }>();

    return data ? request.user[data] : request.user;
  },
);
