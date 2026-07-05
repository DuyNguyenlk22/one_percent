import {
  BadRequestException,
  Injectable,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import { CreateHabitDto } from './dto/create-habit.dto';
import { PrismaService } from 'src/prisma.service';
import { GetHabitsDto } from './dto/get-habit.dto';
import { UpdateHabitDto } from './dto/update-habit.dto';
import { HabitUpdateInput } from 'generated/prisma/models';
import dayjs from 'dayjs';
import { computeCurrentStreak } from 'src/utils/streak';
import { omit } from 'lodash';
@Injectable()
export class HabitService {
  constructor(private prisma: PrismaService) {}
  async addHabit(userId: string, dto: CreateHabitDto) {
    return await this.prisma.habit.create({
      data: {
        ...dto,
        userId,
      },
    });
  }

  async getHabits(userId: string, dateDto?: GetHabitsDto) {
    if (!dateDto) {
      return await this.prisma.habit.findMany({
        where: {
          userId,
          archivedAt: null,
        },
      });
    }

    const habits = await this.prisma.habit.findMany({
      where: {
        userId,
        archivedAt: null,
      },
      include: {
        entries: {
          orderBy: {
            date: 'desc',
          },
        },
      },
    });
    const target = dayjs(dateDto.date);

    return habits.map((habit) => ({
      ...omit(habit, 'entries'),
      doneToday: habit.entries.some((entry) =>
        dayjs(entry.date).isSame(target, 'day'),
      ),
      currentStreak: computeCurrentStreak(
        habit.entries.map((entry) => entry.date),
        target,
      ),
    }));
  }

  async updateHabits(id: string, userId: string, habitDto: UpdateHabitDto) {
    const habit = await this.prisma.habit.findFirst({
      where: {
        id,
        userId,
      },
    });

    if (!habit) {
      throw new NotFoundException('Habit not found!');
    }

    const data: HabitUpdateInput = {
      ...habit,
      ...habitDto,
      archivedAt: habitDto.archived ? new Date() : null,
    };

    return await this.prisma.habit.update({
      where: { id },
      data,
    });
  }

  async deleteHabit(id: string, userId: string) {
    if (!id) throw new BadRequestException();

    const habit = await this.prisma.habit.findFirst({
      where: {
        id,
        userId,
      },
    });

    if (!habit) {
      throw new NotFoundException('Habit not found!');
    }

    const deletedHabit = await this.prisma.habit.delete({
      where: {
        id,
        userId,
      },
    });

    if (deletedHabit) {
      return {
        code: 200,
        message: `Deleted successfully the habit with id: ${id}`,
      };
    } else throw new InternalServerErrorException();
  }
}
