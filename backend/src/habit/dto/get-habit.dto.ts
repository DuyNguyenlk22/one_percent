import { IsDateString, IsOptional } from 'class-validator';

export class GetHabitsDto {
  @IsOptional()
  @IsDateString()
  date: string;
}
