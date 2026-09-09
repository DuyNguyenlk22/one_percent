import { Test } from '@nestjs/testing';
import { EntriesService } from './entries.service';
import { PrismaService } from 'src/prisma.service';

describe('EntriesService.deleteEntry', () => {
  const habitId = 'dddddddd-0000-4000-8000-000000000001';
  const habit = { id: habitId, userId: 'user-1', name: 'Read' };

  let service: EntriesService;
  let prisma: {
    habit: { findFirst: jest.Mock };
    habitEntry: { findUnique: jest.Mock; delete: jest.Mock };
  };

  beforeEach(async () => {
    prisma = {
      habit: { findFirst: jest.fn().mockResolvedValue(habit) },
      habitEntry: {
        findUnique: jest.fn().mockResolvedValue({ id: 'entry-1', habitId }),
        delete: jest.fn().mockResolvedValue({ id: 'entry-1', habitId }),
      },
    };
    const moduleRef = await Test.createTestingModule({
      providers: [EntriesService, { provide: PrismaService, useValue: prisma }],
    }).compile();
    service = moduleRef.get(EntriesService);
  });

  it('deletes by the habitId_date unique key', async () => {
    await service.deleteEntry('user-1', habitId, '2026-03-10');

    expect(prisma.habitEntry.delete).toHaveBeenCalledWith({
      where: {
        habitId_date: {
          habitId,
          date: new Date('2026-03-10T00:00:00.000Z'),
        },
      },
    });
  });

  it('refuses a habit the caller does not own', async () => {
    prisma.habit.findFirst.mockResolvedValue(null);

    await expect(
      service.deleteEntry('someone-else', habitId, '2026-03-10'),
    ).rejects.toThrow('Habit not found!');
    expect(prisma.habitEntry.delete).not.toHaveBeenCalled();
  });

  it('404s when the day was never checked off', async () => {
    prisma.habitEntry.findUnique.mockResolvedValue(null);

    await expect(
      service.deleteEntry('user-1', habitId, '2026-03-10'),
    ).rejects.toThrow('Habit entry not found!');
  });
});
