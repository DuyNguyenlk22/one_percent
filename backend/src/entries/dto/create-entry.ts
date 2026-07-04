import { ApiProperty } from '@nestjs/swagger';
import { IsDateString, IsOptional } from 'class-validator';

export class CreateEntryDto {
  @ApiProperty()
  @IsDateString()
  @IsOptional()
  date?: string;
}
