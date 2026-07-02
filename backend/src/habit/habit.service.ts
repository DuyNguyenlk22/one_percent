import { Injectable } from '@nestjs/common';
import { CreateHabitDto } from './dto/create-habit.dto';
import { PrismaService } from 'src/prisma.service';
// import { UpdateHabitDto } from './dto/update-habit.dto';

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

  // findAll() {
  //   return `This action returns all habit`;
  // }

  // findOne(id: number) {
  //   return `This action returns a #${id} habit`;
  // }

  // update(id: number, updateHabitDto: UpdateHabitDto) {
  //   return `This action updates a #${id} habit`;
  // }

  // remove(id: number) {
  //   return `This action removes a #${id} habit`;
  // }
}
