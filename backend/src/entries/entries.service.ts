import { Injectable } from '@nestjs/common';
import { PrismaService } from 'src/prisma.service';
import { CreateEntryDto } from './dto/create-entry';

@Injectable()
export class EntriesService {
  constructor(private prisma: PrismaService) {}

  checkOff(userId: string, habitId: string, dto: CreateEntryDto) {
    return 'The habit has been entried';
  }
}
