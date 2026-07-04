import {
  Controller,
  Post,
  Body,
  UseGuards,
  Get,
  Query,
  Patch,
  Param,
  ParseUUIDPipe,
  Delete,
} from '@nestjs/common';
import { HabitService } from './habit.service';
import { CreateHabitDto } from './dto/create-habit.dto';
import {
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiParam,
  ApiTags,
} from '@nestjs/swagger';
import { JwtAuthGuard } from 'src/auth/jwt-auth.guard';
import { CurrentUser } from 'src/common/decorators';
import { GetHabitsDto } from './dto/get-habit.dto';
import { UpdateHabitDto } from './dto/update-habit.dto';

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
  async addHabit(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateHabitDto,
  ) {
    return await this.habitService.addHabit(userId, dto);
  }

  @Get()
  async getHabits(
    @CurrentUser('id') userId: string,
    @Query('date') date?: GetHabitsDto,
  ) {
    return await this.habitService.getHabits(userId, date);
  }

  @Patch(':id')
  @ApiParam({
    name: 'id',
    description: 'Please provide habit id',
    required: true,
  })
  async updateHabit(
    @Body() habitDto: UpdateHabitDto,
    @Param('id', new ParseUUIDPipe()) paramId: string,
    @CurrentUser('id') userId: string,
  ) {
    return await this.habitService.updateHabits(paramId, userId, habitDto);
  }

  @Delete(':id')
  @ApiParam({
    name: 'id',
    description: 'Please provide habit id',
    required: true,
  })
  async deleteHabit(
    @Param('id', new ParseUUIDPipe()) paramId: string,
    @CurrentUser('id') userId: string,
  ) {
    return await this.habitService.deleteHabit(paramId, userId);
  }
}
