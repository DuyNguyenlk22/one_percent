import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { EntriesService } from './entries.service';
import { ApiBearerAuth, ApiCreatedResponse, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from 'src/auth/jwt-auth.guard';
import { CreateEntryDto } from './dto/create-entry';
import { CurrentUser } from 'src/common/decorators';
import { GetHabitEntriesDto } from 'src/entries/dto/query.dto';

@Controller('habits')
@ApiTags('Habit-entries')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
export class EntriesController {
  constructor(private readonly entriesService: EntriesService) {}

  @Post(':id/entries')
  @ApiCreatedResponse({
    description: 'The record has been successfully created.',
    type: CreateEntryDto,
  })
  checkOff(
    @Param('id', new ParseUUIDPipe()) habitId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: CreateEntryDto,
  ) {
    return this.entriesService.checkOff(userId, habitId, dto);
  }

  @Get(':id/entries')
  async getEntries(
    @Param('id', new ParseUUIDPipe()) habitId: string,
    @CurrentUser('id') userId: string,
    @Query() query: GetHabitEntriesDto,
  ) {
    return await this.entriesService.getEntries(
      userId,
      habitId,
      query.from,
      query.to,
    );
  }

  @Delete(':id/entries/:date')
  deleteEntry(
    @Param('id', new ParseUUIDPipe()) habitId: string,
    // Not ParseDatePipe: it yields a Date parsed as a local instant, which
    // reintroduces the day shift standardizeDate exists to prevent. The
    // service normalises the string itself.
    @Param('date') date: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.entriesService.deleteEntry(userId, habitId, date);
  }
}
