import { Injectable, NotFoundException } from '@nestjs/common';
import { CreateHabitDto } from './dto/create-habit.dto';
import { PrismaService } from 'src/prisma.service';
import { GetHabitsDto } from './dto/get-habit.dto';
import { UpdateHabitDto } from './dto/update-habit.dto';
import { HabitUpdateInput } from 'generated/prisma/models';
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

  async getHabits(userId: string, date?: GetHabitsDto) {
    if (!date) {
      return await this.prisma.habit.findMany({
        where: {
          userId,
          archivedAt: null,
        },
      });
    }
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
}
