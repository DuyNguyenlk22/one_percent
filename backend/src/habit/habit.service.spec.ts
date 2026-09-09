import { Test } from '@nestjs/testing';
import { HabitService } from './habit.service';
import { PrismaService } from 'src/prisma.service';
import { DecoratedHabit } from './types';

describe('HabitService.getHabits', () => {
  const habitRow = {
    id: 'bbbbbbbb-0000-4000-8000-000000000001',
    userId: 'user-1',
    name: 'Read',
    color: '#4D6054',
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
    archivedAt: null,
  };

  let service: HabitService;
  let prisma: { habit: { findMany: jest.Mock } };

  beforeEach(async () => {
    prisma = { habit: { findMany: jest.fn() } };
    const moduleRef = await Test.createTestingModule({
      providers: [HabitService, { provide: PrismaService, useValue: prisma }],
    }).compile();
    service = moduleRef.get(HabitService);
  });

  it('returns bare rows when no date is supplied', async () => {
    prisma.habit.findMany.mockResolvedValue([habitRow]);

    const result = await service.getHabits('user-1', undefined);

    expect(result).toEqual([habitRow]);
    expect(prisma.habit.findMany).toHaveBeenCalledWith({
      where: { userId: 'user-1', archivedAt: null },
    });
  });

  it('treats an empty query object as no date', async () => {
    prisma.habit.findMany.mockResolvedValue([habitRow]);

    const result = await service.getHabits('user-1', {} as never);

    expect(result).toEqual([habitRow]);
  });

  it('decorates against the requested date, not today', async () => {
    prisma.habit.findMany.mockResolvedValue([
      {
        ...habitRow,
        entries: [
          { date: new Date('2026-03-10T00:00:00.000Z') },
          { date: new Date('2026-03-09T00:00:00.000Z') },
          { date: new Date('2026-03-08T00:00:00.000Z') },
        ],
      },
    ]);

    const [decorated] = (await service.getHabits('user-1', {
      date: '2026-03-10',
    })) as DecoratedHabit[];

    expect(decorated.doneToday).toBe(true);
    expect(decorated.currentStreak).toBe(3);
    expect(decorated).not.toHaveProperty('entries');
  });

  it('reports doneToday false for a day with no entry', async () => {
    prisma.habit.findMany.mockResolvedValue([
      { ...habitRow, entries: [{ date: new Date('2026-03-08T00:00:00.000Z') }] },
    ]);

    const [decorated] = (await service.getHabits('user-1', {
      date: '2026-03-10',
    })) as DecoratedHabit[];

    expect(decorated.doneToday).toBe(false);
    expect(decorated.currentStreak).toBe(0);
  });
});

describe('HabitService.updateHabits', () => {
  const archived = {
    id: 'cccccccc-0000-4000-8000-000000000001',
    userId: 'user-1',
    name: 'Read',
    color: '#4D6054',
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
    archivedAt: new Date('2026-02-01T00:00:00.000Z'),
  };

  let service: HabitService;
  let prisma: { habit: { findFirst: jest.Mock; update: jest.Mock } };

  beforeEach(async () => {
    prisma = {
      habit: {
        findFirst: jest.fn().mockResolvedValue(archived),
        update: jest
          .fn()
          .mockImplementation(({ data }) => ({ ...archived, ...data })),
      },
    };
    const moduleRef = await Test.createTestingModule({
      providers: [HabitService, { provide: PrismaService, useValue: prisma }],
    }).compile();
    service = moduleRef.get(HabitService);
  });

  it('a rename leaves archivedAt alone', async () => {
    await service.updateHabits(archived.id, 'user-1', { name: 'Read daily' });

    expect(prisma.habit.update).toHaveBeenCalledWith({
      where: { id: archived.id },
      data: { name: 'Read daily' },
    });
  });

  it('never writes immutable columns back', async () => {
    await service.updateHabits(archived.id, 'user-1', { color: '#8A9A5B' });

    const { data } = prisma.habit.update.mock.calls[0][0];
    expect(data).not.toHaveProperty('id');
    expect(data).not.toHaveProperty('createdAt');
    expect(data).not.toHaveProperty('userId');
  });

  it('archived true stamps archivedAt', async () => {
    await service.updateHabits(archived.id, 'user-1', { archived: true });

    const { data } = prisma.habit.update.mock.calls[0][0];
    expect(data.archivedAt).toBeInstanceOf(Date);
    expect(data).not.toHaveProperty('archived');
  });

  it('archived false clears archivedAt', async () => {
    await service.updateHabits(archived.id, 'user-1', { archived: false });

    const { data } = prisma.habit.update.mock.calls[0][0];
    expect(data.archivedAt).toBeNull();
  });

  it('rejects a habit the caller does not own', async () => {
    prisma.habit.findFirst.mockResolvedValue(null);

    await expect(
      service.updateHabits(archived.id, 'someone-else', { name: 'Nope' }),
    ).rejects.toThrow('Habit not found!');
  });
});
