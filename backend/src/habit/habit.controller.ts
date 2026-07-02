import { Controller, Post, Body, UseGuards } from '@nestjs/common';
import { HabitService } from './habit.service';
import { CreateHabitDto } from './dto/create-habit.dto';
import { ApiBearerAuth, ApiCreatedResponse, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from 'src/auth/jwt-auth.guard';
import { CurrentUser } from 'src/common/decorators';

@Controller('habits')
@ApiTags('Habit')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
export class HabitController {
  constructor(private readonly habitService: HabitService) {}

  @Post()
  @ApiCreatedResponse({
    description: 'The record has been successfully created.',
    type: CreateHabitDto,
  })
  addHabit(@CurrentUser('id') userId: string, @Body() dto: CreateHabitDto) {
    return this.habitService.addHabit(userId, dto);
  }

  // @Get()
  // findAll() {
  //   return this.habitService.findAll();
  // }

  // @Patch(':id')
  // update(@Param('id') id: string, @Body() updateHabitDto: UpdateHabitDto) {
  //   return this.habitService.update(+id, updateHabitDto);
  // }

  // @Delete(':id')
  // remove(@Param('id') id: string) {
  //   return this.habitService.remove(+id);
  // }
}
