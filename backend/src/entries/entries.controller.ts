import {
  Body,
  Controller,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { EntriesService } from './entries.service';
import { ApiBearerAuth, ApiCreatedResponse, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from 'src/auth/jwt-auth.guard';
import { CreateEntryDto } from './dto/create-entry';
import { CurrentUser } from 'src/common/decorators';

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
}
