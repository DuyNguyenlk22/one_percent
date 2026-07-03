import { ApiProperty, PartialType } from '@nestjs/swagger';
import { CreateHabitDto } from './create-habit.dto';
import { IsBoolean, IsOptional } from 'class-validator';

export class UpdateHabitDto extends PartialType(CreateHabitDto) {
  @IsOptional()
  @IsBoolean()
  @ApiProperty()
  archived?: boolean;
}
