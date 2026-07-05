import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from 'src/prisma.service';
import { CreateEntryDto } from './dto/create-entry';
import { standardizeDate, TODAY } from 'src/utils/dayjs';

@Injectable()
export class EntriesService {
  constructor(private prisma: PrismaService) {}

  async checkOff(userId: string, habitId: string, dto: CreateEntryDto) {
    const date = dto.date ? standardizeDate(dto.date) : TODAY;

    const habit = await this.prisma.habit.findFirst({
      where: {
        id: habitId,
        userId,
        archivedAt: null,
      },
    });

    if (!habit) {
      throw new NotFoundException();
    }

    return await this.prisma.habitEntry.upsert({
      where: {
        habitId_date: {
          habitId,
          date,
        },
      },
      create: {
        habitId,
        date,
      },
      update: {},
    });
  }

  async getEntries(userId: string, habitId: string, from: string, to: string) {
    const habit = await this.prisma.habit.findFirst({
      where: {
        userId,
        id: habitId,
      },
    });

    if (!habit) {
      throw new NotFoundException('Habit not found!');
    }

    const entries = await this.prisma.habitEntry.findMany({
      where: {
        habitId,
        date: {
          gte: standardizeDate(from),
          lte: standardizeDate(to),
        },
      },
      orderBy: {
        date: 'asc',
      },
      select: {
        date: true,
      },
    });

    return {
      entries: entries.map((entry) => entry.date),
    };
  }

  async deleteEntry(entryId: string, date: string) {
    const habit = await this.prisma.habitEntry.findFirst({
      where: {
        id: entryId,
        date,
      },
    });

    if (!habit) {
      throw new NotFoundException('Habit entry not found!');
    }

    return await this.prisma.habitEntry.delete({
      where: {
        id: entryId,
        date,
      },
    });
  }
}
