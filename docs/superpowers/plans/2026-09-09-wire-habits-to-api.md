# Wiring the Bloom Screens to the API — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hardcoded demo state on Today, Routines, Add Habit, Insights and Profile with real data from the existing NestJS API, and fix the six defects that block it.

**Architecture:** The mobile app gains `habits/data`, `entries/data` and their use cases, mirroring `features/auth` exactly — datasource throws `AppException`, repository is the only place that maps to `Failure`, presentation `switch`es over `Result`. Two Riverpod `AsyncNotifier`s own all screen state: `dailyHabitsProvider` (Today + My Habits) and `insightsProvider` (Insights + Profile stats). History maths lives in a pure, widget-free `InsightsCalculator`.

**Tech Stack:** Flutter 3.11 · Riverpod 3 · go_router 17 · Dio 5 · mocktail — NestJS 11 · Prisma 7 · Jest 30 · dayjs

**Spec:** [docs/superpowers/specs/2026-09-09-wire-habits-to-api-design.md](../specs/2026-09-09-wire-habits-to-api-design.md)

## Global Constraints

- **No Prisma migrations.** The schema is fixed: `Habit { id, userId, name, color?, createdAt, archivedAt? }`, `HabitEntry { id, habitId, date @db.Date, createdAt }` with `@@unique([habitId, date])`. Anything the API cannot serve is removed from the UI, never faked.
- **Day keys are UTC.** `HabitEntry.date` is a Postgres `DATE` written at UTC midnight. Every format/compare of a day key on both sides uses UTC, never local time — this is what makes the tests timezone-independent.
- **Dart:** run everything from `mobile/`. Test: `flutter test`. Analyze: `flutter analyze`.
- **TypeScript:** run everything from `backend/`. Test: `npm test`. Jest `rootDir` is `src`, `testRegex` is `.*\.spec\.ts$`, so specs live beside the file they cover. There are currently no backend unit tests; these are the first.
- **Riverpod 3:** `Override` is imported from `package:flutter_riverpod/misc.dart`, not the main barrel (see `test/helpers/pump_app.dart`).
- **No new dependencies.** Everything needed is already in `pubspec.yaml` and `package.json`.
- **Mutation methods return `Failure?`** — `null` means success. Pages show a SnackBar on non-null. This keeps error state out of `AsyncValue` so an optimistic rollback does not blow away the list.
- Commit after every task.

---

## Task 1: UTC day keys on the backend

The foundation for everything else. `standardizeDate` currently returns a full ISO timestamp against a `DATE` column, and `TODAY` is evaluated once at module load, so a long-running process hands out its boot day forever.

**Files:**
- Modify: `backend/src/utils/dayjs.ts`
- Test: `backend/src/utils/dayjs.spec.ts` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: `standardizeDate(date: string | Date): Date` — UTC midnight of the input's local calendar day. `today(): Date` — `standardizeDate(new Date())`. `formatDate(date: Date): string` — `YYYY-MM-DD` read in **UTC**. `DATE_FORMAT` unchanged. The `TODAY` constant is **deleted**.

- [ ] **Step 1: Write the failing test**

```ts
// backend/src/utils/dayjs.spec.ts
import { formatDate, standardizeDate, today } from './dayjs';

describe('standardizeDate', () => {
  it('returns UTC midnight for a plain YYYY-MM-DD string', () => {
    expect(standardizeDate('2026-03-14').toISOString()).toBe(
      '2026-03-14T00:00:00.000Z',
    );
  });

  it('keeps the local calendar day of a Date and drops the time', () => {
    const localNoon = new Date(2026, 2, 14, 12, 0, 0);
    expect(standardizeDate(localNoon).toISOString()).toBe(
      '2026-03-14T00:00:00.000Z',
    );
  });
});

describe('formatDate', () => {
  it('reads the day key in UTC, so a stored DATE never shifts', () => {
    expect(formatDate(new Date('2026-03-14T00:00:00.000Z'))).toBe('2026-03-14');
  });
});

describe('today', () => {
  it('is a function, so a long-running process does not keep its boot day', () => {
    expect(typeof today).toBe('function');
    expect(today().toISOString()).toBe(standardizeDate(new Date()).toISOString());
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npx jest src/utils/dayjs.spec.ts`
Expected: FAIL — `today is not a function`, and `standardizeDate(...).toISOString is not a function` (it currently returns a string).

- [ ] **Step 3: Write the implementation**

```ts
// backend/src/utils/dayjs.ts
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';

dayjs.extend(utc);

export const DATE_FORMAT = 'YYYY-MM-DD';

/// Narrows any instant to the UTC midnight of its local calendar day, which is
/// the key shape `HabitEntry.date` (`@db.Date`) and `@@unique([habitId, date])`
/// expect.
export const standardizeDate = (date: string | Date): Date =>
  new Date(`${dayjs(date).format(DATE_FORMAT)}T00:00:00.000Z`);

/// Evaluated per call. A module-level constant would pin a long-running
/// process to the day it booted.
export const today = (): Date => standardizeDate(new Date());

/// Reads a stored day key back. UTC, because that is how it was written —
/// formatting in local time shifts the day for anyone west of Greenwich.
export const formatDate = (date: Date): string =>
  dayjs(date).utc().format(DATE_FORMAT);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && npx jest src/utils/dayjs.spec.ts`
Expected: PASS (4 tests)

- [ ] **Step 5: Update the one existing caller of the deleted constant**

In `backend/src/entries/entries.service.ts`, change the import and the `checkOff` default:

```ts
import { standardizeDate, today } from 'src/utils/dayjs';
// ...
const date = dto.date ? standardizeDate(dto.date) : today();
```

- [ ] **Step 6: Verify the project still compiles**

Run: `cd backend && npx tsc --noEmit`
Expected: no errors

- [ ] **Step 7: Commit**

```bash
git add backend/src/utils/dayjs.ts backend/src/utils/dayjs.spec.ts backend/src/entries/entries.service.ts
git commit -m "fix(backend): key habit entries on UTC midnight dates

standardizeDate returned a full ISO timestamp against a DATE column and
TODAY was evaluated at module load, so a long-running process handed out
its boot day. formatDate now reads day keys in UTC to match how they are
written."
```

---

## Task 2: Register issues a token the guard accepts

`auth.service.register` signs `{ id }` while `JwtStrategy.validate` reads `payload.userId`. A newly registered user is authenticated in app state but 401s on every habit call.

**Files:**
- Modify: `backend/src/auth/auth.service.ts:59`
- Test: `backend/src/auth/auth.service.spec.ts` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: no signature change — `register` keeps returning `{ user, accessToken }`.

- [ ] **Step 1: Write the failing test**

```ts
// backend/src/auth/auth.service.spec.ts
import { Test } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { AuthService } from './auth.service';
import { PrismaService } from 'src/prisma.service';

describe('AuthService token claims', () => {
  const user = {
    id: 'aaaaaaaa-0000-4000-8000-000000000001',
    email: 'alex@example.com',
    passwordHash: '$2b$10$abcdefghijklmnopqrstuv',
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
  };

  let service: AuthService;
  let jwt: { sign: jest.Mock; signAsync: jest.Mock };
  let prisma: { user: { findUnique: jest.Mock; create: jest.Mock } };

  beforeEach(async () => {
    jwt = {
      sign: jest.fn().mockReturnValue('token'),
      signAsync: jest.fn().mockResolvedValue('token'),
    };
    prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue(user),
      },
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: prisma },
        { provide: JwtService, useValue: jwt },
      ],
    }).compile();

    service = moduleRef.get(AuthService);
  });

  it('register signs the userId claim JwtStrategy reads', async () => {
    await service.register(user.email, 'password123');

    expect(jwt.signAsync).toHaveBeenCalledWith({ userId: user.id });
  });

  it('register never leaks the password hash', async () => {
    const response = await service.register(user.email, 'password123');

    expect(response.user).not.toHaveProperty('passwordHash');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npx jest src/auth/auth.service.spec.ts`
Expected: FAIL — `expected { userId: "aaaa…" }, received { id: "aaaa…" }`

- [ ] **Step 3: Write the implementation**

In `backend/src/auth/auth.service.ts`, inside `register`:

```ts
    const accessToken = await this.jwtService.signAsync({ userId: user.id });
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && npx jest src/auth/auth.service.spec.ts`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add backend/src/auth/auth.service.ts backend/src/auth/auth.service.spec.ts
git commit -m "fix(backend): sign the userId claim on register

register signed { id } while JwtStrategy reads payload.userId, so every
call made with a registration token resolved userId undefined and 401d."
```

---

## Task 3: `GET /habits?date=` reaches the service as a DTO

`@Query('date') date?: GetHabitsDto` binds the raw string, so `dateDto.date` is `undefined` and `dayjs(undefined)` silently falls back to now. `doneToday` also compares with `isSame(…, 'day')` across a UTC/local boundary, which shifts the day west of Greenwich.

**Files:**
- Modify: `backend/src/habit/habit.controller.ts:44-50`, `backend/src/habit/dto/get-habit.dto.ts`, `backend/src/habit/habit.service.ts:25-63`
- Test: `backend/src/habit/habit.service.spec.ts` (create)

**Interfaces:**
- Consumes: `formatDate`, from Task 1.
- Produces: `HabitService.getHabits(userId: string, query?: GetHabitsDto)`. With no `query.date` it returns bare habit rows; with one it returns each row plus `doneToday: boolean` and `currentStreak: number`. `GetHabitsDto.date` becomes `date?: string`.

- [ ] **Step 1: Write the failing test**

```ts
// backend/src/habit/habit.service.spec.ts
import { Test } from '@nestjs/testing';
import { HabitService } from './habit.service';
import { PrismaService } from 'src/prisma.service';

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

    const [decorated] = await service.getHabits('user-1', {
      date: '2026-03-10',
    });

    expect(decorated.doneToday).toBe(true);
    expect(decorated.currentStreak).toBe(3);
    expect(decorated).not.toHaveProperty('entries');
  });

  it('reports doneToday false for a day with no entry', async () => {
    prisma.habit.findMany.mockResolvedValue([
      { ...habitRow, entries: [{ date: new Date('2026-03-08T00:00:00.000Z') }] },
    ]);

    const [decorated] = await service.getHabits('user-1', {
      date: '2026-03-10',
    });

    expect(decorated.doneToday).toBe(false);
    expect(decorated.currentStreak).toBe(0);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npx jest src/habit/habit.service.spec.ts`
Expected: FAIL — the empty-query case returns decorated rows, and the decorated cases mis-report `doneToday` in any timezone behind UTC.

- [ ] **Step 3: Write the implementation**

`backend/src/habit/dto/get-habit.dto.ts`:

```ts
import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsOptional } from 'class-validator';

export class GetHabitsDto {
  @ApiPropertyOptional({ example: '2026-03-10' })
  @IsOptional()
  @IsDateString()
  date?: string;
}
```

`backend/src/habit/habit.controller.ts` — replace the `getHabits` handler:

```ts
  @Get()
  async getHabits(
    @CurrentUser('id') userId: string,
    @Query() query: GetHabitsDto,
  ) {
    return await this.habitService.getHabits(userId, query);
  }
```

`backend/src/habit/habit.service.ts` — replace `getHabits`, and add `formatDate` to the imports from `src/utils/dayjs`:

```ts
  async getHabits(userId: string, query?: GetHabitsDto) {
    // `@Query()` always binds an object, so the guard is on the field.
    if (!query?.date) {
      return await this.prisma.habit.findMany({
        where: { userId, archivedAt: null },
      });
    }

    const habits = await this.prisma.habit.findMany({
      where: { userId, archivedAt: null },
      include: { entries: { orderBy: { date: 'desc' } } },
    });

    const target = dayjs(query.date);
    const targetKey = target.format(DATE_FORMAT);

    return habits.map((habit) => ({
      ...omit(habit, 'entries'),
      // Compare day keys, not instants: entries are stored at UTC midnight
      // and `target` is a local day, so `isSame(…, 'day')` shifts west of UTC.
      doneToday: habit.entries.some(
        (entry) => formatDate(entry.date) === targetKey,
      ),
      currentStreak: computeCurrentStreak(
        habit.entries.map((entry) => entry.date),
        target,
      ),
    }));
  }
```

Import line at the top of the file:

```ts
import { DATE_FORMAT, formatDate } from 'src/utils/dayjs';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && npx jest src/habit/habit.service.spec.ts`
Expected: PASS (4 tests)

- [ ] **Step 5: Confirm it is timezone-independent**

Run: `cd backend && TZ=Pacific/Kiritimati npx jest src/habit/habit.service.spec.ts && TZ=Pacific/Midway npx jest src/habit/habit.service.spec.ts`
Expected: PASS in both — UTC+14 and UTC-11 are the extremes that would expose a local-time comparison.

- [ ] **Step 6: Commit**

```bash
git add backend/src/habit/habit.controller.ts backend/src/habit/dto/get-habit.dto.ts backend/src/habit/habit.service.ts backend/src/habit/habit.service.spec.ts
git commit -m "fix(backend): bind the date query DTO and compare day keys in UTC

@Query('date') bound the raw string while the service read .date, so
dayjs(undefined) fell back to now and the date filter did nothing."
```

---

## Task 4: A rename stops un-archiving the habit

`updateHabits` spreads the whole existing row into the update payload — `id` and `createdAt` included — and forces `archivedAt: null` whenever `archived` is falsy. Task 8's My Habits screen renames and archives through this endpoint, so it has to be correct first.

**Files:**
- Modify: `backend/src/habit/habit.service.ts:65-90`
- Test: `backend/src/habit/habit.service.spec.ts` (extend)

**Interfaces:**
- Consumes: nothing.
- Produces: `HabitService.updateHabits(id, userId, habitDto)` unchanged in signature; it now writes only the supplied fields.

- [ ] **Step 1: Write the failing test**

Append to `backend/src/habit/habit.service.spec.ts`:

```ts
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
        update: jest.fn().mockImplementation(({ data }) => ({ ...archived, ...data })),
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npx jest src/habit/habit.service.spec.ts -t updateHabits`
Expected: FAIL — the rename case writes `archivedAt: null` plus `id` and `createdAt`.

- [ ] **Step 3: Write the implementation**

Replace `updateHabits` in `backend/src/habit/habit.service.ts`:

```ts
  async updateHabits(id: string, userId: string, habitDto: UpdateHabitDto) {
    const habit = await this.prisma.habit.findFirst({ where: { id, userId } });

    if (!habit) {
      throw new NotFoundException('Habit not found!');
    }

    const { archived, ...fields } = habitDto;

    // Only the supplied fields are written. Spreading the existing row would
    // send back `id` and `createdAt`, and defaulting `archived` would make a
    // plain rename un-archive the habit.
    const data: HabitUpdateInput = { ...fields };
    if (archived !== undefined) {
      data.archivedAt = archived ? new Date() : null;
    }

    return await this.prisma.habit.update({ where: { id }, data });
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && npx jest src/habit/habit.service.spec.ts`
Expected: PASS (9 tests total in the file)

- [ ] **Step 5: Commit**

```bash
git add backend/src/habit/habit.service.ts backend/src/habit/habit.service.spec.ts
git commit -m "fix(backend): update only the supplied habit fields

updateHabits spread the whole row into the payload and forced
archivedAt null whenever archived was falsy, so a rename un-archived."
```

---

## Task 5: `DELETE /habits/:id/entries/:date` finds the row and checks ownership

The controller names the path param `entryId` but the route supplies the *habit* id, and the service queries `habitEntry.findFirst({ id: entryId, date })` — which can never match. It is also the only `/habits/**` handler with neither `@CurrentUser` nor an ownership check.

**Files:**
- Modify: `backend/src/entries/entries.controller.ts:45-51`, `backend/src/entries/entries.service.ts:70-95`
- Test: `backend/src/entries/entries.service.spec.ts` (create)

**Interfaces:**
- Consumes: `standardizeDate`, from Task 1.
- Produces: `EntriesService.deleteEntry(userId: string, habitId: string, date: string)` — was `deleteEntry(entryId, date)`.

- [ ] **Step 1: Write the failing test**

```ts
// backend/src/entries/entries.service.spec.ts
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && npx jest src/entries/entries.service.spec.ts`
Expected: FAIL — `deleteEntry` takes two arguments and calls `findFirst`, not `findUnique`.

- [ ] **Step 3: Write the implementation**

Replace `deleteEntry` in `backend/src/entries/entries.service.ts`:

```ts
  async deleteEntry(userId: string, habitId: string, date: string) {
    const habit = await this.prisma.habit.findFirst({
      where: { id: habitId, userId },
    });

    if (!habit) {
      throw new NotFoundException('Habit not found!');
    }

    const habitId_date = { habitId, date: standardizeDate(date) };

    const entry = await this.prisma.habitEntry.findUnique({
      where: { habitId_date },
    });

    if (!entry) {
      throw new NotFoundException('Habit entry not found!');
    }

    await this.prisma.habitEntry.delete({ where: { habitId_date } });

    return { code: 200, message: 'Deleted successfully' };
  }
```

`InternalServerErrorException` is no longer used in this file — drop it from the import.

Replace the handler in `backend/src/entries/entries.controller.ts`:

```ts
  @Delete(':id/entries/:date')
  deleteEntry(
    @Param('id', new ParseUUIDPipe()) habitId: string,
    @Param('date') date: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.entriesService.deleteEntry(userId, habitId, date);
  }
```

`ParseDatePipe` is dropped: it yields a `Date` parsed as a local instant, which reintroduces the day shift `standardizeDate` exists to prevent. The service normalises the string itself. `ParseDatePipe` is no longer used in this file — drop it from the import.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && npx jest src/entries/entries.service.spec.ts`
Expected: PASS (3 tests)

- [ ] **Step 5: Run the whole backend suite and typecheck**

Run: `cd backend && npm test && npx tsc --noEmit`
Expected: all suites PASS, no type errors

- [ ] **Step 6: Commit**

```bash
git add backend/src/entries/entries.controller.ts backend/src/entries/entries.service.ts backend/src/entries/entries.service.spec.ts
git commit -m "fix(backend): delete entries by habitId_date with an ownership check

The route supplies a habit id but the param was named entryId and the
service queried habitEntry.id with it, so un-checking never matched. It
was also the only /habits/** handler with no ownership check."
```

---
## Task 6: Client reads day keys in UTC too

`AppDateUtils.fromApiDate` does `DateTime.parse(value).toLocal()`, so an entry stored at UTC midnight becomes the *previous* day for anyone west of Greenwich. The existing test hedges with `isIn([8, 9, 10])` — that hedge exists because the behaviour is wrong. Fix it before any model parses a date.

**Files:**
- Modify: `mobile/lib/core/utils/date_utils.dart:29`
- Test: `mobile/test/core/utils/date_utils_test.dart:16-22`

**Interfaces:**
- Consumes: nothing.
- Produces: `AppDateUtils.fromApiDate(String) → DateTime` — a local `DateTime` at midnight whose calendar day is the UTC day of the input, for every timezone. `toApiDate`, `dateOnly`, `today`, `weekOf`, `startOfWeek`, `daysBetween` are unchanged and used throughout the rest of the plan.

- [ ] **Step 1: Replace the hedged assertion with a deterministic one**

In `mobile/test/core/utils/date_utils_test.dart`, replace the `fromApiDate` test:

```dart
    test('fromApiDate reads the UTC calendar day in every timezone', () {
      expect(AppDateUtils.fromApiDate('2026-09-09'), DateTime(2026, 9, 9));
      // Entries are stored at UTC midnight. Converting to local time first
      // would move this to the 8th anywhere west of Greenwich.
      expect(
        AppDateUtils.fromApiDate('2026-09-09T00:00:00.000Z'),
        DateTime(2026, 9, 9),
      );
      // Any instant on the 9th UTC still reads as the 9th.
      expect(
        AppDateUtils.fromApiDate('2026-09-09T23:59:59.000Z'),
        DateTime(2026, 9, 9),
      );
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/core/utils/date_utils_test.dart`
Expected: FAIL in any non-UTC zone — `DateTime(2026, 9, 8)` where `DateTime(2026, 9, 9)` was expected. (In a UTC zone it passes; step 4 forces the failure regardless.)

- [ ] **Step 3: Write the implementation**

Replace `fromApiDate` in `mobile/lib/core/utils/date_utils.dart`:

```dart
  /// Parses an API date into the local calendar day it denotes.
  ///
  /// The backend writes `HabitEntry.date` at UTC midnight, so a timestamp is
  /// read in UTC — converting to local time first would shift the day back for
  /// anyone west of Greenwich. A bare `yyyy-MM-dd` is already a day with no
  /// zone, so it is taken as-is.
  static DateTime fromApiDate(String value) {
    if (value.length == 10) return DateTime.parse(value);
    final utc = DateTime.parse(value).toUtc();
    return DateTime(utc.year, utc.month, utc.day);
  }
```

- [ ] **Step 4: Run the test in both timezone extremes**

Run: `cd mobile && TZ=Pacific/Kiritimati flutter test test/core/utils/date_utils_test.dart && TZ=Pacific/Midway flutter test test/core/utils/date_utils_test.dart`
Expected: PASS in both

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/core/utils/date_utils.dart mobile/test/core/utils/date_utils_test.dart
git commit -m "fix(mobile): read API day keys in UTC

Entries are stored at UTC midnight; converting to local time first moved
every check-off back a day west of Greenwich."
```

---

## Task 7: Habit models and the `DailyHabit` entity

`GET /habits?date=` returns a habit row decorated with `doneToday` and `currentStreak` — a different shape from a bare habit. It gets its own entity so `Habit` stays a faithful mirror of the DB row.

**Files:**
- Create: `mobile/lib/features/habits/domain/entities/daily_habit.dart`
- Create: `mobile/lib/features/habits/data/models/habit_model.dart`
- Create: `mobile/lib/features/habits/data/models/daily_habit_model.dart`
- Test: `mobile/test/features/habits/data/habit_model_test.dart`

**Interfaces:**
- Consumes: `Habit` (`habits/domain/entities/habit.dart`), `AppDateUtils` from Task 6.
- Produces:
  - `class DailyHabit { final Habit habit; final bool doneToday; final int currentStreak; }` with `const DailyHabit({required habit, required doneToday, required currentStreak})`, forwarding getters `id`, `name`, `color`, and `DailyHabit copyWith({bool? doneToday, int? currentStreak})`.
  - `class HabitModel extends Habit` with `factory HabitModel.fromJson(Map<String, dynamic>)` and `Map<String, dynamic> toJson()`.
  - `class DailyHabitModel extends DailyHabit` with `factory DailyHabitModel.fromJson(Map<String, dynamic>)`.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/habits/data/habit_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/habits/data/models/daily_habit_model.dart';
import 'package:mobile/features/habits/data/models/habit_model.dart';

void main() {
  const habitJson = {
    'id': 'bbbbbbbb-0000-4000-8000-000000000001',
    'userId': 'aaaaaaaa-0000-4000-8000-000000000001',
    'name': 'Read',
    'color': '#4D6054',
    'createdAt': '2026-01-01T09:30:00.000Z',
    'archivedAt': null,
  };

  group('HabitModel', () {
    test('parses the row the API returns', () {
      final habit = HabitModel.fromJson(habitJson);

      expect(habit.id, 'bbbbbbbb-0000-4000-8000-000000000001');
      expect(habit.name, 'Read');
      expect(habit.color, '#4D6054');
      expect(habit.archivedAt, isNull);
      expect(habit.isArchived, isFalse);
    });

    test('treats a missing colour as null rather than throwing', () {
      final habit = HabitModel.fromJson({...habitJson}..remove('color'));

      expect(habit.color, isNull);
    });

    test('parses an archived habit', () {
      final habit = HabitModel.fromJson({
        ...habitJson,
        'archivedAt': '2026-02-01T00:00:00.000Z',
      });

      expect(habit.isArchived, isTrue);
    });

    test('round-trips through toJson', () {
      final habit = HabitModel.fromJson(habitJson);
      final restored = HabitModel.fromJson(habit.toJson());

      expect(restored, habit);
    });
  });

  group('DailyHabitModel', () {
    test('lifts doneToday and currentStreak off the decorated row', () {
      final daily = DailyHabitModel.fromJson({
        ...habitJson,
        'doneToday': true,
        'currentStreak': 5,
      });

      expect(daily.doneToday, isTrue);
      expect(daily.currentStreak, 5);
      expect(daily.name, 'Read');
      expect(daily.id, habitJson['id']);
      expect(daily.color, '#4D6054');
    });

    test('defaults the decoration when the API omits it', () {
      final daily = DailyHabitModel.fromJson(habitJson);

      expect(daily.doneToday, isFalse);
      expect(daily.currentStreak, 0);
    });

    test('copyWith replaces only what it is given', () {
      final daily = DailyHabitModel.fromJson({
        ...habitJson,
        'doneToday': false,
        'currentStreak': 2,
      });

      final toggled = daily.copyWith(doneToday: true, currentStreak: 3);

      expect(toggled.doneToday, isTrue);
      expect(toggled.currentStreak, 3);
      expect(toggled.habit, daily.habit);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/habits/data/habit_model_test.dart`
Expected: FAIL — the imported files do not exist.

- [ ] **Step 3: Write the entity**

```dart
// mobile/lib/features/habits/domain/entities/daily_habit.dart
import 'habit.dart';

/// A habit as `GET /habits?date=` returns it: the row plus the two fields the
/// backend computes for that day.
///
/// Kept separate from [Habit] because it is a different shape, not a richer
/// one — the undecorated `GET /habits` never carries these, and [Habit] stays a
/// faithful mirror of the database row.
class DailyHabit {
  const DailyHabit({
    required this.habit,
    required this.doneToday,
    required this.currentStreak,
  });

  final Habit habit;

  /// Whether the habit was checked off on the requested day.
  final bool doneToday;

  /// Consecutive days ending at the requested day, computed by the backend's
  /// `computeCurrentStreak`. Never stored.
  final int currentStreak;

  String get id => habit.id;
  String get name => habit.name;
  String? get color => habit.color;

  DailyHabit copyWith({bool? doneToday, int? currentStreak}) {
    return DailyHabit(
      habit: habit,
      doneToday: doneToday ?? this.doneToday,
      currentStreak: currentStreak ?? this.currentStreak,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyHabit &&
          habit == other.habit &&
          doneToday == other.doneToday &&
          currentStreak == other.currentStreak;

  @override
  int get hashCode => Object.hash(habit, doneToday, currentStreak);

  @override
  String toString() =>
      'DailyHabit(${habit.name}, done: $doneToday, streak: $currentStreak)';
}
```

- [ ] **Step 4: Write the models**

```dart
// mobile/lib/features/habits/data/models/habit_model.dart
import '../../domain/entities/habit.dart';

/// Wire representation of [Habit].
///
/// Extends the entity so a model is usable anywhere a [Habit] is, while every
/// mention of JSON stays inside the data layer.
class HabitModel extends Habit {
  const HabitModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.createdAt,
    super.color,
    super.archivedAt,
  });

  /// Parses a row from `GET /habits`, `POST /habits` or `PATCH /habits/:id`.
  factory HabitModel.fromJson(Map<String, dynamic> json) {
    final archivedAt = json['archivedAt'] as String?;
    return HabitModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      color: json['color'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      archivedAt:
          archivedAt == null ? null : DateTime.parse(archivedAt).toLocal(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'name': name,
        'color': color,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'archivedAt': archivedAt?.toUtc().toIso8601String(),
      };
}
```

```dart
// mobile/lib/features/habits/data/models/daily_habit_model.dart
import '../../domain/entities/daily_habit.dart';
import 'habit_model.dart';

/// Wire representation of [DailyHabit].
///
/// The backend returns the decoration flattened onto the habit row rather than
/// nested, so the habit is parsed from the same map.
class DailyHabitModel extends DailyHabit {
  const DailyHabitModel({
    required super.habit,
    required super.doneToday,
    required super.currentStreak,
  });

  /// Parses a row from `GET /habits?date=`.
  ///
  /// `doneToday` and `currentStreak` default rather than throw: the same
  /// endpoint without a `date` omits them, and a habit nobody has checked off
  /// is genuinely "not done, streak zero".
  factory DailyHabitModel.fromJson(Map<String, dynamic> json) {
    return DailyHabitModel(
      habit: HabitModel.fromJson(json),
      doneToday: json['doneToday'] as bool? ?? false,
      currentStreak: json['currentStreak'] as int? ?? 0,
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/habits/data/habit_model_test.dart`
Expected: PASS (7 tests)

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/features/habits/domain/entities/daily_habit.dart mobile/lib/features/habits/data/models/ mobile/test/features/habits/data/habit_model_test.dart
git commit -m "feat(mobile): add habit models and the DailyHabit entity"
```

---

## Task 8: Habit datasource and repository

**Files:**
- Create: `mobile/lib/features/habits/data/datasources/habit_remote_datasource.dart`
- Create: `mobile/lib/features/habits/data/repositories/habit_repository_impl.dart`
- Modify: `mobile/lib/features/habits/domain/repositories/habit_repository.dart` (revise the interface)
- Test: `mobile/test/features/habits/data/habit_repository_impl_test.dart`

**Interfaces:**
- Consumes: `HabitModel`, `DailyHabitModel` (Task 7); `ApiClient`, `ApiConstants`, `NetworkInfo`, `AppDateUtils`, the `AppException` family and the `Failure` family from `core/`.
- Produces:
  - `abstract interface class HabitRemoteDataSource` with `getHabits()`, `getHabitsForDate(DateTime date)`, `createHabit({required String name, String? color})`, `updateHabit({required String habitId, String? name, String? color, bool? archived})`, `deleteHabit(String habitId)`; and `HabitRemoteDataSourceImpl(ApiClient)`.
  - Revised `HabitRepository`: `Future<Result<List<Habit>>> getHabits()`, `Future<Result<List<DailyHabit>>> getHabitsForDate(DateTime date)`, `Future<Result<Habit>> createHabit({required String name, String? color})`, `Future<Result<Habit>> updateHabit({required String habitId, String? name, String? color, bool? archived})`, `Future<Result<void>> deleteHabit(String habitId)`.
  - `HabitRepositoryImpl({required HabitRemoteDataSource remoteDataSource, required NetworkInfo networkInfo})`.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/habits/data/habit_repository_impl_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/exceptions.dart';
import 'package:mobile/core/errors/failures.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/features/habits/data/models/daily_habit_model.dart';
import 'package:mobile/features/habits/data/models/habit_model.dart';
import 'package:mobile/features/habits/data/repositories/habit_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockHabitRemoteDataSource remote;
  late MockNetworkInfo network;
  late HabitRepositoryImpl repository;

  final habit = buildHabitModel();

  setUp(() {
    remote = MockHabitRemoteDataSource();
    network = MockNetworkInfo();
    when(() => network.isConnected).thenAnswer((_) async => true);
    repository = HabitRepositoryImpl(
      remoteDataSource: remote,
      networkInfo: network,
    );
  });

  group('getHabitsForDate', () {
    test('returns the decorated list on success', () async {
      final daily = DailyHabitModel(
        habit: habit,
        doneToday: true,
        currentStreak: 4,
      );
      when(() => remote.getHabitsForDate(any()))
          .thenAnswer((_) async => [daily]);

      final result = await repository.getHabitsForDate(DateTime(2026, 3, 10));

      expect(result, isA<Success<List<dynamic>>>());
      expect(result.dataOrNull!.single.currentStreak, 4);
    });

    test('short-circuits when offline without touching the network', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);

      final result = await repository.getHabitsForDate(DateTime(2026, 3, 10));

      expect(result.failureOrNull, isA<NetworkFailure>());
      verifyNever(() => remote.getHabitsForDate(any()));
    });
  });

  group('exception translation', () {
    test('maps every AppException onto its Failure', () async {
      final cases = <AppException, Type>{
        const NetworkException(): NetworkFailure,
        const UnauthorizedException(): AuthFailure,
        const ValidationException('bad', errors: ['name should not be empty']):
            ValidationFailure,
        const NotFoundException(): NotFoundFailure,
        const ServerException('boom', statusCode: 500): ServerFailure,
      };

      for (final entry in cases.entries) {
        when(() => remote.getHabits()).thenThrow(entry.key);

        final result = await repository.getHabits();

        expect(
          result.failureOrNull.runtimeType,
          entry.value,
          reason: '${entry.key.runtimeType} should become ${entry.value}',
        );
      }
    });

    test('keeps the field messages from a validation failure', () async {
      when(() => remote.createHabit(name: any(named: 'name'), color: any(named: 'color')))
          .thenThrow(const ValidationException(
        'name should not be empty',
        errors: ['name should not be empty'],
      ));

      final result = await repository.createHabit(name: '');

      final failure = result.failureOrNull! as ValidationFailure;
      expect(failure.errors, ['name should not be empty']);
    });

    test('an unrecognised error becomes UnexpectedFailure', () async {
      when(() => remote.getHabits()).thenThrow(StateError('nope'));

      final result = await repository.getHabits();

      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });

  group('mutations', () {
    test('createHabit forwards the name and colour', () async {
      when(() => remote.createHabit(name: 'Read', color: '#4D6054'))
          .thenAnswer((_) async => habit);

      final result = await repository.createHabit(name: 'Read', color: '#4D6054');

      expect(result.dataOrNull, habit);
    });

    test('updateHabit forwards only the fields it is given', () async {
      when(() => remote.updateHabit(
            habitId: habit.id,
            name: 'Read daily',
            color: null,
            archived: null,
          )).thenAnswer((_) async => habit);

      final result = await repository.updateHabit(
        habitId: habit.id,
        name: 'Read daily',
      );

      expect(result.isSuccess, isTrue);
    });

    test('deleteHabit succeeds with no payload', () async {
      when(() => remote.deleteHabit(habit.id)).thenAnswer((_) async {});

      final result = await repository.deleteHabit(habit.id);

      expect(result.isSuccess, isTrue);
    });
  });
}
```

- [ ] **Step 2: Extend the shared mocks**

Append to `mobile/test/helpers/mocks.dart` (and add the matching imports at the top of that file):

```dart
class MockHabitRemoteDataSource extends Mock implements HabitRemoteDataSource {}

class MockEntryRemoteDataSource extends Mock implements EntryRemoteDataSource {}

class MockHabitRepository extends Mock implements HabitRepository {}

class MockEntryRepository extends Mock implements EntryRepository {}

/// A representative habit, so tests do not each invent their own.
HabitModel buildHabitModel({
  String id = 'bbbbbbbb-0000-4000-8000-000000000001',
  String userId = '11111111-1111-4111-8111-111111111111',
  String name = 'Read',
  String? color = '#4D6054',
  DateTime? createdAt,
  DateTime? archivedAt,
}) {
  return HabitModel(
    id: id,
    userId: userId,
    name: name,
    color: color,
    createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
    archivedAt: archivedAt,
  );
}

/// A representative decorated habit.
DailyHabitModel buildDailyHabit({
  HabitModel? habit,
  bool doneToday = false,
  int currentStreak = 0,
}) {
  return DailyHabitModel(
    habit: habit ?? buildHabitModel(),
    doneToday: doneToday,
    currentStreak: currentStreak,
  );
}
```

Also extend `registerFallbacks()` in the same file so `any()` works for the new argument types:

```dart
void registerFallbacks() {
  registerFallbackValue(buildUserModel());
  registerFallbackValue(buildHabitModel());
  registerFallbackValue(DateTime(2026, 1, 1));
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/habits/data/habit_repository_impl_test.dart`
Expected: FAIL — the datasource and repository implementation do not exist.

- [ ] **Step 4: Write the datasource**

```dart
// mobile/lib/features/habits/data/datasources/habit_remote_datasource.dart
import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/date_utils.dart';
import '../models/daily_habit_model.dart';
import '../models/habit_model.dart';

/// Habit CRUD against the NestJS backend.
///
/// Throws [AppException] on failure — mapping to a `Failure` is the
/// repository's job.
abstract interface class HabitRemoteDataSource {
  /// `GET /habits` — active habits, undecorated.
  Future<List<HabitModel>> getHabits();

  /// `GET /habits?date=yyyy-MM-dd` — each row plus `doneToday` and
  /// `currentStreak` for that day.
  Future<List<DailyHabitModel>> getHabitsForDate(DateTime date);

  /// `POST /habits`
  Future<HabitModel> createHabit({required String name, String? color});

  /// `PATCH /habits/:id` — only non-null fields are sent.
  Future<HabitModel> updateHabit({
    required String habitId,
    String? name,
    String? color,
    bool? archived,
  });

  /// `DELETE /habits/:id`
  Future<void> deleteHabit(String habitId);
}

class HabitRemoteDataSourceImpl implements HabitRemoteDataSource {
  const HabitRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<HabitModel>> getHabits() async {
    final json = await _client.get<List<dynamic>>(ApiConstants.habits);
    return json
        .map((row) => HabitModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<DailyHabitModel>> getHabitsForDate(DateTime date) async {
    final json = await _client.get<List<dynamic>>(
      ApiConstants.habits,
      queryParameters: {'date': AppDateUtils.toApiDate(date)},
    );
    return json
        .map((row) => DailyHabitModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<HabitModel> createHabit({required String name, String? color}) async {
    final json = await _client.post<Map<String, dynamic>>(
      ApiConstants.habits,
      data: {'name': name, if (color != null) 'color': color},
    );
    return HabitModel.fromJson(json);
  }

  @override
  Future<HabitModel> updateHabit({
    required String habitId,
    String? name,
    String? color,
    bool? archived,
  }) async {
    // Omitting a field is how the caller says "leave it alone"; sending null
    // would clear the colour and, before the backend fix, un-archive the row.
    final json = await _client.patch<Map<String, dynamic>>(
      ApiConstants.habit(habitId),
      data: {
        if (name != null) 'name': name,
        if (color != null) 'color': color,
        if (archived != null) 'archived': archived,
      },
    );
    return HabitModel.fromJson(json);
  }

  @override
  Future<void> deleteHabit(String habitId) async {
    await _client.delete<Map<String, dynamic>>(ApiConstants.habit(habitId));
  }
}
```

- [ ] **Step 5: Revise the repository interface**

Replace the body of `mobile/lib/features/habits/domain/repositories/habit_repository.dart`:

```dart
import '../../../../core/errors/result.dart';
import '../entities/daily_habit.dart';
import '../entities/habit.dart';

/// Habit CRUD, as the domain layer needs it.
///
/// Backed by `backend/src/habit/habit.controller.ts`.
abstract interface class HabitRepository {
  /// `GET /habits` — active habits, undecorated.
  Future<Result<List<Habit>>> getHabits();

  /// `GET /habits?date=` — active habits decorated with `doneToday` and
  /// `currentStreak` for [date]. A separate method because the response is a
  /// different shape, not a richer one.
  Future<Result<List<DailyHabit>>> getHabitsForDate(DateTime date);

  /// `POST /habits`.
  Future<Result<Habit>> createHabit({required String name, String? color});

  /// `PATCH /habits/:id`. Only the supplied fields are changed.
  Future<Result<Habit>> updateHabit({
    required String habitId,
    String? name,
    String? color,
    bool? archived,
  });

  /// `DELETE /habits/:id`.
  Future<Result<void>> deleteHabit(String habitId);
}
```

- [ ] **Step 6: Write the repository implementation**

```dart
// mobile/lib/features/habits/data/repositories/habit_repository_impl.dart
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/daily_habit.dart';
import '../../domain/entities/habit.dart';
import '../../domain/repositories/habit_repository.dart';
import '../datasources/habit_remote_datasource.dart';

/// The only place where habit exceptions become failures.
class HabitRepositoryImpl implements HabitRepository {
  const HabitRepositoryImpl({
    required HabitRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
  })  : _remote = remoteDataSource,
        _networkInfo = networkInfo;

  final HabitRemoteDataSource _remote;
  final NetworkInfo _networkInfo;

  @override
  Future<Result<List<Habit>>> getHabits() => _guard(_remote.getHabits);

  @override
  Future<Result<List<DailyHabit>>> getHabitsForDate(DateTime date) =>
      _guard(() => _remote.getHabitsForDate(date));

  @override
  Future<Result<Habit>> createHabit({required String name, String? color}) =>
      _guard(() => _remote.createHabit(name: name, color: color));

  @override
  Future<Result<Habit>> updateHabit({
    required String habitId,
    String? name,
    String? color,
    bool? archived,
  }) {
    return _guard(() => _remote.updateHabit(
          habitId: habitId,
          name: name,
          color: color,
          archived: archived,
        ));
  }

  @override
  Future<Result<void>> deleteHabit(String habitId) =>
      _guard(() => _remote.deleteHabit(habitId));

  /// Checks connectivity, runs [call], and converts anything thrown into a
  /// [Failure]. Every method is this shape, so it lives in one place.
  Future<Result<T>> _guard<T>(Future<T> Function() call) async {
    if (!await _networkInfo.isConnected) {
      return const ResultError(NetworkFailure());
    }
    try {
      return Success(await call());
    } on AppException catch (exception) {
      return ResultError(_toFailure(exception));
    } on Object catch (error, stackTrace) {
      Logger.error('Habit request failed', error: error, stackTrace: stackTrace);
      return const ResultError(UnexpectedFailure());
    }
  }

  Failure _toFailure(AppException exception) => switch (exception) {
        NetworkException() => NetworkFailure(exception.message),
        UnauthorizedException() => AuthFailure(exception.message),
        ValidationException(:final errors) =>
          ValidationFailure(exception.message, errors: errors),
        NotFoundException() => NotFoundFailure(exception.message),
        CacheException() => CacheFailure(exception.message),
        ServerException(:final statusCode) =>
          ServerFailure(exception.message, statusCode: statusCode),
      };
}
```

- [ ] **Step 7: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/habits/data/habit_repository_impl_test.dart`
Expected: PASS (8 tests)

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/features/habits/data/ mobile/lib/features/habits/domain/repositories/habit_repository.dart mobile/test/features/habits/data/habit_repository_impl_test.dart mobile/test/helpers/mocks.dart
git commit -m "feat(mobile): implement the habit datasource and repository

Splits getHabits into the bare and date-decorated calls, matching what
the endpoint actually returns in each case."
```

---

## Task 9: Habit use cases

**Files:**
- Create: `mobile/lib/features/habits/domain/usecases/get_daily_habits.dart`
- Create: `mobile/lib/features/habits/domain/usecases/create_habit.dart`
- Create: `mobile/lib/features/habits/domain/usecases/update_habit.dart`
- Create: `mobile/lib/features/habits/domain/usecases/delete_habit.dart`
- Test: `mobile/test/features/habits/domain/habit_usecases_test.dart`

**Interfaces:**
- Consumes: `HabitRepository` (Task 8), `AppDateUtils` (Task 6).
- Produces:
  - `GetDailyHabits(HabitRepository)` — `Future<Result<List<DailyHabit>>> call({DateTime? date})`, defaulting to today.
  - `CreateHabit(HabitRepository)` — `Future<Result<Habit>> call({required String name, String? color})`; validates locally.
  - `UpdateHabit(HabitRepository)` — `Future<Result<Habit>> call({required String habitId, String? name, String? color, bool? archived})`; validates `name` when present.
  - `DeleteHabit(HabitRepository)` — `Future<Result<void>> call(String habitId)`.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/habits/domain/habit_usecases_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/failures.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/core/utils/date_utils.dart';
import 'package:mobile/features/habits/domain/usecases/create_habit.dart';
import 'package:mobile/features/habits/domain/usecases/delete_habit.dart';
import 'package:mobile/features/habits/domain/usecases/get_daily_habits.dart';
import 'package:mobile/features/habits/domain/usecases/update_habit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockHabitRepository repository;

  setUpAll(registerFallbacks);

  setUp(() {
    repository = MockHabitRepository();
  });

  group('GetDailyHabits', () {
    test('defaults to today', () async {
      when(() => repository.getHabitsForDate(any()))
          .thenAnswer((_) async => const Success(<Never>[]));

      await GetDailyHabits(repository)();

      final captured =
          verify(() => repository.getHabitsForDate(captureAny())).captured.single
              as DateTime;
      expect(AppDateUtils.isToday(captured), isTrue);
    });

    test('passes an explicit date through', () async {
      when(() => repository.getHabitsForDate(any()))
          .thenAnswer((_) async => const Success(<Never>[]));

      await GetDailyHabits(repository)(date: DateTime(2026, 3, 10));

      verify(() => repository.getHabitsForDate(DateTime(2026, 3, 10))).called(1);
    });
  });

  group('CreateHabit', () {
    test('rejects a blank name without a round trip', () async {
      final result = await CreateHabit(repository)(name: '   ');

      expect(result.failureOrNull, isA<ValidationFailure>());
      verifyNever(() => repository.createHabit(
            name: any(named: 'name'),
            color: any(named: 'color'),
          ));
    });

    test('rejects a name longer than 60 characters', () async {
      final result = await CreateHabit(repository)(name: 'a' * 61);

      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('rejects a colour that is not hex', () async {
      final result =
          await CreateHabit(repository)(name: 'Read', color: 'forest green');

      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('trims the name before sending it', () async {
      when(() => repository.createHabit(
            name: any(named: 'name'),
            color: any(named: 'color'),
          )).thenAnswer((_) async => Success(buildHabitModel()));

      await CreateHabit(repository)(name: '  Read  ', color: '#4D6054');

      verify(() => repository.createHabit(name: 'Read', color: '#4D6054'))
          .called(1);
    });
  });

  group('UpdateHabit', () {
    test('rejects a blank rename', () async {
      final result =
          await UpdateHabit(repository)(habitId: 'habit-1', name: '  ');

      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('an archive with no name skips name validation', () async {
      when(() => repository.updateHabit(
            habitId: any(named: 'habitId'),
            name: any(named: 'name'),
            color: any(named: 'color'),
            archived: any(named: 'archived'),
          )).thenAnswer((_) async => Success(buildHabitModel()));

      final result =
          await UpdateHabit(repository)(habitId: 'habit-1', archived: true);

      expect(result.isSuccess, isTrue);
    });
  });

  group('DeleteHabit', () {
    test('forwards the id', () async {
      when(() => repository.deleteHabit('habit-1'))
          .thenAnswer((_) async => const Success(null));

      final result = await DeleteHabit(repository)('habit-1');

      expect(result.isSuccess, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/habits/domain/habit_usecases_test.dart`
Expected: FAIL — none of the use case files exist.

- [ ] **Step 3: Write the use cases**

```dart
// mobile/lib/features/habits/domain/usecases/get_daily_habits.dart
import '../../../../core/errors/result.dart';
import '../../../../core/utils/date_utils.dart';
import '../entities/daily_habit.dart';
import '../repositories/habit_repository.dart';

/// Loads the habits for one day, decorated with `doneToday` and
/// `currentStreak`.
class GetDailyHabits {
  const GetDailyHabits(this._repository);

  final HabitRepository _repository;

  /// [date] defaults to today, which is what every current caller wants.
  Future<Result<List<DailyHabit>>> call({DateTime? date}) {
    return _repository.getHabitsForDate(date ?? AppDateUtils.today);
  }
}
```

```dart
// mobile/lib/features/habits/domain/usecases/habit_validators.dart
import '../../../../core/errors/failures.dart';

/// Input rules shared by [CreateHabit] and [UpdateHabit].
///
/// They mirror the backend DTOs — `@IsNotEmpty()` on the name and
/// `@IsHexColor()` on the colour — so an obviously bad value fails before it
/// costs a round trip. The backend still validates; this is not the guard.
abstract final class HabitValidators {
  static const int maxNameLength = 60;

  static final RegExp _hex = RegExp(r'^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$');

  /// Returns a failure when [name] is unusable, otherwise null.
  static ValidationFailure? name(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const ValidationFailure('Give your habit a name.');
    }
    if (trimmed.length > maxNameLength) {
      return const ValidationFailure(
        'Habit names are limited to $maxNameLength characters.',
      );
    }
    return null;
  }

  /// Returns a failure when [color] is present and not a hex colour.
  static ValidationFailure? color(String? color) {
    if (color == null) return null;
    if (!_hex.hasMatch(color)) {
      return const ValidationFailure('Pick a colour from the palette.');
    }
    return null;
  }
}
```

> Note: `ValidationFailure` takes a `const` message, so the `maxNameLength`
> interpolation above must be written as a literal `'Habit names are limited to
> 60 characters.'` — adjust if the analyzer objects to a non-constant
> interpolation.

```dart
// mobile/lib/features/habits/domain/usecases/create_habit.dart
import '../../../../core/errors/result.dart';
import '../entities/habit.dart';
import '../repositories/habit_repository.dart';
import 'habit_validators.dart';

/// Creates a habit for the signed-in user.
class CreateHabit {
  const CreateHabit(this._repository);

  final HabitRepository _repository;

  Future<Result<Habit>> call({required String name, String? color}) async {
    final nameFailure = HabitValidators.name(name);
    if (nameFailure != null) return ResultError(nameFailure);

    final colorFailure = HabitValidators.color(color);
    if (colorFailure != null) return ResultError(colorFailure);

    return _repository.createHabit(name: name.trim(), color: color);
  }
}
```

```dart
// mobile/lib/features/habits/domain/usecases/update_habit.dart
import '../../../../core/errors/result.dart';
import '../entities/habit.dart';
import '../repositories/habit_repository.dart';
import 'habit_validators.dart';

/// Renames, recolours or archives a habit. Omitted fields are left alone.
class UpdateHabit {
  const UpdateHabit(this._repository);

  final HabitRepository _repository;

  Future<Result<Habit>> call({
    required String habitId,
    String? name,
    String? color,
    bool? archived,
  }) async {
    // Only validate what was actually supplied: archiving does not carry a
    // name, and validating a null one would reject it.
    if (name != null) {
      final nameFailure = HabitValidators.name(name);
      if (nameFailure != null) return ResultError(nameFailure);
    }

    final colorFailure = HabitValidators.color(color);
    if (colorFailure != null) return ResultError(colorFailure);

    return _repository.updateHabit(
      habitId: habitId,
      name: name?.trim(),
      color: color,
      archived: archived,
    );
  }
}
```

```dart
// mobile/lib/features/habits/domain/usecases/delete_habit.dart
import '../../../../core/errors/result.dart';
import '../repositories/habit_repository.dart';

/// Permanently removes a habit and, by cascade, all of its entries.
class DeleteHabit {
  const DeleteHabit(this._repository);

  final HabitRepository _repository;

  Future<Result<void>> call(String habitId) =>
      _repository.deleteHabit(habitId);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/habits/domain/habit_usecases_test.dart`
Expected: PASS (9 tests)

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/habits/domain/usecases/ mobile/test/features/habits/domain/habit_usecases_test.dart
git commit -m "feat(mobile): add habit use cases with local validation"
```

---

## Task 10: Entry datasource, repository and use cases

**Files:**
- Create: `mobile/lib/features/entries/data/models/habit_entry_model.dart`
- Create: `mobile/lib/features/entries/data/datasources/entry_remote_datasource.dart`
- Create: `mobile/lib/features/entries/data/repositories/entry_repository_impl.dart`
- Create: `mobile/lib/features/entries/domain/usecases/set_entry.dart`
- Create: `mobile/lib/features/entries/domain/usecases/get_entries.dart`
- Modify: `mobile/lib/features/entries/domain/repositories/entry_repository.dart`
- Test: `mobile/test/features/entries/data/entry_repository_impl_test.dart`

**Interfaces:**
- Consumes: `ApiConstants.entries(habitId)`, `ApiConstants.entry(habitId, date)`, `AppDateUtils`, `NetworkInfo`.
- Produces:
  - `HabitEntryModel extends HabitEntry` with `factory HabitEntryModel.fromJson(Map<String, dynamic>)`.
  - `abstract interface class EntryRemoteDataSource` with `checkOff({required String habitId, required DateTime date}) → Future<HabitEntryModel>`, `getEntries({required String habitId, required DateTime from, required DateTime to}) → Future<List<DateTime>>`, `deleteEntry({required String habitId, required DateTime date}) → Future<void>`; and `EntryRemoteDataSourceImpl(ApiClient)`.
  - Revised `EntryRepository` — `getEntries` returns `Future<Result<List<DateTime>>>`, the other two unchanged in shape.
  - `EntryRepositoryImpl({required EntryRemoteDataSource remoteDataSource, required NetworkInfo networkInfo})`.
  - `SetEntry(EntryRepository)` — `Future<Result<void>> call({required String habitId, required DateTime date, required bool completed})`. `completed` is the **desired** state: true checks off, false un-checks.
  - `GetEntries(EntryRepository)` — `Future<Result<List<DateTime>>> call({required String habitId, required DateTime from, required DateTime to})`.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/entries/data/entry_repository_impl_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/exceptions.dart';
import 'package:mobile/core/errors/failures.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/features/entries/data/models/habit_entry_model.dart';
import 'package:mobile/features/entries/data/repositories/entry_repository_impl.dart';
import 'package:mobile/features/entries/domain/usecases/set_entry.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockEntryRemoteDataSource remote;
  late MockNetworkInfo network;
  late EntryRepositoryImpl repository;

  const habitId = 'bbbbbbbb-0000-4000-8000-000000000001';
  final day = DateTime(2026, 3, 10);

  setUpAll(registerFallbacks);

  setUp(() {
    remote = MockEntryRemoteDataSource();
    network = MockNetworkInfo();
    when(() => network.isConnected).thenAnswer((_) async => true);
    repository = EntryRepositoryImpl(
      remoteDataSource: remote,
      networkInfo: network,
    );
  });

  group('HabitEntryModel', () {
    test('parses the row POST returns, reading the day key in UTC', () {
      final entry = HabitEntryModel.fromJson(const {
        'id': 'eeeeeeee-0000-4000-8000-000000000001',
        'habitId': habitId,
        'date': '2026-03-10T00:00:00.000Z',
        'createdAt': '2026-03-10T08:15:00.000Z',
      });

      expect(entry.date, DateTime(2026, 3, 10));
      expect(entry.habitId, habitId);
    });
  });

  group('getEntries', () {
    test('returns the bare date list the endpoint sends', () async {
      when(() => remote.getEntries(
            habitId: any(named: 'habitId'),
            from: any(named: 'from'),
            to: any(named: 'to'),
          )).thenAnswer((_) async => [DateTime(2026, 3, 9), DateTime(2026, 3, 10)]);

      final result = await repository.getEntries(
        habitId: habitId,
        from: DateTime(2026, 3, 1),
        to: day,
      );

      expect(result.dataOrNull, [DateTime(2026, 3, 9), DateTime(2026, 3, 10)]);
    });

    test('short-circuits when offline', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);

      final result = await repository.getEntries(
        habitId: habitId,
        from: DateTime(2026, 3, 1),
        to: day,
      );

      expect(result.failureOrNull, isA<NetworkFailure>());
      verifyNever(() => remote.getEntries(
            habitId: any(named: 'habitId'),
            from: any(named: 'from'),
            to: any(named: 'to'),
          ));
    });
  });

  group('exception translation', () {
    test('a 404 becomes NotFoundFailure', () async {
      when(() => remote.checkOff(
            habitId: any(named: 'habitId'),
            date: any(named: 'date'),
          )).thenThrow(const NotFoundException());

      final result = await repository.checkOff(habitId: habitId, date: day);

      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('a 401 becomes AuthFailure', () async {
      when(() => remote.deleteEntry(
            habitId: any(named: 'habitId'),
            date: any(named: 'date'),
          )).thenThrow(const UnauthorizedException());

      final result = await repository.deleteEntry(habitId: habitId, date: day);

      expect(result.failureOrNull, isA<AuthFailure>());
    });
  });

  group('SetEntry', () {
    late MockEntryRepository entryRepository;

    setUp(() {
      entryRepository = MockEntryRepository();
    });

    test('completed true checks the day off', () async {
      when(() => entryRepository.checkOff(
            habitId: any(named: 'habitId'),
            date: any(named: 'date'),
          )).thenAnswer((_) async => Success(buildHabitEntryModel()));

      await SetEntry(entryRepository)(
        habitId: habitId,
        date: day,
        completed: true,
      );

      verify(() => entryRepository.checkOff(habitId: habitId, date: day))
          .called(1);
      verifyNever(() => entryRepository.deleteEntry(
            habitId: any(named: 'habitId'),
            date: any(named: 'date'),
          ));
    });

    test('completed false un-checks the day', () async {
      when(() => entryRepository.deleteEntry(
            habitId: any(named: 'habitId'),
            date: any(named: 'date'),
          )).thenAnswer((_) async => const Success(null));

      await SetEntry(entryRepository)(
        habitId: habitId,
        date: day,
        completed: false,
      );

      verify(() => entryRepository.deleteEntry(habitId: habitId, date: day))
          .called(1);
    });

    test('un-checking a day that was never checked off is not an error',
        () async {
      when(() => entryRepository.deleteEntry(
            habitId: any(named: 'habitId'),
            date: any(named: 'date'),
          )).thenAnswer((_) async => const ResultError(NotFoundFailure()));

      final result = await SetEntry(entryRepository)(
        habitId: habitId,
        date: day,
        completed: false,
      );

      expect(result.isSuccess, isTrue);
    });
  });
}
```

Add the entry builder to `mobile/test/helpers/mocks.dart`:

```dart
/// A representative entry.
HabitEntryModel buildHabitEntryModel({
  String id = 'eeeeeeee-0000-4000-8000-000000000001',
  String habitId = 'bbbbbbbb-0000-4000-8000-000000000001',
  DateTime? date,
  DateTime? createdAt,
}) {
  return HabitEntryModel(
    id: id,
    habitId: habitId,
    date: date ?? DateTime(2026, 3, 10),
    createdAt: createdAt ?? DateTime.utc(2026, 3, 10, 8),
  );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/entries/data/entry_repository_impl_test.dart`
Expected: FAIL — none of the entry data files exist.

- [ ] **Step 3: Write the model**

```dart
// mobile/lib/features/entries/data/models/habit_entry_model.dart
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/habit_entry.dart';

/// Wire representation of [HabitEntry], as `POST /habits/:id/entries` returns
/// it.
///
/// `GET /habits/:id/entries` sends bare dates instead, so it is parsed with
/// [AppDateUtils.fromApiDate] directly rather than through this model.
class HabitEntryModel extends HabitEntry {
  const HabitEntryModel({
    required super.id,
    required super.habitId,
    required super.date,
    required super.createdAt,
  });

  factory HabitEntryModel.fromJson(Map<String, dynamic> json) {
    return HabitEntryModel(
      id: json['id'] as String,
      habitId: json['habitId'] as String,
      // A day key, not an instant: read it in UTC.
      date: AppDateUtils.fromApiDate(json['date'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }
}
```

- [ ] **Step 4: Write the datasource**

```dart
// mobile/lib/features/entries/data/datasources/entry_remote_datasource.dart
import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/date_utils.dart';
import '../models/habit_entry_model.dart';

/// Check-offs against the NestJS backend.
///
/// Throws [AppException] on failure — mapping to a `Failure` is the
/// repository's job.
abstract interface class EntryRemoteDataSource {
  /// `POST /habits/:id/entries` — idempotent, an upsert on `(habitId, date)`.
  Future<HabitEntryModel> checkOff({
    required String habitId,
    required DateTime date,
  });

  /// `GET /habits/:id/entries?from&to`, both bounds inclusive.
  ///
  /// The endpoint responds `{ "entries": [Date] }` — bare days with no ids.
  Future<List<DateTime>> getEntries({
    required String habitId,
    required DateTime from,
    required DateTime to,
  });

  /// `DELETE /habits/:id/entries/:date`
  Future<void> deleteEntry({required String habitId, required DateTime date});
}

class EntryRemoteDataSourceImpl implements EntryRemoteDataSource {
  const EntryRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<HabitEntryModel> checkOff({
    required String habitId,
    required DateTime date,
  }) async {
    final json = await _client.post<Map<String, dynamic>>(
      ApiConstants.entries(habitId),
      data: {'date': AppDateUtils.toApiDate(date)},
    );
    return HabitEntryModel.fromJson(json);
  }

  @override
  Future<List<DateTime>> getEntries({
    required String habitId,
    required DateTime from,
    required DateTime to,
  }) async {
    final json = await _client.get<Map<String, dynamic>>(
      ApiConstants.entries(habitId),
      queryParameters: {
        'from': AppDateUtils.toApiDate(from),
        'to': AppDateUtils.toApiDate(to),
      },
    );
    final entries = json['entries'] as List<dynamic>? ?? const [];
    return entries
        .map((date) => AppDateUtils.fromApiDate(date as String))
        .toList();
  }

  @override
  Future<void> deleteEntry({
    required String habitId,
    required DateTime date,
  }) async {
    await _client.delete<Map<String, dynamic>>(
      ApiConstants.entry(habitId, AppDateUtils.toApiDate(date)),
    );
  }
}
```

- [ ] **Step 5: Revise the repository interface**

Replace the body of `mobile/lib/features/entries/domain/repositories/entry_repository.dart`:

```dart
import '../../../../core/errors/result.dart';
import '../entities/habit_entry.dart';

/// Check-offs for a habit, as the domain layer needs them.
///
/// Backed by `backend/src/entries/entries.controller.ts`.
abstract interface class EntryRepository {
  /// `POST /habits/:id/entries` — marks [habitId] complete on [date].
  Future<Result<HabitEntry>> checkOff({
    required String habitId,
    required DateTime date,
  });

  /// `GET /habits/:id/entries?from&to`, both bounds inclusive.
  ///
  /// Returns bare days: the endpoint responds `{ entries: Date[] }` with no
  /// ids, so there is no [HabitEntry] to build.
  Future<Result<List<DateTime>>> getEntries({
    required String habitId,
    required DateTime from,
    required DateTime to,
  });

  /// `DELETE /habits/:id/entries/:date` — undoes a check-off.
  Future<Result<void>> deleteEntry({
    required String habitId,
    required DateTime date,
  });
}
```

- [ ] **Step 6: Write the repository implementation**

```dart
// mobile/lib/features/entries/data/repositories/entry_repository_impl.dart
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/habit_entry.dart';
import '../../domain/repositories/entry_repository.dart';
import '../datasources/entry_remote_datasource.dart';

/// The only place where entry exceptions become failures.
class EntryRepositoryImpl implements EntryRepository {
  const EntryRepositoryImpl({
    required EntryRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
  })  : _remote = remoteDataSource,
        _networkInfo = networkInfo;

  final EntryRemoteDataSource _remote;
  final NetworkInfo _networkInfo;

  @override
  Future<Result<HabitEntry>> checkOff({
    required String habitId,
    required DateTime date,
  }) {
    return _guard(() => _remote.checkOff(habitId: habitId, date: date));
  }

  @override
  Future<Result<List<DateTime>>> getEntries({
    required String habitId,
    required DateTime from,
    required DateTime to,
  }) {
    return _guard(
      () => _remote.getEntries(habitId: habitId, from: from, to: to),
    );
  }

  @override
  Future<Result<void>> deleteEntry({
    required String habitId,
    required DateTime date,
  }) {
    return _guard(() => _remote.deleteEntry(habitId: habitId, date: date));
  }

  Future<Result<T>> _guard<T>(Future<T> Function() call) async {
    if (!await _networkInfo.isConnected) {
      return const ResultError(NetworkFailure());
    }
    try {
      return Success(await call());
    } on AppException catch (exception) {
      return ResultError(_toFailure(exception));
    } on Object catch (error, stackTrace) {
      Logger.error('Entry request failed', error: error, stackTrace: stackTrace);
      return const ResultError(UnexpectedFailure());
    }
  }

  Failure _toFailure(AppException exception) => switch (exception) {
        NetworkException() => NetworkFailure(exception.message),
        UnauthorizedException() => AuthFailure(exception.message),
        ValidationException(:final errors) =>
          ValidationFailure(exception.message, errors: errors),
        NotFoundException() => NotFoundFailure(exception.message),
        CacheException() => CacheFailure(exception.message),
        ServerException(:final statusCode) =>
          ServerFailure(exception.message, statusCode: statusCode),
      };
}
```

- [ ] **Step 7: Write the use cases**

```dart
// mobile/lib/features/entries/domain/usecases/set_entry.dart
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../repositories/entry_repository.dart';

/// Puts a habit's day into the requested state.
///
/// [completed] is the state the caller *wants*, not the current one, which
/// keeps the check-off toggle a single call with no branching in the widget.
class SetEntry {
  const SetEntry(this._repository);

  final EntryRepository _repository;

  Future<Result<void>> call({
    required String habitId,
    required DateTime date,
    required bool completed,
  }) async {
    if (completed) {
      final result = await _repository.checkOff(habitId: habitId, date: date);
      return result.map((_) {});
    }

    final result = await _repository.deleteEntry(habitId: habitId, date: date);

    // Un-checking a day that was never checked off already has the outcome the
    // caller asked for. Surfacing a 404 here would make a double tap look like
    // a failure.
    if (result.failureOrNull is NotFoundFailure) return const Success(null);
    return result;
  }
}
```

```dart
// mobile/lib/features/entries/domain/usecases/get_entries.dart
import '../../../../core/errors/result.dart';
import '../repositories/entry_repository.dart';

/// Loads the days a habit was completed within an inclusive window.
class GetEntries {
  const GetEntries(this._repository);

  final EntryRepository _repository;

  Future<Result<List<DateTime>>> call({
    required String habitId,
    required DateTime from,
    required DateTime to,
  }) {
    return _repository.getEntries(habitId: habitId, from: from, to: to);
  }
}
```

- [ ] **Step 8: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/entries/`
Expected: PASS (8 tests)

- [ ] **Step 9: Commit**

```bash
git add mobile/lib/features/entries/ mobile/test/features/entries/ mobile/test/helpers/mocks.dart
git commit -m "feat(mobile): implement the entry datasource, repository and use cases

getEntries returns bare dates, matching what the endpoint sends; the
HabitEntry entity now describes only the POST response."
```

---

## Task 11: Register the object graph and close the 401 loop

`AuthInterceptor.onUnauthorized` is constructed without its callback, so a 401 clears the token but nothing tells the router. Now that every screen makes guarded calls, that loop has to close.

**Files:**
- Modify: `mobile/lib/injection/dependency_injection.dart`
- Test: `mobile/test/injection/dependency_injection_test.dart` (create)

**Interfaces:**
- Consumes: everything from Tasks 8–10.
- Produces: `habitRemoteDataSourceProvider`, `habitRepositoryProvider`, `entryRemoteDataSourceProvider`, `entryRepositoryProvider`, `getDailyHabitsUseCaseProvider`, `createHabitUseCaseProvider`, `updateHabitUseCaseProvider`, `deleteHabitUseCaseProvider`, `setEntryUseCaseProvider`, `getEntriesUseCaseProvider`, and `sessionExpiredProvider` (`StateProvider<int>`, a counter the auth notifier watches).

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/injection/dependency_injection_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/entries/domain/repositories/entry_repository.dart';
import 'package:mobile/features/habits/domain/repositories/habit_repository.dart';
import 'package:mobile/features/habits/domain/usecases/create_habit.dart';
import 'package:mobile/features/habits/domain/usecases/get_daily_habits.dart';
import 'package:mobile/injection/dependency_injection.dart';

void main() {
  test('the habit and entry graph resolves without a network call', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(habitRepositoryProvider), isA<HabitRepository>());
    expect(container.read(entryRepositoryProvider), isA<EntryRepository>());
    expect(container.read(getDailyHabitsUseCaseProvider), isA<GetDailyHabits>());
    expect(container.read(createHabitUseCaseProvider), isA<CreateHabit>());
  });

  test('sessionExpiredProvider starts at zero', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(sessionExpiredProvider), 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/injection/dependency_injection_test.dart`
Expected: FAIL — none of the new providers exist.

- [ ] **Step 3: Add the providers**

Append to `mobile/lib/injection/dependency_injection.dart`, and add the imports for the habit and entry datasources, repositories and use cases:

```dart
// ---------------------------------------------------------------------------
// Session expiry
// ---------------------------------------------------------------------------

/// Bumped by [AuthInterceptor] when the backend rejects the bearer token.
///
/// A counter rather than a flag: two 401s in a row must both be observable,
/// and a counter is the simplest value that changes every time. `AuthNotifier`
/// listens and flips to unauthenticated, which the router picks up.
final sessionExpiredProvider = StateProvider<int>((ref) => 0);
```

Replace `apiClientProvider` so the interceptor gets its callback:

```dart
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    interceptors: [
      AuthInterceptor(
        secureStorage: ref.watch(secureStorageProvider),
        // Closes the loop the interceptor could not close on its own: it
        // clears the token, this tells the router.
        onUnauthorized: () => ref.read(sessionExpiredProvider.notifier).state++,
      ),
    ],
  );
});
```

Then append the feature providers:

```dart
// ---------------------------------------------------------------------------
// Feature: habits
// ---------------------------------------------------------------------------

final habitRemoteDataSourceProvider = Provider<HabitRemoteDataSource>(
  (ref) => HabitRemoteDataSourceImpl(ref.watch(apiClientProvider)),
);

final habitRepositoryProvider = Provider<HabitRepository>(
  (ref) => HabitRepositoryImpl(
    remoteDataSource: ref.watch(habitRemoteDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  ),
);

final getDailyHabitsUseCaseProvider = Provider<GetDailyHabits>(
  (ref) => GetDailyHabits(ref.watch(habitRepositoryProvider)),
);

final createHabitUseCaseProvider = Provider<CreateHabit>(
  (ref) => CreateHabit(ref.watch(habitRepositoryProvider)),
);

final updateHabitUseCaseProvider = Provider<UpdateHabit>(
  (ref) => UpdateHabit(ref.watch(habitRepositoryProvider)),
);

final deleteHabitUseCaseProvider = Provider<DeleteHabit>(
  (ref) => DeleteHabit(ref.watch(habitRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Feature: entries
// ---------------------------------------------------------------------------

final entryRemoteDataSourceProvider = Provider<EntryRemoteDataSource>(
  (ref) => EntryRemoteDataSourceImpl(ref.watch(apiClientProvider)),
);

final entryRepositoryProvider = Provider<EntryRepository>(
  (ref) => EntryRepositoryImpl(
    remoteDataSource: ref.watch(entryRemoteDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  ),
);

final setEntryUseCaseProvider = Provider<SetEntry>(
  (ref) => SetEntry(ref.watch(entryRepositoryProvider)),
);

final getEntriesUseCaseProvider = Provider<GetEntries>(
  (ref) => GetEntries(ref.watch(entryRepositoryProvider)),
);
```

- [ ] **Step 4: Have the auth notifier react to expiry**

In `mobile/lib/features/auth/presentation/providers/auth_provider.dart`, inside `AuthNotifier.build()`, before the `Future.microtask(restoreSession)` line:

```dart
    // A 401 on any guarded call means the session is gone. The interceptor has
    // already dropped the token; flipping status is what moves the router.
    ref.listen(sessionExpiredProvider, (previous, next) {
      if (previous == null || next == previous) return;
      state = const AuthState(status: AuthStatus.unauthenticated);
    });
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd mobile && flutter test test/injection/dependency_injection_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 6: Analyze and run the whole suite**

Run: `cd mobile && flutter analyze && flutter test`
Expected: no analyzer issues; every existing test still passes

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/injection/dependency_injection.dart mobile/lib/features/auth/presentation/providers/auth_provider.dart mobile/test/injection/dependency_injection_test.dart
git commit -m "feat(mobile): register the habit graph and route 401s to the router

AuthInterceptor.onUnauthorized was never supplied, so an expired token
was cleared but nothing told the router until the next getCurrentUser."
```

---
## Task 12: `dailyHabitsProvider`

The single source of truth for Today and My Habits. Toggling is optimistic: the checkbox flips before the request, and a failure reverts it.

**Files:**
- Create: `mobile/lib/features/habits/presentation/providers/daily_habits_provider.dart`
- Test: `mobile/test/features/habits/presentation/daily_habits_provider_test.dart`

**Interfaces:**
- Consumes: `getDailyHabitsUseCaseProvider`, `createHabitUseCaseProvider`, `updateHabitUseCaseProvider`, `deleteHabitUseCaseProvider`, `setEntryUseCaseProvider` (Task 11).
- Produces: `dailyHabitsProvider` — `AsyncNotifierProvider<DailyHabitsNotifier, List<DailyHabit>>`. Methods, all returning `Future<Failure?>` where `null` means success: `toggle(String habitId)`, `create({required String name, String? color})`, `rename(String habitId, String name)`, `recolor(String habitId, String color)`, `archive(String habitId)`, `remove(String habitId)`. Plus `Future<void> refresh()`.
- Also produces the derived read-only providers `todayCompletedCountProvider` (`int`) and `topStreakProvider` (`int`).

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/habits/presentation/daily_habits_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/failures.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/features/habits/domain/entities/daily_habit.dart';
import 'package:mobile/features/habits/presentation/providers/daily_habits_provider.dart';
import 'package:mobile/injection/dependency_injection.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockHabitRepository habits;
  late MockEntryRepository entries;

  setUpAll(registerFallbacks);

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        habitRepositoryProvider.overrideWithValue(habits),
        entryRepositoryProvider.overrideWithValue(entries),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    habits = MockHabitRepository();
    entries = MockEntryRepository();

    when(() => habits.getHabitsForDate(any())).thenAnswer(
      (_) async => Success([
        buildDailyHabit(
          habit: buildHabitModel(id: 'habit-1', name: 'Read'),
          doneToday: false,
          currentStreak: 2,
        ),
        buildDailyHabit(
          habit: buildHabitModel(id: 'habit-2', name: 'Stretch'),
          doneToday: true,
          currentStreak: 7,
        ),
      ]),
    );
  });

  test('loads the day on build', () async {
    final container = buildContainer();

    final list = await container.read(dailyHabitsProvider.future);

    expect(list, hasLength(2));
    expect(list.first.name, 'Read');
  });

  test('a load failure surfaces as an AsyncError', () async {
    when(() => habits.getHabitsForDate(any()))
        .thenAnswer((_) async => const ResultError(ServerFailure('boom')));
    final container = buildContainer();

    await expectLater(
      container.read(dailyHabitsProvider.future),
      throwsA(isA<ServerFailure>()),
    );
  });

  group('toggle', () {
    test('flips the habit and bumps the streak before the request returns',
        () async {
      when(() => entries.checkOff(
            habitId: any(named: 'habitId'),
            date: any(named: 'date'),
          )).thenAnswer((_) async => Success(buildHabitEntryModel()));
      final container = buildContainer();
      await container.read(dailyHabitsProvider.future);

      final failure = await container
          .read(dailyHabitsProvider.notifier)
          .toggle('habit-1');

      expect(failure, isNull);
      final updated = container.read(dailyHabitsProvider).requireValue;
      expect(updated.first.doneToday, isTrue);
      expect(updated.first.currentStreak, 3);
    });

    test('un-checking decrements the streak', () async {
      when(() => entries.deleteEntry(
            habitId: any(named: 'habitId'),
            date: any(named: 'date'),
          )).thenAnswer((_) async => const Success(null));
      final container = buildContainer();
      await container.read(dailyHabitsProvider.future);

      await container.read(dailyHabitsProvider.notifier).toggle('habit-2');

      final updated = container.read(dailyHabitsProvider).requireValue;
      expect(updated[1].doneToday, isFalse);
      expect(updated[1].currentStreak, 6);
    });

    test('rolls back and reports the failure when the request fails', () async {
      when(() => entries.checkOff(
            habitId: any(named: 'habitId'),
            date: any(named: 'date'),
          )).thenAnswer((_) async => const ResultError(ServerFailure('nope')));
      final container = buildContainer();
      await container.read(dailyHabitsProvider.future);

      final failure = await container
          .read(dailyHabitsProvider.notifier)
          .toggle('habit-1');

      expect(failure, isA<ServerFailure>());
      final restored = container.read(dailyHabitsProvider).requireValue;
      expect(restored.first.doneToday, isFalse);
      expect(restored.first.currentStreak, 2);
    });
  });

  group('mutations', () {
    test('create reloads the list', () async {
      when(() => habits.createHabit(
            name: any(named: 'name'),
            color: any(named: 'color'),
          )).thenAnswer((_) async => Success(buildHabitModel()));
      final container = buildContainer();
      await container.read(dailyHabitsProvider.future);

      final failure = await container
          .read(dailyHabitsProvider.notifier)
          .create(name: 'Walk', color: '#4D6054');

      expect(failure, isNull);
      verify(() => habits.getHabitsForDate(any())).called(2);
    });

    test('create reports a validation failure and does not reload', () async {
      final container = buildContainer();
      await container.read(dailyHabitsProvider.future);

      final failure =
          await container.read(dailyHabitsProvider.notifier).create(name: '  ');

      expect(failure, isA<ValidationFailure>());
      verify(() => habits.getHabitsForDate(any())).called(1);
    });

    test('remove drops the habit from the list immediately', () async {
      when(() => habits.deleteHabit(any()))
          .thenAnswer((_) async => const Success(null));
      final container = buildContainer();
      await container.read(dailyHabitsProvider.future);

      await container.read(dailyHabitsProvider.notifier).remove('habit-1');

      final remaining = container.read(dailyHabitsProvider).requireValue;
      expect(remaining.map((habit) => habit.id), ['habit-2']);
    });

    test('archive drops the habit from the active list', () async {
      when(() => habits.updateHabit(
            habitId: any(named: 'habitId'),
            name: any(named: 'name'),
            color: any(named: 'color'),
            archived: any(named: 'archived'),
          )).thenAnswer((_) async => Success(buildHabitModel()));
      final container = buildContainer();
      await container.read(dailyHabitsProvider.future);

      await container.read(dailyHabitsProvider.notifier).archive('habit-2');

      final remaining = container.read(dailyHabitsProvider).requireValue;
      expect(remaining.map((habit) => habit.id), ['habit-1']);
    });

    test('a failed remove puts the habit back', () async {
      when(() => habits.deleteHabit(any()))
          .thenAnswer((_) async => const ResultError(NetworkFailure()));
      final container = buildContainer();
      await container.read(dailyHabitsProvider.future);

      final failure =
          await container.read(dailyHabitsProvider.notifier).remove('habit-1');

      expect(failure, isA<NetworkFailure>());
      expect(container.read(dailyHabitsProvider).requireValue, hasLength(2));
    });
  });

  group('derived counts', () {
    test('counts completions and the top streak', () async {
      final container = buildContainer();
      await container.read(dailyHabitsProvider.future);

      expect(container.read(todayCompletedCountProvider), 1);
      expect(container.read(topStreakProvider), 7);
    });

    test('an empty list reads as zero, not an error', () async {
      when(() => habits.getHabitsForDate(any()))
          .thenAnswer((_) async => const Success(<DailyHabit>[]));
      final container = buildContainer();
      await container.read(dailyHabitsProvider.future);

      expect(container.read(todayCompletedCountProvider), 0);
      expect(container.read(topStreakProvider), 0);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/habits/presentation/daily_habits_provider_test.dart`
Expected: FAIL — `daily_habits_provider.dart` does not exist.

- [ ] **Step 3: Write the notifier**

```dart
// mobile/lib/features/habits/presentation/providers/daily_habits_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../injection/dependency_injection.dart';
import '../../domain/entities/daily_habit.dart';

/// Today's habits, and every mutation the two habit screens perform.
///
/// Today and My Habits read this one provider because they are two
/// presentations of one list, not two datasets.
///
/// Mutations return a `Failure?` rather than pushing an `AsyncError`: an
/// optimistic toggle that failed must show a message *and* keep the list on
/// screen, which a global error state cannot do.
class DailyHabitsNotifier extends AsyncNotifier<List<DailyHabit>> {
  @override
  Future<List<DailyHabit>> build() => _load();

  Future<List<DailyHabit>> _load() async {
    final result = await ref.read(getDailyHabitsUseCaseProvider)();
    return switch (result) {
      Success(:final data) => data,
      // Throwing hands the failure to AsyncValue.error, which is what the
      // error-with-retry widget renders.
      ResultError(:final failure) => throw failure,
    };
  }

  /// Re-reads the day from the server.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }

  /// Flips [habitId]'s check-off for today.
  ///
  /// The list updates first and the request follows. A check-off that waits on
  /// a round trip feels broken, and the call is idempotent, so the worst case
  /// is the rollback below.
  Future<Failure?> toggle(String habitId) async {
    final current = state.valueOrNull;
    if (current == null) return null;

    final habit = current.where((item) => item.id == habitId).firstOrNull;
    if (habit == null) return null;

    final completed = !habit.doneToday;
    state = AsyncValue.data(
      _replace(
        current,
        habitId,
        habit.copyWith(
          doneToday: completed,
          // The backend recomputes the real streak on the next read; this
          // keeps the number honest in the meantime.
          currentStreak: completed
              ? habit.currentStreak + 1
              : (habit.currentStreak - 1).clamp(0, 1 << 30),
        ),
      ),
    );

    final result = await ref.read(setEntryUseCaseProvider)(
      habitId: habitId,
      date: AppDateUtils.today,
      completed: completed,
    );

    if (result case ResultError(:final failure)) {
      state = AsyncValue.data(_replace(current, habitId, habit));
      return failure;
    }
    return null;
  }

  /// Creates a habit and reloads, so the new row arrives with its real id.
  Future<Failure?> create({required String name, String? color}) async {
    final result =
        await ref.read(createHabitUseCaseProvider)(name: name, color: color);
    if (result case ResultError(:final failure)) return failure;

    await refresh();
    return null;
  }

  Future<Failure?> rename(String habitId, String name) =>
      _patch(habitId, name: name);

  Future<Failure?> recolor(String habitId, String color) =>
      _patch(habitId, color: color);

  /// Archives the habit. It leaves the active list but its history survives.
  Future<Failure?> archive(String habitId) async {
    final current = state.valueOrNull;
    if (current == null) return null;

    state = AsyncValue.data(_without(current, habitId));

    final result = await ref.read(updateHabitUseCaseProvider)(
      habitId: habitId,
      archived: true,
    );

    if (result case ResultError(:final failure)) {
      state = AsyncValue.data(current);
      return failure;
    }
    return null;
  }

  /// Deletes the habit and, by cascade, every entry it has.
  Future<Failure?> remove(String habitId) async {
    final current = state.valueOrNull;
    if (current == null) return null;

    state = AsyncValue.data(_without(current, habitId));

    final result = await ref.read(deleteHabitUseCaseProvider)(habitId);

    if (result case ResultError(:final failure)) {
      state = AsyncValue.data(current);
      return failure;
    }
    return null;
  }

  /// Shared body of [rename] and [recolor]: patch, then reload so the list
  /// shows exactly what the server stored.
  Future<Failure?> _patch(String habitId, {String? name, String? color}) async {
    final result = await ref.read(updateHabitUseCaseProvider)(
      habitId: habitId,
      name: name,
      color: color,
    );
    if (result case ResultError(:final failure)) return failure;

    await refresh();
    return null;
  }

  List<DailyHabit> _replace(
    List<DailyHabit> list,
    String habitId,
    DailyHabit replacement,
  ) {
    return [
      for (final item in list) item.id == habitId ? replacement : item,
    ];
  }

  List<DailyHabit> _without(List<DailyHabit> list, String habitId) =>
      [for (final item in list) if (item.id != habitId) item];
}

final dailyHabitsProvider =
    AsyncNotifierProvider<DailyHabitsNotifier, List<DailyHabit>>(
  DailyHabitsNotifier.new,
);

/// How many of today's habits are checked off. Zero while loading or on error.
final todayCompletedCountProvider = Provider<int>((ref) {
  final habits = ref.watch(dailyHabitsProvider).valueOrNull ?? const [];
  return habits.where((habit) => habit.doneToday).length;
});

/// The longest streak currently running across all habits.
final topStreakProvider = Provider<int>((ref) {
  final habits = ref.watch(dailyHabitsProvider).valueOrNull ?? const [];
  return habits.fold(0, (best, habit) => 
      habit.currentStreak > best ? habit.currentStreak : best);
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/habits/presentation/daily_habits_provider_test.dart`
Expected: PASS (12 tests)

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/habits/presentation/providers/ mobile/test/features/habits/presentation/daily_habits_provider_test.dart
git commit -m "feat(mobile): add dailyHabitsProvider with optimistic check-off

Mutations return Failure? rather than pushing an AsyncError, so a failed
toggle can roll back and still show the list."
```

---

## Task 13: `InsightsCalculator`

All the history maths, in one pure class with no Riverpod and no Dio, so every rule is testable without a widget tree.

**Files:**
- Create: `mobile/lib/features/insights/domain/entities/insights_summary.dart`
- Create: `mobile/lib/features/insights/domain/insights_calculator.dart`
- Test: `mobile/test/features/insights/domain/insights_calculator_test.dart`

**Interfaces:**
- Consumes: `Habit`, `AppDateUtils`.
- Produces:
  - `class HabitConsistency { final Habit habit; final double rate; }` — `rate` is 0.0–1.0.
  - `class InsightsSummary { final int currentStreak; final int bestStreak; final double consistency; final List<double> dailyCompletion; final List<HabitConsistency> habitConsistency; final int habitCount; }`, plus `static const InsightsSummary empty`.
  - `abstract final class InsightsCalculator` with `static InsightsSummary compute({required List<Habit> habits, required Map<String, List<DateTime>> entriesByHabit, required DateTime from, required DateTime to})`.

**Rules, stated once so the tests and the code agree:**
- A habit only counts on days on or after its `createdAt` day. A habit created yesterday must not drag last month's consistency down.
- `dailyCompletion[i]` is completed-due ÷ due for day `from + i`. A day with nothing due is `0.0`.
- `consistency` is the mean of `dailyCompletion` over days that had something due; `0.0` if no day did.
- `currentStreak` is the longest run of consecutive completed days ending at `to`, across all habits.
- `bestStreak` is the longest run anywhere in the window, across all habits.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/insights/domain/insights_calculator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/insights/domain/insights_calculator.dart';

import '../../../helpers/mocks.dart';

void main() {
  final from = DateTime(2026, 3, 4);
  final to = DateTime(2026, 3, 10);

  final read = buildHabitModel(
    id: 'habit-1',
    name: 'Read',
    createdAt: DateTime(2026, 1, 1),
  );
  final stretch = buildHabitModel(
    id: 'habit-2',
    name: 'Stretch',
    createdAt: DateTime(2026, 1, 1),
  );

  test('no habits reads as empty rather than dividing by zero', () {
    final summary = InsightsCalculator.compute(
      habits: const [],
      entriesByHabit: const {},
      from: from,
      to: to,
    );

    expect(summary.consistency, 0.0);
    expect(summary.currentStreak, 0);
    expect(summary.bestStreak, 0);
    expect(summary.habitCount, 0);
    expect(summary.dailyCompletion, hasLength(7));
    expect(summary.dailyCompletion.every((value) => value == 0.0), isTrue);
  });

  test('a perfect week is 100% consistent with a full streak', () {
    final everyDay = [
      for (var day = 0; day < 7; day++) from.add(Duration(days: day)),
    ];

    final summary = InsightsCalculator.compute(
      habits: [read],
      entriesByHabit: {'habit-1': everyDay},
      from: from,
      to: to,
    );

    expect(summary.consistency, 1.0);
    expect(summary.currentStreak, 7);
    expect(summary.bestStreak, 7);
    expect(summary.dailyCompletion, everyElement(1.0));
  });

  test('a gap ends the current streak but not the best one', () {
    final summary = InsightsCalculator.compute(
      habits: [read],
      entriesByHabit: {
        'habit-1': [
          DateTime(2026, 3, 4),
          DateTime(2026, 3, 5),
          DateTime(2026, 3, 6),
          DateTime(2026, 3, 7),
          // 8 March missed
          DateTime(2026, 3, 9),
        ],
      },
      from: from,
      to: to,
    );

    expect(summary.currentStreak, 0, reason: '10 March is not completed');
    expect(summary.bestStreak, 4);
  });

  test('a streak running up to the last day is the current streak', () {
    final summary = InsightsCalculator.compute(
      habits: [read],
      entriesByHabit: {
        'habit-1': [DateTime(2026, 3, 9), DateTime(2026, 3, 10)],
      },
      from: from,
      to: to,
    );

    expect(summary.currentStreak, 2);
    expect(summary.bestStreak, 2);
  });

  test('two habits average into the daily completion rate', () {
    final summary = InsightsCalculator.compute(
      habits: [read, stretch],
      entriesByHabit: {
        'habit-1': [DateTime(2026, 3, 10)],
        'habit-2': const [],
      },
      from: from,
      to: to,
    );

    expect(summary.dailyCompletion.last, 0.5);
    expect(summary.habitCount, 2);
  });

  test('a habit is not counted on days before it existed', () {
    final newHabit = buildHabitModel(
      id: 'habit-3',
      name: 'Walk',
      createdAt: DateTime(2026, 3, 10),
    );

    final summary = InsightsCalculator.compute(
      habits: [read, newHabit],
      entriesByHabit: {
        'habit-1': [for (var day = 0; day < 7; day++) from.add(Duration(days: day))],
        'habit-3': [DateTime(2026, 3, 10)],
      },
      from: from,
      to: to,
    );

    // Every day is 100%: Read was due and done throughout, and Walk was only
    // due on the 10th, when it was done.
    expect(summary.dailyCompletion, everyElement(1.0));
    expect(summary.consistency, 1.0);
  });

  test('per-habit consistency is measured over the days each was due', () {
    final newHabit = buildHabitModel(
      id: 'habit-3',
      name: 'Walk',
      createdAt: DateTime(2026, 3, 9),
    );

    final summary = InsightsCalculator.compute(
      habits: [read, newHabit],
      entriesByHabit: {
        'habit-1': [DateTime(2026, 3, 10)],
        'habit-3': [DateTime(2026, 3, 9)],
      },
      from: from,
      to: to,
    );

    final byName = {
      for (final item in summary.habitConsistency) item.habit.name: item.rate,
    };

    expect(byName['Read'], closeTo(1 / 7, 0.001));
    // Walk existed for the 9th and 10th and was done on one of them.
    expect(byName['Walk'], closeTo(0.5, 0.001));
  });

  test('habit consistency is sorted strongest first', () {
    final summary = InsightsCalculator.compute(
      habits: [read, stretch],
      entriesByHabit: {
        'habit-1': const [],
        'habit-2': [for (var day = 0; day < 7; day++) from.add(Duration(days: day))],
      },
      from: from,
      to: to,
    );

    expect(summary.habitConsistency.first.habit.name, 'Stretch');
    expect(summary.habitConsistency.last.habit.name, 'Read');
  });

  test('entries outside the window are ignored', () {
    final summary = InsightsCalculator.compute(
      habits: [read],
      entriesByHabit: {
        'habit-1': [DateTime(2026, 2, 1), DateTime(2026, 12, 25)],
      },
      from: from,
      to: to,
    );

    expect(summary.consistency, 0.0);
    expect(summary.bestStreak, 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/insights/domain/insights_calculator_test.dart`
Expected: FAIL — the calculator does not exist.

- [ ] **Step 3: Write the summary entity**

```dart
// mobile/lib/features/insights/domain/entities/insights_summary.dart
import '../../../habits/domain/entities/habit.dart';

/// How reliably one habit was kept over the window.
class HabitConsistency {
  const HabitConsistency({required this.habit, required this.rate});

  final Habit habit;

  /// Completed days divided by the days the habit existed, 0.0–1.0.
  final double rate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitConsistency && habit == other.habit && rate == other.rate;

  @override
  int get hashCode => Object.hash(habit, rate);
}

/// Everything the Insights screen and the Profile stat row display.
///
/// Computed on the client from entry history, because the API has no aggregate
/// endpoint.
class InsightsSummary {
  const InsightsSummary({
    required this.currentStreak,
    required this.bestStreak,
    required this.consistency,
    required this.dailyCompletion,
    required this.habitConsistency,
    required this.habitCount,
  });

  /// Nothing tracked yet — what the screens render before the first habit.
  static const InsightsSummary empty = InsightsSummary(
    currentStreak: 0,
    bestStreak: 0,
    consistency: 0,
    dailyCompletion: [],
    habitConsistency: [],
    habitCount: 0,
  );

  /// The longest run of consecutive completed days ending at the window's last
  /// day, across all habits.
  final int currentStreak;

  /// The longest run anywhere in the window, across all habits.
  final int bestStreak;

  /// Mean daily completion over the days something was due, 0.0–1.0.
  final double consistency;

  /// Completion rate per day, oldest first, one entry per day in the window.
  final List<double> dailyCompletion;

  /// Per-habit rates, strongest first.
  final List<HabitConsistency> habitConsistency;

  final int habitCount;

  /// [consistency] as a whole percentage, for display.
  int get consistencyPercent => (consistency * 100).round();
}
```

- [ ] **Step 4: Write the calculator**

```dart
// mobile/lib/features/insights/domain/insights_calculator.dart
import '../../../core/utils/date_utils.dart';
import '../../habits/domain/entities/habit.dart';
import 'entities/insights_summary.dart';

/// Turns raw entry history into the numbers the Insights and Profile screens
/// show.
///
/// Deliberately pure — no Riverpod, no Dio, no `DateTime.now()`. Every rule
/// below is testable by calling one function with plain lists.
abstract final class InsightsCalculator {
  static InsightsSummary compute({
    required List<Habit> habits,
    required Map<String, List<DateTime>> entriesByHabit,
    required DateTime from,
    required DateTime to,
  }) {
    final days = _daysBetween(from, to);
    if (habits.isEmpty) {
      return InsightsSummary(
        currentStreak: 0,
        bestStreak: 0,
        consistency: 0,
        dailyCompletion: List<double>.filled(days.length, 0),
        habitConsistency: const [],
        habitCount: 0,
      );
    }

    // Day keys, so an entry is a set lookup rather than a list scan per day.
    final completedByHabit = <String, Set<DateTime>>{
      for (final habit in habits)
        habit.id: {
          for (final date in entriesByHabit[habit.id] ?? const <DateTime>[])
            AppDateUtils.dateOnly(date),
        },
    };

    final dailyCompletion = <double>[];
    final dueDayCounts = <String, int>{for (final habit in habits) habit.id: 0};
    final doneDayCounts = <String, int>{for (final habit in habits) habit.id: 0};
    // A day counts toward a streak only if everything due that day was done.
    final perfectDays = <bool>[];

    for (final day in days) {
      var due = 0;
      var done = 0;

      for (final habit in habits) {
        // A habit created yesterday must not be marked absent for last month.
        if (AppDateUtils.dateOnly(habit.createdAt).isAfter(day)) continue;

        due++;
        dueDayCounts[habit.id] = dueDayCounts[habit.id]! + 1;

        if (completedByHabit[habit.id]!.contains(day)) {
          done++;
          doneDayCounts[habit.id] = doneDayCounts[habit.id]! + 1;
        }
      }

      dailyCompletion.add(due == 0 ? 0 : done / due);
      perfectDays.add(due > 0 && done == due);
    }

    final scoredDays = <double>[
      for (var index = 0; index < days.length; index++)
        if (_hadSomethingDue(habits, days[index])) dailyCompletion[index],
    ];

    final habitConsistency = <HabitConsistency>[
      for (final habit in habits)
        HabitConsistency(
          habit: habit,
          rate: dueDayCounts[habit.id]! == 0
              ? 0
              : doneDayCounts[habit.id]! / dueDayCounts[habit.id]!,
        ),
    ]..sort((a, b) => b.rate.compareTo(a.rate));

    return InsightsSummary(
      currentStreak: _trailingRun(perfectDays),
      bestStreak: _longestRun(perfectDays),
      consistency: scoredDays.isEmpty
          ? 0
          : scoredDays.reduce((a, b) => a + b) / scoredDays.length,
      dailyCompletion: dailyCompletion,
      habitConsistency: habitConsistency,
      habitCount: habits.length,
    );
  }

  static bool _hadSomethingDue(List<Habit> habits, DateTime day) => habits.any(
        (habit) => !AppDateUtils.dateOnly(habit.createdAt).isAfter(day),
      );

  static List<DateTime> _daysBetween(DateTime from, DateTime to) {
    final start = AppDateUtils.dateOnly(from);
    final count = AppDateUtils.daysBetween(from, to) + 1;
    return [
      for (var index = 0; index < count; index++)
        start.add(Duration(days: index)),
    ];
  }

  /// Length of the run of `true` ending at the last element.
  static int _trailingRun(List<bool> flags) {
    var run = 0;
    for (var index = flags.length - 1; index >= 0; index--) {
      if (!flags[index]) break;
      run++;
    }
    return run;
  }

  /// Length of the longest run of `true` anywhere.
  static int _longestRun(List<bool> flags) {
    var best = 0;
    var run = 0;
    for (final flag in flags) {
      run = flag ? run + 1 : 0;
      if (run > best) best = run;
    }
    return best;
  }
}
```

> The `start.add(Duration(days: index))` above crosses DST boundaries in some
> zones. If the test `a perfect week is 100% consistent` fails with an
> off-by-one day count in a DST zone, replace the body of `_daysBetween` with
> `DateTime(start.year, start.month, start.day + index)`, which normalises.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/insights/domain/insights_calculator_test.dart`
Expected: PASS (9 tests)

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/features/insights/domain/ mobile/test/features/insights/domain/
git commit -m "feat(mobile): add the pure InsightsCalculator

All history maths in one class with no Riverpod or Dio, so the rules are
testable by calling one function with plain lists."
```

---

## Task 14: `insightsProvider`

Fetches the 30-day window — habits once, then entries per habit in parallel — and hands it to the calculator.

**Files:**
- Create: `mobile/lib/features/insights/presentation/providers/insights_provider.dart`
- Test: `mobile/test/features/insights/presentation/insights_provider_test.dart`

**Interfaces:**
- Consumes: `habitRepositoryProvider`, `getEntriesUseCaseProvider`, `dailyHabitsProvider` (for invalidation), `InsightsCalculator`.
- Produces: `insightsProvider` — `AsyncNotifierProvider<InsightsNotifier, InsightsSummary>` with `Future<void> refresh()`. Also `const int insightsWindowDays = 30`.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/insights/presentation/insights_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/failures.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/core/utils/date_utils.dart';
import 'package:mobile/features/habits/domain/entities/habit.dart';
import 'package:mobile/features/insights/presentation/providers/insights_provider.dart';
import 'package:mobile/injection/dependency_injection.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockHabitRepository habits;
  late MockEntryRepository entries;

  setUpAll(registerFallbacks);

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        habitRepositoryProvider.overrideWithValue(habits),
        entryRepositoryProvider.overrideWithValue(entries),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    habits = MockHabitRepository();
    entries = MockEntryRepository();

    when(() => habits.getHabits()).thenAnswer(
      (_) async => Success<List<Habit>>([
        buildHabitModel(id: 'habit-1', name: 'Read', createdAt: DateTime(2026, 1, 1)),
        buildHabitModel(id: 'habit-2', name: 'Stretch', createdAt: DateTime(2026, 1, 1)),
      ]),
    );
    when(() => entries.getEntries(
          habitId: any(named: 'habitId'),
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).thenAnswer((_) async => Success([AppDateUtils.today]));
  });

  test('fetches every habit\'s entries and summarises them', () async {
    final container = buildContainer();

    final summary = await container.read(insightsProvider.future);

    expect(summary.habitCount, 2);
    expect(summary.currentStreak, 1);
    verify(() => entries.getEntries(
          habitId: 'habit-1',
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).called(1);
    verify(() => entries.getEntries(
          habitId: 'habit-2',
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).called(1);
  });

  test('requests exactly the configured window', () async {
    final container = buildContainer();
    await container.read(insightsProvider.future);

    final captured = verify(() => entries.getEntries(
          habitId: 'habit-1',
          from: captureAny(named: 'from'),
          to: captureAny(named: 'to'),
        )).captured;

    expect(
      AppDateUtils.daysBetween(captured[0] as DateTime, captured[1] as DateTime),
      insightsWindowDays - 1,
    );
  });

  test('no habits yields the empty summary without fetching entries', () async {
    when(() => habits.getHabits())
        .thenAnswer((_) async => const Success(<Habit>[]));
    final container = buildContainer();

    final summary = await container.read(insightsProvider.future);

    expect(summary.habitCount, 0);
    verifyNever(() => entries.getEntries(
          habitId: any(named: 'habitId'),
          from: any(named: 'from'),
          to: any(named: 'to'),
        ));
  });

  test('a failed habit load surfaces as an AsyncError', () async {
    when(() => habits.getHabits())
        .thenAnswer((_) async => const ResultError(NetworkFailure()));
    final container = buildContainer();

    await expectLater(
      container.read(insightsProvider.future),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('one habit failing to load entries does not sink the whole summary',
      () async {
    when(() => entries.getEntries(
          habitId: 'habit-2',
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).thenAnswer((_) async => const ResultError(ServerFailure('boom')));
    final container = buildContainer();

    final summary = await container.read(insightsProvider.future);

    expect(summary.habitCount, 2);
    final stretch = summary.habitConsistency
        .firstWhere((item) => item.habit.name == 'Stretch');
    expect(stretch.rate, 0.0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/insights/presentation/insights_provider_test.dart`
Expected: FAIL — the provider does not exist.

- [ ] **Step 3: Write the notifier**

```dart
// mobile/lib/features/insights/presentation/providers/insights_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../injection/dependency_injection.dart';
import '../../../habits/domain/entities/habit.dart';
import '../../../habits/presentation/providers/daily_habits_provider.dart';
import '../../domain/entities/insights_summary.dart';
import '../../domain/insights_calculator.dart';

/// How far back the Insights screen looks.
const int insightsWindowDays = 30;

/// The history summary behind Insights and the Profile stat row.
///
/// The API has no aggregate endpoint, so this fetches the habits once and then
/// each habit's entries in parallel. N+1 requests, which is acceptable at
/// personal-habit scale and cached here for the lifetime of the screen.
class InsightsNotifier extends AsyncNotifier<InsightsSummary> {
  @override
  Future<InsightsSummary> build() {
    // Any check-off changes the history, so recompute when the list mutates.
    ref.watch(dailyHabitsProvider);
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }

  Future<InsightsSummary> _load() async {
    final habitsResult = await ref.read(habitRepositoryProvider).getHabits();

    final habits = switch (habitsResult) {
      Success(:final data) => data,
      ResultError(:final failure) => throw failure,
    };

    if (habits.isEmpty) return InsightsSummary.empty;

    final to = AppDateUtils.today;
    final from = to.subtract(const Duration(days: insightsWindowDays - 1));

    final getEntries = ref.read(getEntriesUseCaseProvider);
    final results = await Future.wait([
      for (final habit in habits)
        getEntries(habitId: habit.id, from: from, to: to),
    ]);

    final entriesByHabit = <String, List<DateTime>>{
      for (var index = 0; index < habits.length; index++)
        // One habit failing is not worth losing the whole screen over; it
        // simply reads as no completions.
        habits[index].id: results[index].dataOrNull ?? const <DateTime>[],
    };

    return InsightsCalculator.compute(
      habits: habits,
      entriesByHabit: entriesByHabit,
      from: from,
      to: to,
    );
  }
}

final insightsProvider =
    AsyncNotifierProvider<InsightsNotifier, InsightsSummary>(
  InsightsNotifier.new,
);
```

> `List<Habit>` is needed above rather than the inferred `List<HabitModel>`;
> if the analyzer complains at the `Future.wait` line, annotate the local as
> `final List<Habit> habits = ...`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/insights/presentation/insights_provider_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/insights/presentation/providers/ mobile/test/features/insights/presentation/insights_provider_test.dart
git commit -m "feat(mobile): add insightsProvider over a 30-day window"
```

---
## Task 15: Today reads real habits

**Files:**
- Modify: `mobile/lib/features/habits/presentation/pages/today_page.dart`
- Create: `mobile/lib/features/habits/presentation/widgets/habit_check_card.dart`
- Create: `mobile/lib/features/habits/presentation/widgets/habit_color.dart`
- Rewrite: `mobile/test/features/habits/presentation/today_page_test.dart`

**Interfaces:**
- Consumes: `dailyHabitsProvider`, `todayCompletedCountProvider`, `topStreakProvider` (Task 12); `AppLoading`, `AppError` from `core/widgets`.
- Produces: `HabitCheckCard({required DailyHabit habit, required VoidCallback onToggle})`, and `abstract final class HabitColors { static Color parse(String? hex); static const List<String> palette; }` — shared with Tasks 16 and 17.

**What is removed:** `_waterDrankLiters`, `_waterGoalLiters`, `_exerciseCompleted`, `_meditateCompleted`, `_readCompleted`, `_totalHabits`, `_completedCount`, `_addWater`, `_WaterHabitCard`, and the four hardcoded `_ToggleHabitCard` instances. **What stays:** the app bar, the greeting, the progress-ring and streak cards, the quote cycler, and `_ToggleHabitCard`'s visual design — which becomes `HabitCheckCard`.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/habits/presentation/today_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/failures.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/core/widgets/app_error.dart';
import 'package:mobile/features/habits/domain/entities/daily_habit.dart';
import 'package:mobile/features/habits/presentation/pages/today_page.dart';
import 'package:mobile/injection/dependency_injection.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';
import '../../../helpers/pump_app.dart';

void main() {
  late MockHabitRepository habits;
  late MockEntryRepository entries;

  setUpAll(registerFallbacks);

  setUp(() {
    habits = MockHabitRepository();
    entries = MockEntryRepository();
    when(() => entries.checkOff(
          habitId: any(named: 'habitId'),
          date: any(named: 'date'),
        )).thenAnswer((_) async => Success(buildHabitEntryModel()));
  });

  List<Override> overrides() => [
        ...signedOutOverrides(),
        habitRepositoryProvider.overrideWithValue(habits),
        entryRepositoryProvider.overrideWithValue(entries),
      ];

  testWidgets('renders the habits the API returned', (tester) async {
    when(() => habits.getHabitsForDate(any())).thenAnswer(
      (_) async => Success([
        buildDailyHabit(
          habit: buildHabitModel(id: 'habit-1', name: 'Read'),
          currentStreak: 3,
        ),
        buildDailyHabit(
          habit: buildHabitModel(id: 'habit-2', name: 'Stretch'),
          doneToday: true,
          currentStreak: 9,
        ),
      ]),
    );

    await pumpApp(tester, const TodayPage(), overrides: overrides());

    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Stretch'), findsOneWidget);
    // The old hardcoded demo habits are gone.
    expect(find.text('Drink enough water'), findsNothing);
    expect(find.text('Morning exercise'), findsNothing);
  });

  testWidgets('the ring counts completions and the badge shows the top streak',
      (tester) async {
    when(() => habits.getHabitsForDate(any())).thenAnswer(
      (_) async => Success([
        buildDailyHabit(habit: buildHabitModel(id: 'habit-1', name: 'Read')),
        buildDailyHabit(
          habit: buildHabitModel(id: 'habit-2', name: 'Stretch'),
          doneToday: true,
          currentStreak: 9,
        ),
      ]),
    );

    await pumpApp(tester, const TodayPage(), overrides: overrides());

    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    // The hardcoded 12-day streak is gone.
    expect(find.text('12'), findsNothing);
  });

  testWidgets('tapping a habit checks it off optimistically', (tester) async {
    when(() => habits.getHabitsForDate(any())).thenAnswer(
      (_) async => Success([
        buildDailyHabit(habit: buildHabitModel(id: 'habit-1', name: 'Read')),
      ]),
    );

    await pumpApp(tester, const TodayPage(), overrides: overrides());
    expect(find.text('0/1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('habit-toggle-habit-1')));
    await tester.pumpAndSettle();

    expect(find.text('1/1'), findsOneWidget);
    verify(() => entries.checkOff(habitId: 'habit-1', date: any(named: 'date')))
        .called(1);
  });

  testWidgets('a failed toggle reverts and shows a message', (tester) async {
    when(() => habits.getHabitsForDate(any())).thenAnswer(
      (_) async => Success([
        buildDailyHabit(habit: buildHabitModel(id: 'habit-1', name: 'Read')),
      ]),
    );
    when(() => entries.checkOff(
          habitId: any(named: 'habitId'),
          date: any(named: 'date'),
        )).thenAnswer((_) async => const ResultError(NetworkFailure()));

    await pumpApp(tester, const TodayPage(), overrides: overrides());
    await tester.tap(find.byKey(const ValueKey('habit-toggle-habit-1')));
    await tester.pumpAndSettle();

    expect(find.text('0/1'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no habits yet',
      (tester) async {
    when(() => habits.getHabitsForDate(any()))
        .thenAnswer((_) async => const Success(<DailyHabit>[]));

    await pumpApp(tester, const TodayPage(), overrides: overrides());

    expect(find.text('No habits yet'), findsOneWidget);
  });

  testWidgets('shows a retryable error when the load fails', (tester) async {
    when(() => habits.getHabitsForDate(any()))
        .thenAnswer((_) async => const ResultError(NetworkFailure()));

    await pumpApp(tester, const TodayPage(), overrides: overrides());

    expect(find.byType(AppError), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/habits/presentation/today_page_test.dart`
Expected: FAIL — the page still renders the four demo habits.

- [ ] **Step 3: Write the shared colour helper**

```dart
// mobile/lib/features/habits/presentation/widgets/habit_color.dart
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Turns the backend's optional hex string into a [Color].
///
/// `Habit.color` is nullable and only loosely validated server-side, so an
/// unparseable value falls back to the theme rather than throwing in a build.
abstract final class HabitColors {
  /// The colours Add Habit offers. All six-digit hex, which is what
  /// `@IsHexColor()` accepts.
  static const List<String> palette = [
    '#4D6054',
    '#8A9A5B',
    '#B5C4A1',
    '#C77D52',
    '#7D8CA3',
    '#A8756B',
  ];

  static Color parse(String? hex) {
    if (hex == null) return AppColors.primary;

    final digits = hex.replaceFirst('#', '');
    final normalised = switch (digits.length) {
      3 => digits.split('').map((char) => '$char$char').join(),
      6 => digits,
      _ => null,
    };
    if (normalised == null) return AppColors.primary;

    final value = int.tryParse(normalised, radix: 16);
    return value == null ? AppColors.primary : Color(0xFF000000 | value);
  }

  /// A readable foreground for [background].
  static Color onColor(Color background) =>
      background.computeLuminance() > 0.55
          ? AppColors.onSurface
          : Colors.white;
}
```

- [ ] **Step 4: Write the habit card**

Lift the visual design of the existing `_ToggleHabitCard` in `today_page.dart` into this file — same `AnimatedContainer`, padding, radius, shadow, strikethrough and check-circle — driven by a `DailyHabit` instead of loose parameters. The subtitle becomes the streak rather than a hardcoded duration.

```dart
// mobile/lib/features/habits/presentation/widgets/habit_check_card.dart
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/entities/daily_habit.dart';
import 'habit_color.dart';

/// One habit on Today, with its check-off control.
///
/// The card is the whole tap target — the circle is a visual affordance, not a
/// separate one, which makes a check-off much easier to hit.
class HabitCheckCard extends StatelessWidget {
  const HabitCheckCard({
    super.key,
    required this.habit,
    required this.onToggle,
  });

  final DailyHabit habit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final done = habit.doneToday;
    final accent = HabitColors.parse(habit.color);

    return Semantics(
      button: true,
      checked: done,
      label: habit.name,
      child: InkWell(
        key: ValueKey('habit-toggle-${habit.id}'),
        onTap: onToggle,
        borderRadius: AppSpacing.borderRadiusCard,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardPadding,
            vertical: 16,
          ),
          decoration: BoxDecoration(
            color: done ? AppColors.primaryContainer : AppColors.surfaceContainer,
            borderRadius: AppSpacing.borderRadiusCard,
            boxShadow: AppSpacing.ambientShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? AppColors.onPrimaryContainer.withValues(alpha: 0.2)
                      : accent.withValues(alpha: 0.18),
                ),
                child: Icon(
                  Icons.eco_rounded,
                  color: done ? AppColors.onPrimaryContainer : accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: AppTypography.bodyLarge.copyWith(
                        color: done
                            ? AppColors.onPrimaryContainer
                            : AppColors.onSurface,
                        fontWeight: FontWeight.w600,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _streakLabel(habit.currentStreak),
                      style: AppTypography.labelSmall.copyWith(
                        color: done
                            ? AppColors.onPrimaryContainer.withValues(alpha: 0.75)
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? AppColors.onPrimaryContainer : Colors.transparent,
                  border: Border.all(
                    color: done ? Colors.transparent : AppColors.outlineVariant,
                    width: 2,
                  ),
                ),
                child: done
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.primary, size: 20)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _streakLabel(int streak) => switch (streak) {
        0 => 'Not started',
        1 => '1 day streak',
        _ => '$streak day streak',
      };
}
```

- [ ] **Step 5: Rewire the page**

In `today_page.dart`: delete the five demo state fields, `_addWater`, `_totalHabits`, `_completedCount`, `_WaterHabitCard` and `_ToggleHabitCard`. Keep `_quotes`, `_quoteIndex`, `_showMotivation`, `_cycleQuote` and `_formattedDate`. Add the imports for `dailyHabitsProvider`, `HabitCheckCard`, `AppError` and `AppLoading`, then:

Replace the ring's `value:` and label with the provider-derived counts:

```dart
    final habitsAsync = ref.watch(dailyHabitsProvider);
    final total = habitsAsync.valueOrNull?.length ?? 0;
    final completed = ref.watch(todayCompletedCountProvider);
    final topStreak = ref.watch(topStreakProvider);
```

```dart
                                  CircularProgressIndicator(
                                    value: total == 0 ? 0 : completed / total,
                                    strokeWidth: 7,
                                    backgroundColor: AppColors.surfaceVariant,
                                    color: AppColors.primary,
                                    strokeCap: StrokeCap.round,
                                  ),
                                  Text(
                                    '$completed/$total',
                                    style: AppTypography.headlineSmall.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
```

Replace the hardcoded `'12'` in the streak badge with `'$topStreak'`.

Replace the whole `SliverPadding` holding the four demo cards with:

```dart
            // Daily habits, from GET /habits?date=today
            switch (habitsAsync) {
              AsyncError(:final error) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppError(
                    message: error is Failure
                        ? error.message
                        : 'Could not load your habits.',
                    onRetry: () =>
                        ref.read(dailyHabitsProvider.notifier).refresh(),
                  ),
                ),
              AsyncData(:final value) when value.isEmpty =>
                const SliverToBoxAdapter(child: _EmptyHabits()),
              AsyncData(:final value) => SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.containerMargin,
                  ),
                  sliver: SliverList.separated(
                    itemCount: value.length + 1,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.stackGap),
                    itemBuilder: (context, index) {
                      // Trailing spacer clears the floating nav dock.
                      if (index == value.length) {
                        return const SizedBox(height: 110);
                      }
                      final habit = value[index];
                      return HabitCheckCard(
                        habit: habit,
                        onToggle: () => _toggle(habit.id),
                      );
                    },
                  ),
                ),
              _ => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: AppLoading(),
                  ),
                ),
            },
```

Add the toggle handler and the empty state to the file:

```dart
  Future<void> _toggle(String habitId) async {
    final failure =
        await ref.read(dailyHabitsProvider.notifier).toggle(habitId);
    if (failure == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failure.message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
```

```dart
class _EmptyHabits extends StatelessWidget {
  const _EmptyHabits();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.containerMargin,
        vertical: 40,
      ),
      child: Column(
        children: [
          const Icon(Icons.spa_outlined, size: 44, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            'No habits yet',
            style: AppTypography.headlineSmall
                .copyWith(color: AppColors.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            'Plant your first one and it will show up here every day.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
```

Import `Failure` from `core/errors/failures.dart` for the `AsyncError` branch.

- [ ] **Step 6: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/habits/presentation/today_page_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/features/habits/presentation/ mobile/test/features/habits/presentation/today_page_test.dart
git commit -m "feat(mobile): drive Today from the habits API

Replaces the four demo habits and the hardcoded 12-day streak with the
real list, real check-offs, and loading/empty/error states."
```

---

## Task 16: Routines becomes My Habits

**Files:**
- Create: `mobile/lib/features/habits/presentation/pages/my_habits_page.dart`
- Delete: `mobile/lib/features/habits/presentation/pages/routines_page.dart`
- Modify: `mobile/lib/app/router/app_router.dart:103`, `mobile/lib/app/shell/main_shell_scaffold.dart:106`
- Delete: `mobile/test/features/habits/presentation/routines_page_test.dart`
- Create: `mobile/test/features/habits/presentation/my_habits_page_test.dart`

**Interfaces:**
- Consumes: `dailyHabitsProvider`, `HabitColors` (Tasks 12, 15).
- Produces: `MyHabitsPage` — a `ConsumerWidget`. The route name `RouteNames.habits` and path `/habits` are unchanged; only the builder and the nav label change.

**Rules:** each row shows the name, a colour dot and the current streak. An overflow menu offers Rename, Change colour, Archive and Delete. Delete asks for confirmation first — it cascades to every entry and cannot be undone; archive does not, because it is reversible.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/habits/presentation/my_habits_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/features/habits/domain/entities/daily_habit.dart';
import 'package:mobile/features/habits/presentation/pages/my_habits_page.dart';
import 'package:mobile/injection/dependency_injection.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';
import '../../../helpers/pump_app.dart';

void main() {
  late MockHabitRepository habits;
  late MockEntryRepository entries;

  setUpAll(registerFallbacks);

  setUp(() {
    habits = MockHabitRepository();
    entries = MockEntryRepository();
    when(() => habits.getHabitsForDate(any())).thenAnswer(
      (_) async => Success([
        buildDailyHabit(
          habit: buildHabitModel(id: 'habit-1', name: 'Read'),
          currentStreak: 4,
        ),
      ]),
    );
  });

  List<Override> overrides() => [
        ...signedOutOverrides(),
        habitRepositoryProvider.overrideWithValue(habits),
        entryRepositoryProvider.overrideWithValue(entries),
      ];

  testWidgets('lists the real habits, not the Stitch routines', (tester) async {
    await pumpApp(tester, const MyHabitsPage(), overrides: overrides());

    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Sunrise Ritual'), findsNothing);
    expect(find.text('Focus Block'), findsNothing);
  });

  testWidgets('renames a habit through the overflow menu', (tester) async {
    when(() => habits.updateHabit(
          habitId: any(named: 'habitId'),
          name: any(named: 'name'),
          color: any(named: 'color'),
          archived: any(named: 'archived'),
        )).thenAnswer((_) async => Success(buildHabitModel(name: 'Read daily')));

    await pumpApp(tester, const MyHabitsPage(), overrides: overrides());

    await tester.tap(find.byKey(const ValueKey('habit-menu-habit-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Read daily');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(() => habits.updateHabit(
          habitId: 'habit-1',
          name: 'Read daily',
          color: null,
          archived: null,
        )).called(1);
  });

  testWidgets('archiving does not ask for confirmation', (tester) async {
    when(() => habits.updateHabit(
          habitId: any(named: 'habitId'),
          name: any(named: 'name'),
          color: any(named: 'color'),
          archived: any(named: 'archived'),
        )).thenAnswer((_) async => Success(buildHabitModel()));

    await pumpApp(tester, const MyHabitsPage(), overrides: overrides());

    await tester.tap(find.byKey(const ValueKey('habit-menu-habit-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    verify(() => habits.updateHabit(
          habitId: 'habit-1',
          name: null,
          color: null,
          archived: true,
        )).called(1);
  });

  testWidgets('deleting asks first and does nothing when cancelled',
      (tester) async {
    await pumpApp(tester, const MyHabitsPage(), overrides: overrides());

    await tester.tap(find.byKey(const ValueKey('habit-menu-habit-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.textContaining('cannot be undone'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => habits.deleteHabit(any()));
  });

  testWidgets('confirming the dialog deletes the habit', (tester) async {
    when(() => habits.deleteHabit(any()))
        .thenAnswer((_) async => const Success(null));

    await pumpApp(tester, const MyHabitsPage(), overrides: overrides());

    await tester.tap(find.byKey(const ValueKey('habit-menu-habit-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete habit'));
    await tester.pumpAndSettle();

    verify(() => habits.deleteHabit('habit-1')).called(1);
  });

  testWidgets('shows an empty state when nothing is tracked', (tester) async {
    when(() => habits.getHabitsForDate(any()))
        .thenAnswer((_) async => const Success(<DailyHabit>[]));

    await pumpApp(tester, const MyHabitsPage(), overrides: overrides());

    expect(find.textContaining('Nothing planted'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/habits/presentation/my_habits_page_test.dart`
Expected: FAIL — `my_habits_page.dart` does not exist.

- [ ] **Step 3: Write the page**

Build `MyHabitsPage` as a `ConsumerWidget` reusing the chrome from `routines_page.dart` — the same app bar, the same `'Your Routines'` hero block with the title changed to `'Your Habits'` and the subtitle to `'Everything you are growing right now.'`, and the same `CustomScrollView` structure. Replace the three `_RoutineCard`s and `_CustomRoutineCard` with a list of `_HabitRow`s over `ref.watch(dailyHabitsProvider)`, using the same `switch` over `AsyncValue` as Task 15 (loading → `AppLoading`, error → `AppError` with `onRetry`, empty → an empty state reading `'Nothing planted yet'`). Keep the Add card at the bottom of the list, pushing `RouteNames.addHabit`.

Each row:

```dart
class _HabitRow extends ConsumerWidget {
  const _HabitRow({required this.habit});

  final DailyHabit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = HabitColors.parse(habit.color);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: AppSpacing.borderRadiusCard,
        boxShadow: AppSpacing.ambientShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.name,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  habit.currentStreak == 0
                      ? 'No streak yet'
                      : '${habit.currentStreak} day streak',
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            key: ValueKey('habit-menu-${habit.id}'),
            icon: const Icon(Icons.more_horiz_rounded,
                color: AppColors.onSurfaceVariant),
            onSelected: (action) => _onAction(context, ref, action),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'color', child: Text('Change colour')),
              PopupMenuItem(value: 'archive', child: Text('Archive')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context, WidgetRef ref, String action) async {
    final notifier = ref.read(dailyHabitsProvider.notifier);

    final failure = switch (action) {
      'rename' => await _rename(context, notifier),
      'color' => await _recolor(context, notifier),
      // Archiving is reversible and keeps history, so it needs no dialog.
      'archive' => await notifier.archive(habit.id),
      'delete' => await _confirmDelete(context, notifier),
      _ => null,
    };

    if (failure == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failure.message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  // _rename, _recolor and _confirmDelete follow in the next step.
}
```

- [ ] **Step 4: Write the three dialogs**

```dart
  Future<Failure?> _rename(
      BuildContext context, DailyHabitsNotifier notifier) async {
    final controller = TextEditingController(text: habit.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename habit'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (name == null) return null;
    return notifier.rename(habit.id, name);
  }

  Future<Failure?> _recolor(
      BuildContext context, DailyHabitsNotifier notifier) async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change colour'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final hex in HabitColors.palette)
              InkWell(
                onTap: () => Navigator.of(context).pop(hex),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: HabitColors.parse(hex),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hex == habit.color
                          ? AppColors.onSurface
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (chosen == null) return null;
    return notifier.recolor(habit.id, chosen);
  }

  Future<Failure?> _confirmDelete(
      BuildContext context, DailyHabitsNotifier notifier) async {
    // Deleting cascades to every entry the habit has. Archiving is the
    // reversible option, so this is the one that asks.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${habit.name}"?'),
        content: const Text(
          'This removes the habit and its whole history. It cannot be undone — '
          'archive it instead to keep the record.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete habit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return null;
    return notifier.remove(habit.id);
  }
```

- [ ] **Step 5: Point the router and the nav bar at the new page**

In `mobile/lib/app/router/app_router.dart`, swap the import and the builder:

```dart
                builder: (context, state) => const MyHabitsPage(),
```

In `mobile/lib/app/shell/main_shell_scaffold.dart`, change the second destination's label from `'Routines'` to `'Habits'` and its icon to `Icons.spa_outlined`.

Then delete `routines_page.dart` and `routines_page_test.dart`.

- [ ] **Step 6: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/habits/presentation/`
Expected: PASS — 6 new tests plus Task 15's 6, and no reference to the deleted page

- [ ] **Step 7: Commit**

```bash
git add -A mobile/lib/features/habits/presentation/pages mobile/lib/app/router/app_router.dart mobile/lib/app/shell/main_shell_scaffold.dart mobile/test/features/habits/presentation/
git commit -m "feat(mobile): replace the Routines mockup with a real My Habits list

Routines had no backing in the schema. The tab now lists real habits and
is the only place PATCH and DELETE /habits are reachable, which the app
previously had no way to call at all."
```

---

## Task 17: Add Habit creates a real habit

**Files:**
- Modify: `mobile/lib/features/habits/presentation/pages/add_habit_page.dart`
- Test: `mobile/test/features/habits/presentation/add_habit_page_test.dart` (create)

**Interfaces:**
- Consumes: `dailyHabitsProvider.create`, `HabitColors.palette` (Tasks 12, 15).
- Produces: no new public API. `AddHabitPage` becomes a `ConsumerStatefulWidget`.

**What is removed:** `_goalController`, `_selectedFrequency`, `_frequencyOptions`, `_reminderTime`, `_selectTime`, and the goal, frequency and reminder sections of the form — the schema stores none of them. **What is added:** a colour picker over `HabitColors.palette`, and a submitting state on the Confirm button.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/habits/presentation/add_habit_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/failures.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/features/habits/presentation/pages/add_habit_page.dart';
import 'package:mobile/injection/dependency_injection.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';
import '../../../helpers/pump_app.dart';

void main() {
  late MockHabitRepository habits;
  late MockEntryRepository entries;

  setUpAll(registerFallbacks);

  setUp(() {
    habits = MockHabitRepository();
    entries = MockEntryRepository();
    when(() => habits.getHabitsForDate(any()))
        .thenAnswer((_) async => const Success([]));
    when(() => habits.createHabit(
          name: any(named: 'name'),
          color: any(named: 'color'),
        )).thenAnswer((_) async => Success(buildHabitModel()));
  });

  List<Override> overrides() => [
        ...signedOutOverrides(),
        habitRepositoryProvider.overrideWithValue(habits),
        entryRepositoryProvider.overrideWithValue(entries),
      ];

  testWidgets('drops the fields the schema cannot store', (tester) async {
    await pumpApp(tester, const AddHabitPage(), overrides: overrides());

    expect(find.textContaining('Every day'), findsNothing);
    expect(find.textContaining('Reminder'), findsNothing);
    expect(find.textContaining('Goal'), findsNothing);
  });

  testWidgets('creates the selected seed habit', (tester) async {
    await pumpApp(tester, const AddHabitPage(), overrides: overrides());

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    verify(() => habits.createHabit(
          name: 'Drink water',
          color: any(named: 'color'),
        )).called(1);
  });

  testWidgets('creates a custom habit from the text field', (tester) async {
    await pumpApp(tester, const AddHabitPage(), overrides: overrides());

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Walk the dog');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    verify(() => habits.createHabit(
          name: 'Walk the dog',
          color: any(named: 'color'),
        )).called(1);
  });

  testWidgets('a blank custom name never reaches the API', (tester) async {
    await pumpApp(tester, const AddHabitPage(), overrides: overrides());

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    verifyNever(() => habits.createHabit(
          name: any(named: 'name'),
          color: any(named: 'color'),
        ));
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('a server failure keeps the form open with a message',
      (tester) async {
    when(() => habits.createHabit(
          name: any(named: 'name'),
          color: any(named: 'color'),
        )).thenAnswer((_) async => const ResultError(ServerFailure('boom')));

    await pumpApp(tester, const AddHabitPage(), overrides: overrides());
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('boom'), findsOneWidget);
    expect(find.byType(AddHabitPage), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/habits/presentation/add_habit_page_test.dart`
Expected: FAIL — the page still shows the frequency and reminder sections and only pops with a SnackBar.

- [ ] **Step 3: Rewire the page**

Change the class to `ConsumerStatefulWidget` / `ConsumerState`. Delete `_goalController`, `_selectedFrequency`, `_frequencyOptions`, `_reminderTime` and `_selectTime`, and delete the goal, frequency and reminder-time sections from `build`. Add:

```dart
  String _selectedColor = HabitColors.palette.first;
  bool _isSubmitting = false;
```

Add a colour section above the Confirm button, matching the seed-chip row's spacing:

```dart
              Text(
                'COLOUR',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final hex in HabitColors.palette)
                    InkWell(
                      key: ValueKey('habit-color-$hex'),
                      onTap: () => setState(() => _selectedColor = hex),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: HabitColors.parse(hex),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: hex == _selectedColor
                                ? AppColors.onSurface
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
```

Replace `_onConfirm`:

```dart
  Future<void> _onConfirm() async {
    final habitName = _selectedSeed == 'Custom'
        ? _customHabitController.text.trim()
        : _selectedSeed;

    if (habitName.isEmpty) {
      _showMessage('Please enter a habit name', AppColors.error);
      return;
    }

    setState(() => _isSubmitting = true);

    final failure = await ref
        .read(dailyHabitsProvider.notifier)
        .create(name: habitName, color: _selectedColor);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (failure != null) {
      // Keep the form open so the user does not lose what they typed.
      _showMessage(failure.message, AppColors.error);
      return;
    }

    _showMessage('Planted habit "$habitName"!', AppColors.primary);
    context.pop();
  }

  void _showMessage(String message, Color background) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
```

Disable the Confirm button while submitting: `onPressed: _isSubmitting ? null : _onConfirm`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/habits/presentation/add_habit_page_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/habits/presentation/pages/add_habit_page.dart mobile/test/features/habits/presentation/add_habit_page_test.dart
git commit -m "feat(mobile): create real habits from Add Habit

Confirm now posts to /habits. Goal, frequency and reminder controls are
removed: the schema stores none of them, so they only promised a feature
that did not exist."
```

---

## Task 18: Insights shows real history

**Files:**
- Modify: `mobile/lib/features/insights/presentation/pages/insights_page.dart`
- Rewrite: `mobile/test/features/insights/presentation/insights_page_test.dart`

**Interfaces:**
- Consumes: `insightsProvider`, `InsightsSummary` (Tasks 13, 14).
- Produces: `_WeeklyFlowPainter` gains a constructor — `_WeeklyFlowPainter(this.points)` taking `List<double>` — replacing its hardcoded `[0.2, 0.35, 0.4, 0.6, 0.65, 0.85, 0.95]`.

**What changes:** the `'12'` and `'28'` stat cards read `summary.currentStreak` and `summary.bestStreak`; the chart plots the last seven entries of `summary.dailyCompletion` with weekday labels derived from the real dates; the two hardcoded `_FocusAreaCard`s become the top and bottom entries of `summary.habitConsistency`.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/insights/presentation/insights_page_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/failures.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/core/utils/date_utils.dart';
import 'package:mobile/core/widgets/app_error.dart';
import 'package:mobile/features/habits/domain/entities/habit.dart';
import 'package:mobile/features/insights/presentation/pages/insights_page.dart';
import 'package:mobile/injection/dependency_injection.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';
import '../../../helpers/pump_app.dart';

void main() {
  late MockHabitRepository habits;
  late MockEntryRepository entries;

  setUpAll(registerFallbacks);

  setUp(() {
    habits = MockHabitRepository();
    entries = MockEntryRepository();
  });

  List<Override> overrides() => [
        ...signedOutOverrides(),
        habitRepositoryProvider.overrideWithValue(habits),
        entryRepositoryProvider.overrideWithValue(entries),
      ];

  testWidgets('shows the computed streaks, not the hardcoded ones',
      (tester) async {
    when(() => habits.getHabits()).thenAnswer(
      (_) async => Success<List<Habit>>([
        buildHabitModel(id: 'habit-1', name: 'Read', createdAt: DateTime(2026, 1, 1)),
      ]),
    );
    when(() => entries.getEntries(
          habitId: any(named: 'habitId'),
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).thenAnswer((_) async => Success([
          AppDateUtils.today,
          AppDateUtils.today.subtract(const Duration(days: 1)),
          AppDateUtils.today.subtract(const Duration(days: 2)),
        ]));

    await pumpApp(tester, const InsightsPage(), overrides: overrides());

    expect(find.text('3'), findsWidgets);
    expect(find.text('12'), findsNothing);
    expect(find.text('28'), findsNothing);
  });

  testWidgets('names the real habits in Focus Areas', (tester) async {
    when(() => habits.getHabits()).thenAnswer(
      (_) async => Success<List<Habit>>([
        buildHabitModel(id: 'habit-1', name: 'Read', createdAt: DateTime(2026, 1, 1)),
        buildHabitModel(id: 'habit-2', name: 'Stretch', createdAt: DateTime(2026, 1, 1)),
      ]),
    );
    when(() => entries.getEntries(
          habitId: 'habit-1',
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).thenAnswer((_) async => Success([AppDateUtils.today]));
    when(() => entries.getEntries(
          habitId: 'habit-2',
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).thenAnswer((_) async => const Success(<DateTime>[]));

    await pumpApp(tester, const InsightsPage(), overrides: overrides());

    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Stretch'), findsOneWidget);
    expect(find.text('Meditation'), findsNothing);
    expect(find.text('Early Sleep'), findsNothing);
  });

  testWidgets('shows an empty state before anything is tracked',
      (tester) async {
    when(() => habits.getHabits())
        .thenAnswer((_) async => const Success(<Habit>[]));

    await pumpApp(tester, const InsightsPage(), overrides: overrides());

    expect(find.textContaining('Nothing to chart yet'), findsOneWidget);
  });

  testWidgets('offers a retry when the load fails', (tester) async {
    when(() => habits.getHabits())
        .thenAnswer((_) async => const ResultError(NetworkFailure()));

    await pumpApp(tester, const InsightsPage(), overrides: overrides());

    expect(find.byType(AppError), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/insights/presentation/insights_page_test.dart`
Expected: FAIL — the page is a `StatelessWidget` rendering hardcoded values.

- [ ] **Step 3: Rewire the page**

Make `InsightsPage` a `ConsumerWidget`. Wrap the existing `CustomScrollView` body in a `switch` over `ref.watch(insightsProvider)` with the same three branches as Task 15 — `AppLoading`, `AppError` with `onRetry: () => ref.read(insightsProvider.notifier).refresh()`, and the data branch. When `summary.habitCount == 0`, render a centred empty state reading `'Nothing to chart yet'` with the subtitle `'Check a habit off and your history starts here.'`.

In the data branch, keep every existing container, padding and decoration, and replace only the values:

- The current-streak card's `'12'` → `'${summary.currentStreak}'`.
- The best-streak card's `'28'` → `'${summary.bestStreak}'`.
- The chart: `painter: _WeeklyFlowPainter(_lastSevenDays(summary.dailyCompletion))`.
- The weekday row's `const ['M', 'T', 'W', 'T', 'F', 'S', 'S']` → labels from the real dates, so the last column is always today:

```dart
  /// The last seven completion rates, oldest first. A shorter history is
  /// left-padded with zeroes so the chart always has seven columns.
  static List<double> _lastSevenDays(List<double> daily) {
    if (daily.length >= 7) return daily.sublist(daily.length - 7);
    return [...List<double>.filled(7 - daily.length, 0), ...daily];
  }

  /// Weekday initials for the seven days ending today.
  static List<String> _weekdayInitials() {
    final today = AppDateUtils.today;
    return [
      for (var back = 6; back >= 0; back--)
        AppDateUtils.weekdayLabel(today.subtract(Duration(days: back)))
            .substring(0, 1),
    ];
  }
```

- Focus Areas: replace the two hardcoded `_FocusAreaCard`s with entries from `summary.habitConsistency`, which the calculator already sorted strongest first:

```dart
                    for (final entry in _focusAreas(summary)) ...[
                      _FocusAreaCard(
                        title: entry.habit.name,
                        subtitle: entry == summary.habitConsistency.first
                            ? 'Most Consistent'
                            : 'Needs Attention',
                        percentage: '${(entry.rate * 100).round()}%',
                        icon: Icons.eco_rounded,
                        iconBg: HabitColors.parse(entry.habit.color)
                            .withValues(alpha: 0.25),
                        iconColor: HabitColors.parse(entry.habit.color),
                        percentColor: HabitColors.parse(entry.habit.color),
                      ),
                      const SizedBox(height: AppSpacing.stackGap),
                    ],
```

```dart
  /// The strongest and the weakest habit. With one habit there is only one
  /// card, and showing the same habit twice would be noise.
  static List<HabitConsistency> _focusAreas(InsightsSummary summary) {
    final ranked = summary.habitConsistency;
    if (ranked.length < 2) return ranked;
    return [ranked.first, ranked.last];
  }
```

Give `_WeeklyFlowPainter` its constructor and use the passed points:

```dart
class _WeeklyFlowPainter extends CustomPainter {
  const _WeeklyFlowPainter(this.points);

  /// Completion rate per day, 0.0–1.0, oldest first.
  final List<double> points;

  // ... the existing paint body, with the hardcoded `points` local deleted.

  @override
  bool shouldRepaint(covariant _WeeklyFlowPainter oldDelegate) =>
      oldDelegate.points != points;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/insights/presentation/insights_page_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/insights/ mobile/test/features/insights/presentation/insights_page_test.dart
git commit -m "feat(mobile): plot real history on Insights

Streak cards, the weekly chart and Focus Areas now come from 30 days of
entries instead of hardcoded numbers."
```

---

## Task 19: Profile stats stop being invented

**Files:**
- Modify: `mobile/lib/features/profile/presentation/pages/profile_page.dart`
- Rewrite: `mobile/test/features/profile/presentation/profile_page_test.dart`

**Interfaces:**
- Consumes: `insightsProvider` (Task 14), `currentUserProvider`.
- Produces: no new public API.

**What changes:** `'88%'` → `summary.consistencyPercent`, `'14'` → `summary.habitCount`, `'28'` → `summary.currentStreak`, and `'Growing since Oct 2022'` → the user's real `createdAt`. Logout is already wired and stays as it is.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/features/profile/presentation/profile_page_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/errors/result.dart';
import 'package:mobile/core/utils/date_utils.dart';
import 'package:mobile/features/habits/domain/entities/habit.dart';
import 'package:mobile/features/profile/presentation/pages/profile_page.dart';
import 'package:mobile/injection/dependency_injection.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';
import '../../../helpers/pump_app.dart';

void main() {
  late MockHabitRepository habits;
  late MockEntryRepository entries;

  setUpAll(registerFallbacks);

  setUp(() {
    habits = MockHabitRepository();
    entries = MockEntryRepository();

    when(() => habits.getHabits()).thenAnswer(
      (_) async => Success<List<Habit>>([
        buildHabitModel(id: 'habit-1', name: 'Read', createdAt: DateTime(2026, 1, 1)),
        buildHabitModel(id: 'habit-2', name: 'Stretch', createdAt: DateTime(2026, 1, 1)),
      ]),
    );
    when(() => entries.getEntries(
          habitId: any(named: 'habitId'),
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).thenAnswer((_) async => Success([AppDateUtils.today]));
  });

  List<Override> overrides() => [
        ...signedOutOverrides(),
        habitRepositoryProvider.overrideWithValue(habits),
        entryRepositoryProvider.overrideWithValue(entries),
      ];

  testWidgets('shows the real habit count and streak', (tester) async {
    await pumpApp(tester, const ProfilePage(), overrides: overrides());

    expect(find.text('2'), findsOneWidget);
    expect(find.text('14'), findsNothing);
    expect(find.text('88%'), findsNothing);
  });

  testWidgets('the stat row falls back to zeroes while loading',
      (tester) async {
    when(() => habits.getHabits())
        .thenAnswer((_) async => const Success(<Habit>[]));

    await pumpApp(tester, const ProfilePage(), overrides: overrides());

    expect(find.text('0'), findsWidgets);
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('shows when the account was created, not a fixed date',
      (tester) async {
    await pumpApp(tester, const ProfilePage(), overrides: overrides());

    expect(find.textContaining('Growing since January 2026'), findsOneWidget);
    expect(find.textContaining('Oct 2022'), findsNothing);
  });
}
```

> The signed-out helper leaves `currentUserProvider` null. If the "Growing
> since" test fails on a null user, override `authNotifierProvider` in this
> test with a state carrying `buildUserModel(createdAt: DateTime(2026, 1, 15))`,
> mirroring how `login_page_test.dart` supplies auth state.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/features/profile/presentation/profile_page_test.dart`
Expected: FAIL — the page renders `88%`, `14`, `28` and `Growing since Oct 2022`.

- [ ] **Step 3: Rewire the page**

`ProfilePage` is already a `ConsumerWidget`. Add:

```dart
    // Zeroes while loading rather than a spinner: the stat row is decoration
    // on a page whose real purpose is settings and sign-out, and swapping it
    // for a spinner makes the whole page feel like it is loading.
    final summary =
        ref.watch(insightsProvider).valueOrNull ?? InsightsSummary.empty;
```

Replace the three `_StatColumn` values:

```dart
                      child: _StatColumn(
                        value: '${summary.consistencyPercent}%',
                        label: 'CONSISTENCY',
                      ),
```
```dart
                      child: _StatColumn(
                        value: '${summary.habitCount}',
                        label: 'HABITS',
                      ),
```
```dart
                      child: _StatColumn(
                        value: '${summary.currentStreak}',
                        label: 'STREAK',
                      ),
```

Replace the tagline:

```dart
              Text(
                _growingSince(user?.createdAt),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
```

```dart
  /// The month the account was created. Falls back to a neutral line rather
  /// than inventing a date when the profile has not loaded.
  static String _growingSince(DateTime? createdAt) {
    if (createdAt == null) return 'Welcome to Bloom';
    return 'Growing since ${AppDateUtils.monthLabel(createdAt)} '
        '${createdAt.year}';
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/features/profile/presentation/profile_page_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/profile/ mobile/test/features/profile/
git commit -m "feat(mobile): show real Profile stats

Consistency, habit count and streak come from the insights summary, and
the tagline uses the account's real creation date."
```

---

## Task 20: Full verification

**Files:** none — this task only runs things.

- [ ] **Step 1: Backend suite and typecheck**

Run: `cd backend && npm test && npx tsc --noEmit && npm run lint`
Expected: all suites PASS, no type errors, no lint errors

- [ ] **Step 2: Backend suite in both timezone extremes**

Run: `cd backend && TZ=Pacific/Kiritimati npm test && TZ=Pacific/Midway npm test`
Expected: PASS in both — day keys must not depend on the server's zone

- [ ] **Step 3: Mobile analyze and full suite**

Run: `cd mobile && flutter analyze && flutter test`
Expected: no analyzer issues; every test passes

- [ ] **Step 4: Mobile suite in both timezone extremes**

Run: `cd mobile && TZ=Pacific/Kiritimati flutter test && TZ=Pacific/Midway flutter test`
Expected: PASS in both

- [ ] **Step 5: Confirm no demo data survives**

Run:
```bash
cd mobile && grep -rn "Sunrise Ritual\|Focus Block\|Wind Down\|Drink enough water\|Growing since Oct\|_waterDrankLiters\|_meditateCompleted\|Early Sleep" lib/ || echo "clean"
```
Expected: `clean`

- [ ] **Step 6: Update the flow document**

`docs/APP_FLOW.md` §8 ("What is wired vs. what is UI-only") and §9 items 1–6 now describe fixed problems. Rewrite §8 so the "UI complete, local state only" and "Contract declared, no implementation" groups reflect reality, and remove items 1–6 from §9, leaving item 7 (`ForgotPasswordPage` has no backend) and adding the known limitation that `GET /habits?date=` loads a habit's whole entry history to compute streaks. Update the §4 screen-flow diagram: `ROUT` is now `/habits — MyHabitsPage`.

- [ ] **Step 7: Commit**

```bash
git add docs/APP_FLOW.md
git commit -m "docs: update APP_FLOW for the wired habit screens"
```

---

## Self-review

**Spec coverage.** Framing decision → Tasks 15–19 (UI fitted to the API, nothing faked). Routines → My Habits → Task 16. Client-side insights → Tasks 13, 14, 18. Contract corrections 1–6 → Tasks 1, 2, 3, 4, 5 and Task 11 step 3 respectively. Mobile architecture → Tasks 7–11. Interface revisions → Task 8 step 5 and Task 10 step 5. State table → Tasks 12, 14. Screens → Tasks 15–19. Testing → each task's own test steps, plus Task 20. Known limitation → recorded in Task 20 step 6. Out of scope items are untouched by every task.

**Type consistency.** `SetEntry.call` takes `completed`, the desired state, and is called that way in Task 12's `toggle`. `DailyHabitsNotifier.remove` (not `delete`) is used consistently in Tasks 12 and 16. `HabitColors.parse` / `HabitColors.palette` are defined in Task 15 and consumed in Tasks 16, 17, 18. `InsightsSummary.empty` is defined in Task 13 and consumed in Tasks 14 and 19. `insightsWindowDays` is defined in Task 14 and asserted in its own test.

**Known rough edges flagged inline rather than left to discover:** the `const` interpolation in `HabitValidators` (Task 9), the DST-safe day walk in `InsightsCalculator` (Task 13), the `List<Habit>` annotation in `InsightsNotifier` (Task 14), and the auth override the Profile "Growing since" test may need (Task 19).
