import { Module } from '@nestjs/common';
import { EntriesService } from './entries.service';
import { EntriesController } from './entries.controller';
import { PrismaService } from 'src/prisma.service';

@Module({
  controllers: [EntriesController],
  providers: [EntriesService, PrismaService],
})
export class EntriesModule {}
