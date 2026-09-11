import { applyDecorators } from '@nestjs/common';
import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty, IsString, MinLength } from 'class-validator';

/**
 * Shared so login, register, forgot-password and verify-reset-code cannot drift
 * apart on what counts as a valid address.
 */
export function IsEmailAddress(): PropertyDecorator {
  return applyDecorators(
    IsEmail({}, { message: 'Please provide a valid email' }),
    IsNotEmpty(),
    ApiProperty({ example: 'alex@example.com' }),
  );
}

/**
 * Shared so the reset path and the register path cannot disagree about what a
 * valid password is.
 */
export function IsPassword(): PropertyDecorator {
  return applyDecorators(
    IsString(),
    IsNotEmpty(),
    MinLength(6, { message: 'Password must be at least 6 characters long' }),
    ApiProperty({ minLength: 6 }),
  );
}
