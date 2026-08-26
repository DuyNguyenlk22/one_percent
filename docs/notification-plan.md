# Daily Motivational Quote Push Notifications — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Send each user one personalized, Gemini-generated motivational push notification per day, at their own local reminder hour, with a static-quote fallback so a Gemini outage never means a silent day.

**Architecture:** An hourly NestJS cron scans enabled `notification_settings`, converts "now" into each user's IANA timezone, and acts on users whose local hour matches their `reminderHour`. For each due user it builds a habit context (names, streaks, what is still unchecked today), asks Gemini for one line, caches the result in `daily_quotes` keyed `(userId, localDate)`, and pushes to that user's registered FCM device tokens. The `(userId, localDate)` unique constraint plus a `sentAt` stamp make the whole job idempotent: a restart, a duplicate fire, or a second device costs zero extra Gemini calls and sends no duplicate push. Two modules stay independent — `quotes` knows nothing about push, `notifications` knows nothing about Gemini — so each is unit-testable with the other mocked.

**Tech Stack:** NestJS 11, Prisma 7 (`prisma-client` generator), PostgreSQL, `@nestjs/schedule` (cron), `@google/genai` (Gemini), `firebase-admin` (FCM), dayjs + utc/timezone plugins, Jest + supertest, pnpm.

**Spec:** `docs/habit-tracker-mvp-design-and-build-plan.md` (this feature is Future Phase 1, "reminders/notifications", pulled forward). The notification-specific design was agreed in brainstorming and is captured in the Design Decisions section below — no separate spec file exists, so the design travels with this plan.

---

## Design Decisions

These were settled during brainstorming. Do not re-litigate them mid-implementation.

| Decision | Choice | Why |
|---|---|---|
| Delivery | Real FCM push from the server | Notification must arrive with the app closed. |
| Trigger | Hourly cron, per-user `reminderHour` + IANA `timezone` | A nudge at 3am local is worse than no nudge. Minute-precision cron costs 1,440 wakeups/day for precision nobody asked for. |
| Personalization | Per user, one Gemini call per user per day, cached | Feels personal; cache means retries and extra devices are free. |
| Gemini failure | Static fallback pool of 20 quotes, deterministic pick | Free tier is 10 RPM — a batch WILL hit 429. The push still goes out. |
| Scope | Backend only | Mobile is still the bare `flutter create` starter with no auth screens; Flutter wiring is a separate plan after spec Phase 4. |
| Day boundary | Client/user local date, never server-derived | Matches the timezone rule chosen for the rest of the API. |
| Model | `gemini-2.5-flash` | Better text than flash-lite. Swap to `gemini-2.5-flash-lite` via `GEMINI_MODEL` if you ever exceed 250 users. |

**Flagged inconsistency (deliberate, do not "fix" beyond what Task 6 says):** the existing `computeCurrentStreak` counts back from the target date, so a habit not yet checked today reports a streak of `0`. The MVP spec says today-not-yet-done must NOT break the streak. `GET /habits` keeps its current behavior; only the quote context (Task 6) counts from yesterday when today is unchecked, so the notification never tells a user on a 12-day run that their streak is 0. Reconciling `/habits` is out of scope here.

**Known pre-existing bug NOT in scope:** `EntriesService.deleteEntry` (`src/entries/entries.service.ts`) accepts no `userId`, so any authenticated user can delete any other user's entry. Unrelated to notifications. Fix it in its own change.

---

## Global Constraints

Every task's requirements implicitly include this section.

- **Package manager:** `pnpm`. Install with `pnpm add <pkg>` from `backend/`.
- **Prisma:** version 7, generator `prisma-client`, output `../generated/prisma`, `moduleFormat = "cjs"`. Import model types from `generated/prisma/client`.
- **Schema conventions:** table names are snake_case via `@@map`; **column names stay camelCase** (the existing schema uses no per-field `@map` — follow the code, not the design doc's table listings).
- **Migrations:** `npx prisma migrate dev --name <name>` from `backend/`. Config lives in `backend/prisma.config.ts`, which reads `DATABASE_URL` from `backend/.env`.
- **TypeScript:** `strict: true`, `strictNullChecks: true`, `module`/`moduleResolution: nodenext`, `target: ES2023`. Absolute imports of the form `src/...` work via `baseUrl: "./"`.
- **Every new endpoint** is decorated `@UseGuards(JwtAuthGuard)` + `@ApiBearerAuth()` + `@ApiTags(...)`, and takes the user id via `@CurrentUser('id')`. Never accept a userId from the request body or params.
- **DTO style:** `class-validator` decorators plus `@ApiProperty()`, matching `src/habit/dto/create-habit.dto.ts`.
- **Unit tests:** live beside the source as `src/**/*.spec.ts` (Jest `rootDir` is `src`). Run `pnpm test`.
- **e2e tests:** live in `backend/test/**/*.e2e-spec.ts`. Run `pnpm test:e2e`. These need a live Postgres reachable via `DATABASE_URL`.
- **Secrets:** never commit `backend/.env` or the Firebase service-account JSON. Credentials reach the app base64-encoded in an env var.
- **Gemini free-tier quotas (verified Aug 2026):** `gemini-2.5-flash` = 10 RPM / 250 RPD. RPM is the binding constraint, which is why Task 9 paces calls.
- **Commit after every task**, using the `type(scope): message` style already in this repo's history (e.g. `feat(habit): implement compute streak`).

---

## File Structure

**New — quote generation (knows nothing about push):**

| File | Responsibility |
|---|---|
| `backend/src/quotes/quotes.types.ts` | `QuoteContext`, `QuoteSource`, `GeneratedQuote` shared types |
| `backend/src/quotes/fallback-quotes.ts` | 20 static quotes + deterministic `pickFallbackQuote` |
| `backend/src/quotes/gemini.service.ts` | `buildPrompt` + thin `@google/genai` wrapper; returns `null` on ANY failure |
| `backend/src/quotes/quotes.service.ts` | Builds habit context, caches in `daily_quotes`, falls back |
| `backend/src/quotes/quotes.module.ts` | Exports `QuotesService` |

**New — notifications (knows nothing about Gemini):**

| File | Responsibility |
|---|---|
| `backend/src/notifications/fcm.service.ts` | `firebase-admin` wrapper; sends and reports dead tokens |
| `backend/src/notifications/device-tokens.service.ts` | Register / remove / list FCM tokens |
| `backend/src/notifications/notification-settings.service.ts` | Get-or-create and update per-user settings |
| `backend/src/notifications/notifications.service.ts` | Orchestrates one daily run; paces Gemini calls |
| `backend/src/notifications/notifications.scheduler.ts` | Hourly `@Cron` that calls the service |
| `backend/src/notifications/notifications.controller.ts` | REST surface under `/notifications` |
| `backend/src/notifications/dto/*.ts` | Request DTOs |
| `backend/src/notifications/notifications.module.ts` | Wires the above |

**New — shared:** `backend/src/utils/timezone.ts` (local hour/date conversion, timezone validation, date-only coercion).

**Modified:** `backend/prisma/schema.prisma` (3 models + `User` relations), `backend/src/app.module.ts` (register `ScheduleModule`, `QuotesModule`, `NotificationsModule`), `backend/package.json` (deps + Jest `moduleNameMapper`), `backend/test/jest-e2e.json` (same mapping), `backend/src/auth/auth.service.ts` (Task 1 bug fix), `backend/src/utils/index.ts` (re-export).

---

## API Surface

All routes require a Bearer token and act only on the caller's own data.

| Method | Path | Body | Returns |
|---|---|---|---|
| POST | `/notifications/device-tokens` | `{ token, platform? }` | `{ id, token, platform, createdAt }` |
| DELETE | `/notifications/device-tokens` | `{ token }` | `{ code, message }` |
| GET | `/notifications/settings` | — | `{ enabled, reminderHour, timezone }` |
| PUT | `/notifications/settings` | `{ enabled?, reminderHour?, timezone? }` | updated settings |

---

## Task 1: Make Jest resolvable and fix the register-token bug

The register endpoint signs `{ id }` while the JWT strategy reads `payload.userId`, so a token from `/auth/register` never authenticates. Every later e2e test registers a user and then calls a guarded endpoint, so this blocks the whole plan. Jest also cannot currently resolve the `src/...` imports every file uses, because Jest ignores tsconfig `baseUrl` — no unit test can run until that is mapped.

**Files:**
- Modify: `backend/package.json` (Jest `moduleNameMapper`)
- Modify: `backend/test/jest-e2e.json` (same mapping)
- Modify: `backend/src/auth/auth.service.ts:63`
- Test: `backend/src/auth/auth.service.spec.ts`

**Interfaces:**
- Consumes: nothing.
- Produces: a working `pnpm test`; `AuthService.register` returns a token whose payload is `{ userId: string }`.

- [ ] **Step 1: Add Jest module mapping so `src/...` imports resolve**

In `backend/package.json`, inside the top-level `"jest"` object (whose `rootDir` is `"src"`), add a `moduleNameMapper` key alongside the existing `moduleFileExtensions`:

```json
    "moduleNameMapper": {
      "^src/(.*)$": "<rootDir>/$1",
      "^generated/(.*)$": "<rootDir>/../generated/$1"
    },
```

- [ ] **Step 2: Add the same mapping to the e2e config**

In `backend/test/jest-e2e.json` (whose `rootDir` is `"."`, the `backend/` folder), add:

```json
  "moduleNameMapper": {
    "^src/(.*)$": "<rootDir>/src/$1",
    "^generated/(.*)$": "<rootDir>/generated/$1"
  },
```

- [ ] **Step 3: Write the failing test**

Create `backend/src/auth/auth.service.spec.ts`:

```ts
import { Test, TestingModule } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { AuthService } from './auth.service';
import { PrismaService } from 'src/prisma.service';

describe('AuthService', () => {
  let service: AuthService;
  let jwt: { sign: jest.Mock; signAsync: jest.Mock };
  let prisma: { user: { findUnique: jest.Mock; create: jest.Mock } };

  beforeEach(async () => {
    jwt = {
      sign: jest.fn().mockReturnValue('signed-token'),
      signAsync: jest.fn().mockResolvedValue('signed-token'),
    };
    prisma = { user: { findUnique: jest.fn(), create: jest.fn() } };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: prisma },
        { provide: JwtService, useValue: jwt },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
  });

  it('signs the register token with the userId claim the JWT strategy reads', async () => {
    prisma.user.findUnique.mockResolvedValue(null);
    prisma.user.create.mockResolvedValue({
      id: 'user-1',
      email: 'a@b.com',
      passwordHash: 'hash',
      createdAt: new Date(),
    });

    await service.register('a@b.com', 'password123');

    expect(jwt.signAsync).toHaveBeenCalledWith({ userId: 'user-1' });
  });
});
```

- [ ] **Step 4: Run the test and watch it fail**

Run: `cd backend && pnpm test -- auth.service`
Expected: FAIL — received `{"id": "user-1"}`, expected `{"userId": "user-1"}`.

- [ ] **Step 5: Fix the payload**

In `backend/src/auth/auth.service.ts`, in `register`, change the signing line:

```ts
    const accessToken = await this.jwtService.signAsync({ userId: user.id });
```

- [ ] **Step 6: Run the test and watch it pass**

Run: `cd backend && pnpm test -- auth.service`
Expected: PASS, 1 test.

- [ ] **Step 7: Commit**

```bash
cd backend
git add package.json test/jest-e2e.json src/auth/auth.service.ts src/auth/auth.service.spec.ts
git commit -m "fix(auth): sign register token with userId claim and make jest resolve src imports"
```

---

## Task 2: Timezone helpers

Pure date/timezone functions the scheduler depends on. Isolated here so the cron logic can be tested without a clock or a database.

**Files:**
- Create: `backend/src/utils/timezone.ts`
- Modify: `backend/src/utils/index.ts`
- Test: `backend/src/utils/timezone.spec.ts`

**Interfaces:**
- Consumes: `DATE_FORMAT` from `src/utils/dayjs.ts`.
- Produces:
  - `isValidTimezone(tz: string): boolean`
  - `localHourFor(tz: string, at: Date): number` — 0–23
  - `localDateFor(tz: string, at: Date): string` — `YYYY-MM-DD`
  - `toDateOnly(localDate: string): Date` — UTC-midnight `Date` for a `@db.Date` column

- [ ] **Step 1: Write the failing test**

Create `backend/src/utils/timezone.spec.ts`:

```ts
import {
  isValidTimezone,
  localDateFor,
  localHourFor,
  toDateOnly,
} from './timezone';

describe('timezone helpers', () => {
  // 2026-03-01T22:30:00Z is 2026-03-02 05:30 in Ho Chi Minh (UTC+7)
  const at = new Date('2026-03-01T22:30:00.000Z');

  it('accepts a real IANA zone and rejects junk', () => {
    expect(isValidTimezone('Asia/Ho_Chi_Minh')).toBe(true);
    expect(isValidTimezone('UTC')).toBe(true);
    expect(isValidTimezone('Mars/Olympus_Mons')).toBe(false);
    expect(isValidTimezone('')).toBe(false);
  });

  it('converts an instant to the local hour of a zone', () => {
    expect(localHourFor('UTC', at)).toBe(22);
    expect(localHourFor('Asia/Ho_Chi_Minh', at)).toBe(5);
  });

  it('rolls the local date forward across the UTC day boundary', () => {
    expect(localDateFor('UTC', at)).toBe('2026-03-01');
    expect(localDateFor('Asia/Ho_Chi_Minh', at)).toBe('2026-03-02');
  });

  it('coerces a YYYY-MM-DD string to UTC midnight', () => {
    expect(toDateOnly('2026-03-02').toISOString()).toBe(
      '2026-03-02T00:00:00.000Z',
    );
  });
});
```

- [ ] **Step 2: Run the test and watch it fail**

Run: `cd backend && pnpm test -- timezone`
Expected: FAIL — `Cannot find module './timezone'`.

- [ ] **Step 3: Implement the helpers**

Create `backend/src/utils/timezone.ts`:

```ts
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import { DATE_FORMAT } from './dayjs';

dayjs.extend(utc);
dayjs.extend(timezone);

export const isValidTimezone = (tz: string): boolean => {
  if (!tz) return false;
  try {
    Intl.DateTimeFormat(undefined, { timeZone: tz });
    return true;
  } catch {
    return false;
  }
};

export const localHourFor = (tz: string, at: Date): number =>
  dayjs(at).tz(tz).hour();

export const localDateFor = (tz: string, at: Date): string =>
  dayjs(at).tz(tz).format(DATE_FORMAT);

export const toDateOnly = (localDate: string): Date =>
  new Date(`${localDate}T00:00:00.000Z`);
```

- [ ] **Step 4: Re-export from the utils barrel**

Replace the contents of `backend/src/utils/index.ts`:

```ts
export * from './bcrypt';
export * from './dayjs';
export * from './streak';
export * from './timezone';
```

- [ ] **Step 5: Run the test and watch it pass**

Run: `cd backend && pnpm test -- timezone`
Expected: PASS, 4 tests.

- [ ] **Step 6: Commit**

```bash
cd backend
git add src/utils/timezone.ts src/utils/timezone.spec.ts src/utils/index.ts
git commit -m "feat(utils): add timezone helpers for per-user reminder scheduling"
```

---

## Task 3: Database schema for tokens, settings, and cached quotes

**Files:**
- Modify: `backend/prisma/schema.prisma`
- Creates (generated): `backend/prisma/migrations/<timestamp>_add_notifications/migration.sql`

**Interfaces:**
- Consumes: existing `User` model.
- Produces: Prisma models `DeviceToken`, `NotificationSetting`, `DailyQuote`, importable from `generated/prisma/client`. Compound unique key accessor is `userId_localDate` on `DailyQuote`.

- [ ] **Step 1: Add the three models**

Append to `backend/prisma/schema.prisma`:

```prisma
model DeviceToken {
 id String @id @default(uuid())
 userId String
 token String @unique
 platform String @default("android")
 createdAt DateTime @default(now())
 user User @relation(fields: [userId], references: [id], onDelete: Cascade)
 @@index([userId])
 @@map("device_tokens")
}

model NotificationSetting {
 id String @id @default(uuid())
 userId String @unique
 enabled Boolean @default(true)
 reminderHour Int @default(8)
 timezone String @default("UTC")
 createdAt DateTime @default(now())
 updatedAt DateTime @updatedAt
 user User @relation(fields: [userId], references: [id], onDelete: Cascade)
 @@map("notification_settings")
}

model DailyQuote {
 id String @id @default(uuid())
 userId String
 localDate DateTime @db.Date
 text String
 source String
 sentAt DateTime?
 createdAt DateTime @default(now())
 user User @relation(fields: [userId], references: [id], onDelete: Cascade)
 @@unique([userId, localDate])
 @@map("daily_quotes")
}
```

- [ ] **Step 2: Add the back-relations on User**

In the existing `User` model in `backend/prisma/schema.prisma`, add three relation fields directly under `habits Habit[]`:

```prisma
 deviceTokens DeviceToken[]
 notificationSetting NotificationSetting?
 dailyQuotes DailyQuote[]
```

- [ ] **Step 3: Generate and apply the migration**

Run: `cd backend && npx prisma migrate dev --name add_notifications`
Expected: a new folder under `prisma/migrations/` and `Your database is now in sync with your schema.`

- [ ] **Step 4: Verify the client compiles against the new models**

Run: `cd backend && npx tsc --noEmit -p tsconfig.json`
Expected: exit code 0, no errors.

- [ ] **Step 5: Commit**

```bash
cd backend
git add prisma/schema.prisma prisma/migrations
git commit -m "feat(notifications): add device token, settings, and daily quote models"
```

---

## Task 4: Static fallback quote pool

Gemini's free tier is 10 requests per minute. A daily batch will hit that ceiling, so the fallback is a load-bearing path, not decoration. The pick is deterministic on `(userId, localDate)` so the same user never sees the quote change on a retry, and the function is trivially testable.

**Files:**
- Create: `backend/src/quotes/fallback-quotes.ts`
- Test: `backend/src/quotes/fallback-quotes.spec.ts`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `FALLBACK_QUOTES: string[]` — exactly 20 entries
  - `pickFallbackQuote(userId: string, localDate: string): string`

- [ ] **Step 1: Write the failing test**

Create `backend/src/quotes/fallback-quotes.spec.ts`:

```ts
import { FALLBACK_QUOTES, pickFallbackQuote } from './fallback-quotes';

describe('pickFallbackQuote', () => {
  it('ships a non-empty pool of distinct quotes', () => {
    expect(FALLBACK_QUOTES).toHaveLength(20);
    expect(new Set(FALLBACK_QUOTES).size).toBe(20);
    FALLBACK_QUOTES.forEach((quote) => expect(quote.trim()).not.toBe(''));
  });

  it('always returns a quote from the pool', () => {
    expect(FALLBACK_QUOTES).toContain(pickFallbackQuote('user-1', '2026-03-02'));
  });

  it('is deterministic for the same user and date', () => {
    expect(pickFallbackQuote('user-1', '2026-03-02')).toBe(
      pickFallbackQuote('user-1', '2026-03-02'),
    );
  });

  it('varies across dates for the same user', () => {
    const picks = new Set(
      ['2026-03-01', '2026-03-02', '2026-03-03', '2026-03-04', '2026-03-05'].map(
        (date) => pickFallbackQuote('user-1', date),
      ),
    );
    expect(picks.size).toBeGreaterThan(1);
  });

  it('never returns undefined for inputs that hash negative', () => {
    for (let i = 0; i < 200; i++) {
      expect(typeof pickFallbackQuote(`user-${i}`, '2026-03-02')).toBe('string');
    }
  });
});
```

- [ ] **Step 2: Run the test and watch it fail**

Run: `cd backend && pnpm test -- fallback-quotes`
Expected: FAIL — `Cannot find module './fallback-quotes'`.

- [ ] **Step 3: Implement the pool**

Create `backend/src/quotes/fallback-quotes.ts`:

```ts
export const FALLBACK_QUOTES: string[] = [
  'Small steps, taken daily, outrun big plans made yearly.',
  'You do not have to be fast today. You only have to show up.',
  'Consistency is just a decision you keep making.',
  'The habit you keep on a bad day is the one that changes you.',
  'One percent better is still better. Go get your one percent.',
  'Motivation follows action far more often than it leads it.',
  'Missing once is an accident. Missing twice starts a new habit.',
  'The streak is not the point. The person building it is.',
  'Start smaller than feels worthwhile. Then start.',
  'Discipline is remembering what you actually want.',
  'Today is a vote for the person you are becoming.',
  'Progress hides in the days that felt like nothing.',
  'You are allowed a slow day. You are not required to quit.',
  'Do it badly rather than not at all.',
  'The gap between knowing and doing closes in minutes, not years.',
  'Show up before you feel ready. Readiness arrives later.',
  'Your future self is watching. Give them something to work with.',
  'A five-minute version still counts.',
  'Momentum is built, never found.',
  'Finish today so tomorrow starts easier.',
];

export const pickFallbackQuote = (
  userId: string,
  localDate: string,
): string => {
  const seed = `${userId}:${localDate}`;
  let hash = 0;
  for (let i = 0; i < seed.length; i++) {
    hash = (hash * 31 + seed.charCodeAt(i)) | 0;
  }
  const size = FALLBACK_QUOTES.length;
  const index = ((hash % size) + size) % size;
  return FALLBACK_QUOTES[index];
};
```

- [ ] **Step 4: Run the test and watch it pass**

Run: `cd backend && pnpm test -- fallback-quotes`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
cd backend
git add src/quotes/fallback-quotes.ts src/quotes/fallback-quotes.spec.ts
git commit -m "feat(quotes): add deterministic static fallback quote pool"
```

---

## Task 5: Gemini client and prompt builder

A thin wrapper around `@google/genai` that **never throws**. Every failure mode — missing key, 429, timeout, safety block, empty response — collapses to `null`, so the caller has exactly one branch to handle and the daily run cannot be killed by a bad API call.

**Files:**
- Create: `backend/src/quotes/quotes.types.ts`
- Create: `backend/src/quotes/gemini.service.ts`
- Test: `backend/src/quotes/gemini.service.spec.ts`
- Modify: `backend/package.json` (dependency)

**Interfaces:**
- Consumes: `ConfigService` (global), env `GEMINI_API_KEY` and `GEMINI_MODEL`.
- Produces:
  - `interface QuoteContext { habits: Array<{ name: string; currentStreak: number; doneToday: boolean }> }`
  - `type QuoteSource = 'gemini' | 'fallback'`
  - `interface GeneratedQuote { text: string; source: QuoteSource; fromCache: boolean }`
  - `buildPrompt(context: QuoteContext): string`
  - `GeminiService.generate(context: QuoteContext): Promise<string | null>`

- [ ] **Step 1: Install the SDK**

Run: `cd backend && pnpm add @google/genai`
Expected: `@google/genai` appears under `dependencies` in `package.json`.

- [ ] **Step 2: Create the shared types**

Create `backend/src/quotes/quotes.types.ts`:

```ts
export interface QuoteHabitContext {
  name: string;
  currentStreak: number;
  doneToday: boolean;
}

export interface QuoteContext {
  habits: QuoteHabitContext[];
}

export type QuoteSource = 'gemini' | 'fallback';

export interface GeneratedQuote {
  text: string;
  source: QuoteSource;
  fromCache: boolean;
}
```

- [ ] **Step 3: Write the failing test**

Create `backend/src/quotes/gemini.service.spec.ts`:

```ts
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { GeminiService, buildPrompt } from './gemini.service';
import { QuoteContext } from './quotes.types';

const mockGenerateContent = jest.fn();

jest.mock('@google/genai', () => ({
  GoogleGenAI: jest.fn(() => ({
    models: { generateContent: mockGenerateContent },
  })),
}));

const context: QuoteContext = {
  habits: [
    { name: 'Meditate', currentStreak: 12, doneToday: false },
    { name: 'Read', currentStreak: 3, doneToday: true },
  ],
};

const buildService = async (env: Record<string, string | undefined>) => {
  const module: TestingModule = await Test.createTestingModule({
    providers: [
      GeminiService,
      { provide: ConfigService, useValue: { get: (key: string) => env[key] } },
    ],
  }).compile();
  return module.get<GeminiService>(GeminiService);
};

describe('buildPrompt', () => {
  it('names every habit with its streak and whether it is done', () => {
    const prompt = buildPrompt(context);
    expect(prompt).toContain('Meditate');
    expect(prompt).toContain('12-day streak');
    expect(prompt).toContain('not done yet today');
    expect(prompt).toContain('Read');
    expect(prompt).toContain('already done today');
  });
});

describe('GeminiService', () => {
  beforeEach(() => {
    mockGenerateContent.mockReset();
  });

  it('returns the trimmed model text', async () => {
    mockGenerateContent.mockResolvedValue({ text: '  Day 12 of Meditate. Go.  ' });
    const service = await buildService({ GEMINI_API_KEY: 'key' });

    await expect(service.generate(context)).resolves.toBe('Day 12 of Meditate. Go.');
  });

  it('returns null instead of throwing when the API errors', async () => {
    mockGenerateContent.mockRejectedValue(new Error('429 rate limit exceeded'));
    const service = await buildService({ GEMINI_API_KEY: 'key' });

    await expect(service.generate(context)).resolves.toBeNull();
  });

  it('returns null when the model returns empty text', async () => {
    mockGenerateContent.mockResolvedValue({ text: '   ' });
    const service = await buildService({ GEMINI_API_KEY: 'key' });

    await expect(service.generate(context)).resolves.toBeNull();
  });

  it('returns null without calling the API when no key is configured', async () => {
    const service = await buildService({});

    await expect(service.generate(context)).resolves.toBeNull();
    expect(mockGenerateContent).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 4: Run the test and watch it fail**

Run: `cd backend && pnpm test -- gemini.service`
Expected: FAIL — `Cannot find module './gemini.service'`.

- [ ] **Step 5: Implement the service**

Create `backend/src/quotes/gemini.service.ts`:

```ts
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { GoogleGenAI } from '@google/genai';
import { QuoteContext } from './quotes.types';

export const DEFAULT_GEMINI_MODEL = 'gemini-2.5-flash';

export const buildPrompt = (context: QuoteContext): string => {
  const habitLines = context.habits.map(
    (habit) =>
      `- ${habit.name}: ${habit.currentStreak}-day streak, ${
        habit.doneToday ? 'already done today' : 'not done yet today'
      }`,
  );

  return [
    'You write a single short motivational line for a habit-tracking app.',
    'Rules: at most 25 words, address the user as "you", no emoji, no quotation marks, no preamble.',
    'Mention at least one habit by name. Reply with the sentence only.',
    '',
    "The user's habits today:",
    ...habitLines,
  ].join('\n');
};

@Injectable()
export class GeminiService {
  private readonly logger = new Logger(GeminiService.name);
  private readonly client: GoogleGenAI | null;
  private readonly model: string;

  constructor(private readonly config: ConfigService) {
    const apiKey = this.config.get<string>('GEMINI_API_KEY');
    this.model = this.config.get<string>('GEMINI_MODEL') ?? DEFAULT_GEMINI_MODEL;
    this.client = apiKey ? new GoogleGenAI({ apiKey }) : null;

    if (!this.client) {
      this.logger.warn(
        'GEMINI_API_KEY is not set; every quote will use the static fallback pool.',
      );
    }
  }

  async generate(context: QuoteContext): Promise<string | null> {
    if (!this.client) return null;

    try {
      const response = await this.client.models.generateContent({
        model: this.model,
        contents: buildPrompt(context),
      });
      const text = response.text?.trim();
      return text ? text : null;
    } catch (error) {
      this.logger.error(
        `Gemini generation failed: ${(error as Error).message}`,
      );
      return null;
    }
  }
}
```

- [ ] **Step 6: Run the test and watch it pass**

Run: `cd backend && pnpm test -- gemini.service`
Expected: PASS, 5 tests.

- [ ] **Step 7: Commit**

```bash
cd backend
git add package.json pnpm-lock.yaml src/quotes/quotes.types.ts src/quotes/gemini.service.ts src/quotes/gemini.service.spec.ts
git commit -m "feat(quotes): add gemini client and prompt builder with null-on-failure contract"
```

---

## Task 6: QuotesService — habit context, caching, fallback

Owns the "one quote per user per day" rule. Note the streak adjustment: when today is not yet checked off, the streak is counted from **yesterday**, so a user on a 12-day run who has not checked in yet is told "12", not "0". This is the MVP spec's documented rule; `GET /habits` is intentionally left alone.

**Files:**
- Create: `backend/src/quotes/quotes.service.ts`
- Create: `backend/src/quotes/quotes.module.ts`
- Test: `backend/src/quotes/quotes.service.spec.ts`

**Interfaces:**
- Consumes: `PrismaService`, `GeminiService.generate`, `pickFallbackQuote`, `computeCurrentStreak` (from `src/utils/streak`), `toDateOnly` (Task 2).
- Produces:
  - `QuotesService.buildContext(userId: string, localDate: string): Promise<QuoteContext>`
  - `QuotesService.getOrCreateDailyQuote(userId: string, localDate: string): Promise<GeneratedQuote>`
  - `QuotesModule` exporting `QuotesService`

- [ ] **Step 1: Write the failing test**

Create `backend/src/quotes/quotes.service.spec.ts`:

```ts
import { Test, TestingModule } from '@nestjs/testing';
import { QuotesService } from './quotes.service';
import { GeminiService } from './gemini.service';
import { PrismaService } from 'src/prisma.service';
import { FALLBACK_QUOTES } from './fallback-quotes';

describe('QuotesService', () => {
  let service: QuotesService;
  let prisma: {
    habit: { findMany: jest.Mock };
    dailyQuote: { findUnique: jest.Mock; upsert: jest.Mock };
  };
  let gemini: { generate: jest.Mock };

  beforeEach(async () => {
    prisma = {
      habit: { findMany: jest.fn().mockResolvedValue([]) },
      dailyQuote: {
        findUnique: jest.fn().mockResolvedValue(null),
        upsert: jest.fn().mockResolvedValue({}),
      },
    };
    gemini = { generate: jest.fn() };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        QuotesService,
        { provide: PrismaService, useValue: prisma },
        { provide: GeminiService, useValue: gemini },
      ],
    }).compile();

    service = module.get<QuotesService>(QuotesService);
  });

  describe('buildContext', () => {
    it('counts the streak from yesterday when today is not yet done', async () => {
      prisma.habit.findMany.mockResolvedValue([
        {
          name: 'Meditate',
          entries: [
            // Local-component constructors: `new Date('2026-03-01')` is UTC
            // midnight, which formatDate() renders as the PREVIOUS day on any
            // machine west of UTC, breaking these assertions there.
            { date: new Date(2026, 2, 1) },
            { date: new Date(2026, 1, 28) },
            { date: new Date(2026, 1, 27) },
          ],
        },
      ]);

      const context = await service.buildContext('user-1', '2026-03-02');

      expect(context.habits[0]).toEqual({
        name: 'Meditate',
        currentStreak: 3,
        doneToday: false,
      });
    });

    it('includes today in the streak when today is done', async () => {
      prisma.habit.findMany.mockResolvedValue([
        {
          name: 'Read',
          entries: [
            { date: new Date(2026, 2, 2) },
            { date: new Date(2026, 2, 1) },
          ],
        },
      ]);

      const context = await service.buildContext('user-1', '2026-03-02');

      expect(context.habits[0]).toEqual({
        name: 'Read',
        currentStreak: 2,
        doneToday: true,
      });
    });
  });

  describe('getOrCreateDailyQuote', () => {
    it('returns the cached quote without calling Gemini', async () => {
      prisma.dailyQuote.findUnique.mockResolvedValue({
        text: 'cached line',
        source: 'gemini',
      });

      const quote = await service.getOrCreateDailyQuote('user-1', '2026-03-02');

      expect(quote).toEqual({
        text: 'cached line',
        source: 'gemini',
        fromCache: true,
      });
      expect(gemini.generate).not.toHaveBeenCalled();
      expect(prisma.dailyQuote.upsert).not.toHaveBeenCalled();
    });

    it('generates and caches a Gemini quote on a cache miss', async () => {
      gemini.generate.mockResolvedValue('Day 12 of Meditate. Go.');

      const quote = await service.getOrCreateDailyQuote('user-1', '2026-03-02');

      expect(quote).toEqual({
        text: 'Day 12 of Meditate. Go.',
        source: 'gemini',
        fromCache: false,
      });
      expect(prisma.dailyQuote.upsert).toHaveBeenCalledTimes(1);
    });

    it('falls back to the static pool when Gemini returns null', async () => {
      gemini.generate.mockResolvedValue(null);

      const quote = await service.getOrCreateDailyQuote('user-1', '2026-03-02');

      expect(quote.source).toBe('fallback');
      expect(quote.fromCache).toBe(false);
      expect(FALLBACK_QUOTES).toContain(quote.text);
      expect(prisma.dailyQuote.upsert).toHaveBeenCalledTimes(1);
    });
  });
});
```

- [ ] **Step 2: Run the test and watch it fail**

Run: `cd backend && pnpm test -- quotes.service`
Expected: FAIL — `Cannot find module './quotes.service'`.

- [ ] **Step 3: Implement the service**

Create `backend/src/quotes/quotes.service.ts`:

```ts
import { Injectable } from '@nestjs/common';
import dayjs from 'dayjs';
import { PrismaService } from 'src/prisma.service';
import { computeCurrentStreak } from 'src/utils/streak';
import { toDateOnly } from 'src/utils/timezone';
import { GeminiService } from './gemini.service';
import { pickFallbackQuote } from './fallback-quotes';
import { GeneratedQuote, QuoteContext, QuoteSource } from './quotes.types';

@Injectable()
export class QuotesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly gemini: GeminiService,
  ) {}

  async buildContext(userId: string, localDate: string): Promise<QuoteContext> {
    const habits = await this.prisma.habit.findMany({
      where: { userId, archivedAt: null },
      include: { entries: { orderBy: { date: 'desc' } } },
    });

    const target = dayjs(localDate);

    return {
      habits: habits.map((habit) => {
        const dates = habit.entries.map((entry) => entry.date);
        const doneToday = dates.some((date) => dayjs(date).isSame(target, 'day'));
        // A day not yet checked off must not zero the streak: count back from
        // yesterday when today is still open.
        const streakFrom = doneToday ? target : target.subtract(1, 'day');

        return {
          name: habit.name,
          currentStreak: computeCurrentStreak(dates, streakFrom),
          doneToday,
        };
      }),
    };
  }

  async getOrCreateDailyQuote(
    userId: string,
    localDate: string,
  ): Promise<GeneratedQuote> {
    const date = toDateOnly(localDate);

    const cached = await this.prisma.dailyQuote.findUnique({
      where: { userId_localDate: { userId, localDate: date } },
    });

    if (cached) {
      return {
        text: cached.text,
        source: cached.source as QuoteSource,
        fromCache: true,
      };
    }

    const context = await this.buildContext(userId, localDate);
    const generated = await this.gemini.generate(context);

    const text = generated ?? pickFallbackQuote(userId, localDate);
    const source: QuoteSource = generated ? 'gemini' : 'fallback';

    await this.prisma.dailyQuote.upsert({
      where: { userId_localDate: { userId, localDate: date } },
      create: { userId, localDate: date, text, source },
      update: {},
    });

    return { text, source, fromCache: false };
  }
}
```

- [ ] **Step 4: Create the module**

Create `backend/src/quotes/quotes.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { QuotesService } from './quotes.service';
import { GeminiService } from './gemini.service';
import { PrismaService } from 'src/prisma.service';

@Module({
  providers: [QuotesService, GeminiService, PrismaService],
  exports: [QuotesService],
})
export class QuotesModule {}
```

- [ ] **Step 5: Run the test and watch it pass**

Run: `cd backend && pnpm test -- quotes.service`
Expected: PASS, 5 tests.

- [ ] **Step 6: Commit**

```bash
cd backend
git add src/quotes/quotes.service.ts src/quotes/quotes.service.spec.ts src/quotes/quotes.module.ts
git commit -m "feat(quotes): cache one personalized quote per user per day with fallback"
```

---

## Task 7: FCM sender

Wraps `firebase-admin`. Returns dead tokens rather than deleting them itself, so this service stays free of database concerns and the caller decides what cleanup means.

**Files:**
- Create: `backend/src/notifications/fcm.service.ts`
- Test: `backend/src/notifications/fcm.service.spec.ts`
- Modify: `backend/package.json` (dependency)

**Interfaces:**
- Consumes: `ConfigService`, env `FIREBASE_SERVICE_ACCOUNT_BASE64`.
- Produces: `FcmService.sendToTokens(tokens: string[], title: string, body: string): Promise<{ successCount: number; invalidTokens: string[] }>`

- [ ] **Step 1: Install the SDK**

Run: `cd backend && pnpm add firebase-admin`
Expected: `firebase-admin` appears under `dependencies`.

- [ ] **Step 2: Write the failing test**

Create `backend/src/notifications/fcm.service.spec.ts`:

```ts
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { FcmService } from './fcm.service';

const mockSendEachForMulticast = jest.fn();
const mockInitializeApp = jest.fn(() => ({ name: 'test-app' }));

jest.mock('firebase-admin', () => ({
  apps: [],
  initializeApp: (...args: unknown[]) => mockInitializeApp(...args),
  credential: { cert: jest.fn((account: unknown) => account) },
  messaging: () => ({ sendEachForMulticast: mockSendEachForMulticast }),
}));

const serviceAccount = Buffer.from(
  JSON.stringify({ project_id: 'demo', client_email: 'a@b.com', private_key: 'k' }),
).toString('base64');

const buildService = async (env: Record<string, string | undefined>) => {
  const module: TestingModule = await Test.createTestingModule({
    providers: [
      FcmService,
      { provide: ConfigService, useValue: { get: (key: string) => env[key] } },
    ],
  }).compile();
  const service = module.get<FcmService>(FcmService);
  service.onModuleInit();
  return service;
};

describe('FcmService', () => {
  beforeEach(() => {
    mockSendEachForMulticast.mockReset();
    mockInitializeApp.mockClear();
  });

  it('reports the success count when every token accepts', async () => {
    mockSendEachForMulticast.mockResolvedValue({
      successCount: 2,
      responses: [{ success: true }, { success: true }],
    });
    const service = await buildService({
      FIREBASE_SERVICE_ACCOUNT_BASE64: serviceAccount,
    });

    await expect(service.sendToTokens(['a', 'b'], 'Title', 'Body')).resolves.toEqual({
      successCount: 2,
      invalidTokens: [],
    });
  });

  it('returns unregistered tokens so the caller can delete them', async () => {
    mockSendEachForMulticast.mockResolvedValue({
      successCount: 1,
      responses: [
        { success: true },
        {
          success: false,
          error: { code: 'messaging/registration-token-not-registered' },
        },
      ],
    });
    const service = await buildService({
      FIREBASE_SERVICE_ACCOUNT_BASE64: serviceAccount,
    });

    await expect(service.sendToTokens(['good', 'dead'], 'T', 'B')).resolves.toEqual({
      successCount: 1,
      invalidTokens: ['dead'],
    });
  });

  it('does not treat a transient failure as a dead token', async () => {
    mockSendEachForMulticast.mockResolvedValue({
      successCount: 0,
      responses: [{ success: false, error: { code: 'messaging/internal-error' } }],
    });
    const service = await buildService({
      FIREBASE_SERVICE_ACCOUNT_BASE64: serviceAccount,
    });

    await expect(service.sendToTokens(['flaky'], 'T', 'B')).resolves.toEqual({
      successCount: 0,
      invalidTokens: [],
    });
  });

  it('no-ops on an empty token list', async () => {
    const service = await buildService({
      FIREBASE_SERVICE_ACCOUNT_BASE64: serviceAccount,
    });

    await expect(service.sendToTokens([], 'T', 'B')).resolves.toEqual({
      successCount: 0,
      invalidTokens: [],
    });
    expect(mockSendEachForMulticast).not.toHaveBeenCalled();
  });

  it('stays inert when no credentials are configured', async () => {
    const service = await buildService({});

    await expect(service.sendToTokens(['a'], 'T', 'B')).resolves.toEqual({
      successCount: 0,
      invalidTokens: [],
    });
    expect(mockInitializeApp).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 3: Run the test and watch it fail**

Run: `cd backend && pnpm test -- fcm.service`
Expected: FAIL — `Cannot find module './fcm.service'`.

- [ ] **Step 4: Implement the service**

Create `backend/src/notifications/fcm.service.ts`:

```ts
import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';

const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

// sendEachForMulticast accepts at most 500 tokens per call.
const FCM_BATCH_LIMIT = 500;

export interface FcmSendResult {
  successCount: number;
  invalidTokens: string[];
}

@Injectable()
export class FcmService implements OnModuleInit {
  private readonly logger = new Logger(FcmService.name);
  private app: admin.app.App | null = null;

  constructor(private readonly config: ConfigService) {}

  onModuleInit(): void {
    const encoded = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_BASE64');

    if (!encoded) {
      this.logger.warn(
        'FIREBASE_SERVICE_ACCOUNT_BASE64 is not set; push notifications are disabled.',
      );
      return;
    }

    try {
      const serviceAccount = JSON.parse(
        Buffer.from(encoded, 'base64').toString('utf8'),
      ) as admin.ServiceAccount;

      this.app = admin.apps.length
        ? (admin.apps[0] as admin.app.App)
        : admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
          });
    } catch (error) {
      this.logger.error(
        `Failed to initialise Firebase Admin: ${(error as Error).message}`,
      );
    }
  }

  async sendToTokens(
    tokens: string[],
    title: string,
    body: string,
  ): Promise<FcmSendResult> {
    if (!this.app || tokens.length === 0) {
      return { successCount: 0, invalidTokens: [] };
    }

    const batch = tokens.slice(0, FCM_BATCH_LIMIT);

    const response = await admin.messaging(this.app).sendEachForMulticast({
      tokens: batch,
      notification: { title, body },
    });

    const invalidTokens: string[] = [];

    response.responses.forEach((result, index) => {
      if (result.success) return;

      const code = (result.error as { code?: string } | undefined)?.code;
      if (code && DEAD_TOKEN_CODES.has(code)) {
        invalidTokens.push(batch[index]);
      } else {
        this.logger.warn(`FCM send failed for a token: ${code ?? 'unknown'}`);
      }
    });

    return { successCount: response.successCount, invalidTokens };
  }
}
```

- [ ] **Step 5: Run the test and watch it pass**

Run: `cd backend && pnpm test -- fcm.service`
Expected: PASS, 5 tests.

- [ ] **Step 6: Commit**

```bash
cd backend
git add package.json pnpm-lock.yaml src/notifications/fcm.service.ts src/notifications/fcm.service.spec.ts
git commit -m "feat(notifications): add fcm sender with dead token reporting"
```

---

## Task 8: Device tokens, settings, and the REST surface

The endpoints a mobile client will eventually call. Registering a token **upserts on the token itself**, so a phone that signs out and back in as a different user is reassigned rather than duplicated — otherwise the previous account keeps pushing to a device it no longer owns.

**Files:**
- Create: `backend/src/notifications/dto/register-device-token.dto.ts`
- Create: `backend/src/notifications/dto/delete-device-token.dto.ts`
- Create: `backend/src/notifications/dto/update-notification-settings.dto.ts`
- Create: `backend/src/notifications/device-tokens.service.ts`
- Create: `backend/src/notifications/notification-settings.service.ts`
- Create: `backend/src/notifications/notifications.controller.ts`
- Test: `backend/src/notifications/device-tokens.service.spec.ts`
- Test: `backend/src/notifications/notification-settings.service.spec.ts`

**Interfaces:**
- Consumes: `PrismaService`, `isValidTimezone` (Task 2), `JwtAuthGuard`, `CurrentUser`.
- Produces:
  - `DeviceTokensService.register(userId, dto)`, `.listTokens(userId): Promise<string[]>`, `.remove(userId, token)`, `.deleteTokens(tokens: string[]): Promise<void>`
  - `NotificationSettingsService.getOrCreate(userId)`, `.update(userId, dto)`
  - `NotificationsController` mounted at `/notifications`

- [ ] **Step 1: Write the DTOs**

Create `backend/src/notifications/dto/register-device-token.dto.ts`:

```ts
import { ApiProperty } from '@nestjs/swagger';
import { IsIn, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class RegisterDeviceTokenDto {
  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  token: string;

  @ApiProperty({ required: false, enum: ['android', 'ios'] })
  @IsOptional()
  @IsIn(['android', 'ios'])
  platform?: string;
}
```

Create `backend/src/notifications/dto/delete-device-token.dto.ts`:

```ts
import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class DeleteDeviceTokenDto {
  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  token: string;
}
```

Create `backend/src/notifications/dto/update-notification-settings.dto.ts`:

```ts
import { ApiProperty } from '@nestjs/swagger';
import { IsBoolean, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class UpdateNotificationSettingsDto {
  @ApiProperty({ required: false })
  @IsOptional()
  @IsBoolean()
  enabled?: boolean;

  @ApiProperty({ required: false, minimum: 0, maximum: 23 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(23)
  reminderHour?: number;

  @ApiProperty({ required: false, example: 'Asia/Ho_Chi_Minh' })
  @IsOptional()
  @IsString()
  timezone?: string;
}
```

- [ ] **Step 2: Write the failing service tests**

Create `backend/src/notifications/device-tokens.service.spec.ts`:

```ts
import { Test, TestingModule } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { DeviceTokensService } from './device-tokens.service';
import { PrismaService } from 'src/prisma.service';

describe('DeviceTokensService', () => {
  let service: DeviceTokensService;
  let prisma: {
    deviceToken: {
      upsert: jest.Mock;
      findMany: jest.Mock;
      deleteMany: jest.Mock;
    };
  };

  beforeEach(async () => {
    prisma = {
      deviceToken: {
        upsert: jest.fn().mockResolvedValue({ id: 'dt-1' }),
        findMany: jest.fn().mockResolvedValue([]),
        deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DeviceTokensService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get<DeviceTokensService>(DeviceTokensService);
  });

  it('reassigns an existing token to the registering user', async () => {
    await service.register('user-2', { token: 'fcm-abc' });

    expect(prisma.deviceToken.upsert).toHaveBeenCalledWith({
      where: { token: 'fcm-abc' },
      create: { userId: 'user-2', token: 'fcm-abc', platform: 'android' },
      update: { userId: 'user-2', platform: 'android' },
    });
  });

  it('lists only the token strings for a user', async () => {
    prisma.deviceToken.findMany.mockResolvedValue([
      { token: 'a' },
      { token: 'b' },
    ]);

    await expect(service.listTokens('user-1')).resolves.toEqual(['a', 'b']);
  });

  it('scopes removal to the owning user', async () => {
    await service.remove('user-1', 'fcm-abc');

    expect(prisma.deviceToken.deleteMany).toHaveBeenCalledWith({
      where: { userId: 'user-1', token: 'fcm-abc' },
    });
  });

  it('throws 404 when removing a token the user does not own', async () => {
    prisma.deviceToken.deleteMany.mockResolvedValue({ count: 0 });

    await expect(service.remove('user-1', 'nope')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('skips the database entirely when there are no dead tokens', async () => {
    await service.deleteTokens([]);

    expect(prisma.deviceToken.deleteMany).not.toHaveBeenCalled();
  });
});
```

Create `backend/src/notifications/notification-settings.service.spec.ts`:

```ts
import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { NotificationSettingsService } from './notification-settings.service';
import { PrismaService } from 'src/prisma.service';

describe('NotificationSettingsService', () => {
  let service: NotificationSettingsService;
  let prisma: {
    notificationSetting: { upsert: jest.Mock; update: jest.Mock };
  };

  beforeEach(async () => {
    prisma = {
      notificationSetting: {
        upsert: jest.fn().mockResolvedValue({
          userId: 'user-1',
          enabled: true,
          reminderHour: 8,
          timezone: 'UTC',
        }),
        update: jest.fn().mockResolvedValue({}),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        NotificationSettingsService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get<NotificationSettingsService>(
      NotificationSettingsService,
    );
  });

  it('creates default settings on first read', async () => {
    await service.getOrCreate('user-1');

    expect(prisma.notificationSetting.upsert).toHaveBeenCalledWith({
      where: { userId: 'user-1' },
      create: { userId: 'user-1' },
      update: {},
    });
  });

  it('rejects an unknown IANA timezone before touching the database', async () => {
    await expect(
      service.update('user-1', { timezone: 'Mars/Olympus_Mons' }),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(prisma.notificationSetting.update).not.toHaveBeenCalled();
  });

  it('persists a valid update', async () => {
    await service.update('user-1', {
      reminderHour: 6,
      timezone: 'Asia/Ho_Chi_Minh',
    });

    expect(prisma.notificationSetting.update).toHaveBeenCalledWith({
      where: { userId: 'user-1' },
      data: { reminderHour: 6, timezone: 'Asia/Ho_Chi_Minh' },
    });
  });
});
```

- [ ] **Step 3: Run the tests and watch them fail**

Run: `cd backend && pnpm test -- device-tokens.service notification-settings.service`
Expected: FAIL — `Cannot find module './device-tokens.service'`.

- [ ] **Step 4: Implement DeviceTokensService**

Create `backend/src/notifications/device-tokens.service.ts`:

```ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from 'src/prisma.service';
import { RegisterDeviceTokenDto } from './dto/register-device-token.dto';

const DEFAULT_PLATFORM = 'android';

@Injectable()
export class DeviceTokensService {
  constructor(private readonly prisma: PrismaService) {}

  async register(userId: string, dto: RegisterDeviceTokenDto) {
    const platform = dto.platform ?? DEFAULT_PLATFORM;

    // Upsert on the token, not on (userId, token): a device that switches
    // accounts must move to the new owner rather than notify both.
    return await this.prisma.deviceToken.upsert({
      where: { token: dto.token },
      create: { userId, token: dto.token, platform },
      update: { userId, platform },
    });
  }

  async listTokens(userId: string): Promise<string[]> {
    const rows = await this.prisma.deviceToken.findMany({
      where: { userId },
      select: { token: true },
    });

    return rows.map((row) => row.token);
  }

  async remove(userId: string, token: string) {
    const result = await this.prisma.deviceToken.deleteMany({
      where: { userId, token },
    });

    if (result.count === 0) {
      throw new NotFoundException('Device token not found!');
    }

    return { code: 200, message: 'Device token removed' };
  }

  async deleteTokens(tokens: string[]): Promise<void> {
    if (tokens.length === 0) return;

    await this.prisma.deviceToken.deleteMany({
      where: { token: { in: tokens } },
    });
  }
}
```

- [ ] **Step 5: Implement NotificationSettingsService**

Create `backend/src/notifications/notification-settings.service.ts`:

```ts
import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from 'src/prisma.service';
import { isValidTimezone } from 'src/utils/timezone';
import { UpdateNotificationSettingsDto } from './dto/update-notification-settings.dto';

@Injectable()
export class NotificationSettingsService {
  constructor(private readonly prisma: PrismaService) {}

  async getOrCreate(userId: string) {
    return await this.prisma.notificationSetting.upsert({
      where: { userId },
      create: { userId },
      update: {},
    });
  }

  async update(userId: string, dto: UpdateNotificationSettingsDto) {
    if (dto.timezone && !isValidTimezone(dto.timezone)) {
      throw new BadRequestException(`Unknown IANA timezone: ${dto.timezone}`);
    }

    await this.getOrCreate(userId);

    return await this.prisma.notificationSetting.update({
      where: { userId },
      data: { ...dto },
    });
  }
}
```

- [ ] **Step 6: Implement the controller**

Create `backend/src/notifications/notifications.controller.ts`:

```ts
import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiCreatedResponse, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from 'src/auth/jwt-auth.guard';
import { CurrentUser } from 'src/common/decorators';
import { DeviceTokensService } from './device-tokens.service';
import { NotificationSettingsService } from './notification-settings.service';
import { RegisterDeviceTokenDto } from './dto/register-device-token.dto';
import { DeleteDeviceTokenDto } from './dto/delete-device-token.dto';
import { UpdateNotificationSettingsDto } from './dto/update-notification-settings.dto';

@Controller('notifications')
@ApiTags('Notifications')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(
    private readonly deviceTokens: DeviceTokensService,
    private readonly settings: NotificationSettingsService,
  ) {}

  @Post('device-tokens')
  @ApiCreatedResponse({ description: 'Device token registered.' })
  async registerDeviceToken(
    @CurrentUser('id') userId: string,
    @Body() dto: RegisterDeviceTokenDto,
  ) {
    return await this.deviceTokens.register(userId, dto);
  }

  @Delete('device-tokens')
  @HttpCode(HttpStatus.OK)
  async removeDeviceToken(
    @CurrentUser('id') userId: string,
    @Body() dto: DeleteDeviceTokenDto,
  ) {
    return await this.deviceTokens.remove(userId, dto.token);
  }

  @Get('settings')
  async getSettings(@CurrentUser('id') userId: string) {
    return await this.settings.getOrCreate(userId);
  }

  @Put('settings')
  async updateSettings(
    @CurrentUser('id') userId: string,
    @Body() dto: UpdateNotificationSettingsDto,
  ) {
    return await this.settings.update(userId, dto);
  }
}
```

- [ ] **Step 7: Run the tests and watch them pass**

Run: `cd backend && pnpm test -- device-tokens.service notification-settings.service`
Expected: PASS, 8 tests.

- [ ] **Step 8: Commit**

```bash
cd backend
git add src/notifications/dto src/notifications/device-tokens.service.ts src/notifications/device-tokens.service.spec.ts src/notifications/notification-settings.service.ts src/notifications/notification-settings.service.spec.ts src/notifications/notifications.controller.ts
git commit -m "feat(notifications): add device token and settings endpoints"
```

---

## Task 9: The daily run

The orchestration, and the only place that knows both halves. Two behaviours matter and are both tested: a user whose local hour has not arrived is skipped without any Gemini call, and Gemini calls are spaced by `GEMINI_MIN_INTERVAL_MS` so a batch cannot trip the 10 RPM free-tier ceiling. A cached quote needs no call, so it needs no delay.

**Files:**
- Create: `backend/src/utils/sleep.ts`
- Modify: `backend/src/utils/index.ts`
- Create: `backend/src/notifications/notifications.service.ts`
- Test: `backend/src/notifications/notifications.service.spec.ts`

**Interfaces:**
- Consumes: `PrismaService`, `QuotesService.getOrCreateDailyQuote`, `FcmService.sendToTokens`, `DeviceTokensService.listTokens`/`.deleteTokens`, `ConfigService`, `localHourFor`/`localDateFor`/`isValidTimezone`/`toDateOnly`.
- Produces:
  - `interface DailyRunSummary { considered, due, sent, skippedNoTokens, skippedAlreadySent, skippedBadTimezone: number }`
  - `NotificationsService.runDueNotifications(now: Date): Promise<DailyRunSummary>`

- [ ] **Step 1: Add the sleep helper**

Create `backend/src/utils/sleep.ts`:

```ts
export const sleep = (ms: number): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, ms));
```

Then add its re-export to `backend/src/utils/index.ts`:

```ts
export * from './sleep';
```

- [ ] **Step 2: Write the failing test**

Create `backend/src/notifications/notifications.service.spec.ts`:

```ts
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { NotificationsService } from './notifications.service';
import { DeviceTokensService } from './device-tokens.service';
import { FcmService } from './fcm.service';
import { QuotesService } from 'src/quotes/quotes.service';
import { PrismaService } from 'src/prisma.service';

// 2026-03-01T22:00:00Z is 05:00 in Asia/Ho_Chi_Minh and 22:00 in UTC.
const NOW = new Date('2026-03-01T22:00:00.000Z');

describe('NotificationsService', () => {
  let service: NotificationsService;
  let prisma: {
    notificationSetting: { findMany: jest.Mock };
    dailyQuote: { findUnique: jest.Mock; update: jest.Mock };
  };
  let quotes: { getOrCreateDailyQuote: jest.Mock };
  let fcm: { sendToTokens: jest.Mock };
  let deviceTokens: { listTokens: jest.Mock; deleteTokens: jest.Mock };

  beforeEach(async () => {
    prisma = {
      notificationSetting: { findMany: jest.fn().mockResolvedValue([]) },
      dailyQuote: {
        findUnique: jest.fn().mockResolvedValue(null),
        update: jest.fn().mockResolvedValue({}),
      },
    };
    quotes = {
      getOrCreateDailyQuote: jest.fn().mockResolvedValue({
        text: 'Day 12 of Meditate. Go.',
        source: 'gemini',
        fromCache: false,
      }),
    };
    fcm = {
      sendToTokens: jest
        .fn()
        .mockResolvedValue({ successCount: 1, invalidTokens: [] }),
    };
    deviceTokens = {
      listTokens: jest.fn().mockResolvedValue(['fcm-abc']),
      deleteTokens: jest.fn().mockResolvedValue(undefined),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        NotificationsService,
        { provide: PrismaService, useValue: prisma },
        { provide: QuotesService, useValue: quotes },
        { provide: FcmService, useValue: fcm },
        { provide: DeviceTokensService, useValue: deviceTokens },
        {
          provide: ConfigService,
          // No pacing delay in tests.
          useValue: { get: () => '0' },
        },
      ],
    }).compile();

    service = module.get<NotificationsService>(NotificationsService);
  });

  it('sends to a user whose local hour matches their reminder hour', async () => {
    prisma.notificationSetting.findMany.mockResolvedValue([
      {
        userId: 'user-1',
        enabled: true,
        reminderHour: 5,
        timezone: 'Asia/Ho_Chi_Minh',
      },
    ]);

    const summary = await service.runDueNotifications(NOW);

    expect(summary.due).toBe(1);
    expect(summary.sent).toBe(1);
    // Local date has already rolled over to the 2nd in UTC+7.
    expect(quotes.getOrCreateDailyQuote).toHaveBeenCalledWith(
      'user-1',
      '2026-03-02',
    );
    expect(fcm.sendToTokens).toHaveBeenCalledWith(
      ['fcm-abc'],
      expect.any(String),
      'Day 12 of Meditate. Go.',
    );
  });

  it('skips a user whose local hour has not arrived, without calling Gemini', async () => {
    prisma.notificationSetting.findMany.mockResolvedValue([
      {
        userId: 'user-1',
        enabled: true,
        reminderHour: 9,
        timezone: 'Asia/Ho_Chi_Minh',
      },
    ]);

    const summary = await service.runDueNotifications(NOW);

    expect(summary.due).toBe(0);
    expect(summary.sent).toBe(0);
    expect(quotes.getOrCreateDailyQuote).not.toHaveBeenCalled();
    expect(fcm.sendToTokens).not.toHaveBeenCalled();
  });

  it('skips a due user with no registered devices', async () => {
    prisma.notificationSetting.findMany.mockResolvedValue([
      { userId: 'user-1', enabled: true, reminderHour: 22, timezone: 'UTC' },
    ]);
    deviceTokens.listTokens.mockResolvedValue([]);

    const summary = await service.runDueNotifications(NOW);

    expect(summary.due).toBe(1);
    expect(summary.skippedNoTokens).toBe(1);
    expect(quotes.getOrCreateDailyQuote).not.toHaveBeenCalled();
  });

  it('does not push twice when today was already sent', async () => {
    prisma.notificationSetting.findMany.mockResolvedValue([
      { userId: 'user-1', enabled: true, reminderHour: 22, timezone: 'UTC' },
    ]);
    prisma.dailyQuote.findUnique.mockResolvedValue({
      text: 'already sent',
      source: 'gemini',
      sentAt: new Date('2026-03-01T22:00:05.000Z'),
    });

    const summary = await service.runDueNotifications(NOW);

    expect(summary.skippedAlreadySent).toBe(1);
    expect(fcm.sendToTokens).not.toHaveBeenCalled();
  });

  it('deletes tokens FCM reports as dead', async () => {
    prisma.notificationSetting.findMany.mockResolvedValue([
      { userId: 'user-1', enabled: true, reminderHour: 22, timezone: 'UTC' },
    ]);
    deviceTokens.listTokens.mockResolvedValue(['good', 'dead']);
    fcm.sendToTokens.mockResolvedValue({
      successCount: 1,
      invalidTokens: ['dead'],
    });

    await service.runDueNotifications(NOW);

    expect(deviceTokens.deleteTokens).toHaveBeenCalledWith(['dead']);
  });

  it('skips a corrupt timezone instead of throwing', async () => {
    prisma.notificationSetting.findMany.mockResolvedValue([
      {
        userId: 'user-1',
        enabled: true,
        reminderHour: 22,
        timezone: 'Mars/Olympus_Mons',
      },
    ]);

    const summary = await service.runDueNotifications(NOW);

    expect(summary.skippedBadTimezone).toBe(1);
    expect(summary.sent).toBe(0);
  });
});
```

- [ ] **Step 3: Run the test and watch it fail**

Run: `cd backend && pnpm test -- notifications.service`
Expected: FAIL — `Cannot find module './notifications.service'`.

- [ ] **Step 4: Implement the service**

Create `backend/src/notifications/notifications.service.ts`:

```ts
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from 'src/prisma.service';
import { QuotesService } from 'src/quotes/quotes.service';
import { sleep } from 'src/utils/sleep';
import {
  isValidTimezone,
  localDateFor,
  localHourFor,
  toDateOnly,
} from 'src/utils/timezone';
import { DeviceTokensService } from './device-tokens.service';
import { FcmService } from './fcm.service';

export const NOTIFICATION_TITLE = 'One Percent';
export const DEFAULT_GEMINI_MIN_INTERVAL_MS = 7000;

export interface DailyRunSummary {
  considered: number;
  due: number;
  sent: number;
  skippedNoTokens: number;
  skippedAlreadySent: number;
  skippedBadTimezone: number;
}

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly quotes: QuotesService,
    private readonly fcm: FcmService,
    private readonly deviceTokens: DeviceTokensService,
    private readonly config: ConfigService,
  ) {}

  async runDueNotifications(now: Date): Promise<DailyRunSummary> {
    const settings = await this.prisma.notificationSetting.findMany({
      where: { enabled: true },
    });

    const summary: DailyRunSummary = {
      considered: settings.length,
      due: 0,
      sent: 0,
      skippedNoTokens: 0,
      skippedAlreadySent: 0,
      skippedBadTimezone: 0,
    };

    const minIntervalMs = Number(
      this.config.get<string>('GEMINI_MIN_INTERVAL_MS') ??
        DEFAULT_GEMINI_MIN_INTERVAL_MS,
    );
    let hasCalledGemini = false;

    for (const setting of settings) {
      if (!isValidTimezone(setting.timezone)) {
        this.logger.warn(
          `User ${setting.userId} has an unknown timezone "${setting.timezone}"; skipping.`,
        );
        summary.skippedBadTimezone++;
        continue;
      }

      if (localHourFor(setting.timezone, now) !== setting.reminderHour) continue;
      summary.due++;

      const localDate = localDateFor(setting.timezone, now);
      const date = toDateOnly(localDate);

      const existing = await this.prisma.dailyQuote.findUnique({
        where: { userId_localDate: { userId: setting.userId, localDate: date } },
      });

      if (existing?.sentAt) {
        summary.skippedAlreadySent++;
        continue;
      }

      const tokens = await this.deviceTokens.listTokens(setting.userId);

      if (tokens.length === 0) {
        summary.skippedNoTokens++;
        continue;
      }

      // Only an uncached quote costs a Gemini call, so only that case needs
      // pacing against the free tier's requests-per-minute ceiling.
      const willCallGemini = !existing;

      if (willCallGemini && hasCalledGemini && minIntervalMs > 0) {
        await sleep(minIntervalMs);
      }

      const quote = await this.quotes.getOrCreateDailyQuote(
        setting.userId,
        localDate,
      );

      if (willCallGemini) hasCalledGemini = true;

      const result = await this.fcm.sendToTokens(
        tokens,
        NOTIFICATION_TITLE,
        quote.text,
      );

      await this.deviceTokens.deleteTokens(result.invalidTokens);

      if (result.successCount > 0) {
        await this.prisma.dailyQuote.update({
          where: {
            userId_localDate: { userId: setting.userId, localDate: date },
          },
          data: { sentAt: now },
        });
        summary.sent++;
      }
    }

    return summary;
  }
}
```

- [ ] **Step 5: Run the test and watch it pass**

Run: `cd backend && pnpm test -- notifications.service`
Expected: PASS, 6 tests.

- [ ] **Step 6: Commit**

```bash
cd backend
git add src/utils/sleep.ts src/utils/index.ts src/notifications/notifications.service.ts src/notifications/notifications.service.spec.ts
git commit -m "feat(notifications): orchestrate the daily quote push run"
```

---

## Task 10: Scheduler and application wiring

The cron is guarded by `NOTIFICATIONS_ENABLED` so that a dev machine, a test run, or a review app never pushes to real devices by accident. Turning it on is a deliberate act.

**Files:**
- Create: `backend/src/notifications/notifications.scheduler.ts`
- Create: `backend/src/notifications/notifications.module.ts`
- Test: `backend/src/notifications/notifications.scheduler.spec.ts`
- Modify: `backend/src/app.module.ts`
- Modify: `backend/.env`
- Modify: `backend/package.json` (dependency)

**Interfaces:**
- Consumes: `NotificationsService.runDueNotifications`, `ConfigService`, `QuotesModule`.
- Produces: `NotificationsScheduler.handleHourlyRun()`, `NotificationsModule`.

- [ ] **Step 1: Install the scheduler package**

Run: `cd backend && pnpm add @nestjs/schedule`
Expected: `@nestjs/schedule` appears under `dependencies`.

- [ ] **Step 2: Write the failing test**

Create `backend/src/notifications/notifications.scheduler.spec.ts`:

```ts
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { NotificationsScheduler } from './notifications.scheduler';
import { NotificationsService } from './notifications.service';

describe('NotificationsScheduler', () => {
  const buildScheduler = async (enabled: string | undefined) => {
    const notifications = {
      runDueNotifications: jest.fn().mockResolvedValue({
        considered: 0,
        due: 0,
        sent: 0,
        skippedNoTokens: 0,
        skippedAlreadySent: 0,
        skippedBadTimezone: 0,
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        NotificationsScheduler,
        { provide: NotificationsService, useValue: notifications },
        {
          provide: ConfigService,
          useValue: { get: () => enabled },
        },
      ],
    }).compile();

    return {
      scheduler: module.get<NotificationsScheduler>(NotificationsScheduler),
      notifications,
    };
  };

  it('does nothing unless notifications are explicitly enabled', async () => {
    const { scheduler, notifications } = await buildScheduler(undefined);

    await scheduler.handleHourlyRun();

    expect(notifications.runDueNotifications).not.toHaveBeenCalled();
  });

  it('runs when explicitly enabled', async () => {
    const { scheduler, notifications } = await buildScheduler('true');

    await scheduler.handleHourlyRun();

    expect(notifications.runDueNotifications).toHaveBeenCalledTimes(1);
    expect(notifications.runDueNotifications).toHaveBeenCalledWith(
      expect.any(Date),
    );
  });
});
```

- [ ] **Step 3: Run the test and watch it fail**

Run: `cd backend && pnpm test -- notifications.scheduler`
Expected: FAIL — `Cannot find module './notifications.scheduler'`.

- [ ] **Step 4: Implement the scheduler**

Create `backend/src/notifications/notifications.scheduler.ts`:

```ts
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron, CronExpression } from '@nestjs/schedule';
import { NotificationsService } from './notifications.service';

@Injectable()
export class NotificationsScheduler {
  private readonly logger = new Logger(NotificationsScheduler.name);

  constructor(
    private readonly notifications: NotificationsService,
    private readonly config: ConfigService,
  ) {}

  @Cron(CronExpression.EVERY_HOUR, { name: 'daily-motivation-push' })
  async handleHourlyRun(): Promise<void> {
    if (this.config.get<string>('NOTIFICATIONS_ENABLED') !== 'true') return;

    try {
      const summary = await this.notifications.runDueNotifications(new Date());
      this.logger.log(`Daily push run: ${JSON.stringify(summary)}`);
    } catch (error) {
      this.logger.error(
        `Daily push run failed: ${(error as Error).message}`,
      );
    }
  }
}
```

- [ ] **Step 5: Create the module**

Create `backend/src/notifications/notifications.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { QuotesModule } from 'src/quotes/quotes.module';
import { PrismaService } from 'src/prisma.service';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { NotificationsScheduler } from './notifications.scheduler';
import { DeviceTokensService } from './device-tokens.service';
import { NotificationSettingsService } from './notification-settings.service';
import { FcmService } from './fcm.service';

@Module({
  imports: [QuotesModule],
  controllers: [NotificationsController],
  providers: [
    NotificationsService,
    NotificationsScheduler,
    DeviceTokensService,
    NotificationSettingsService,
    FcmService,
    PrismaService,
  ],
})
export class NotificationsModule {}
```

- [ ] **Step 6: Register everything in AppModule**

Replace the contents of `backend/src/app.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { ConfigModule } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import { AuthModule } from './auth/auth.module';
import { HabitModule } from './habit/habit.module';
import { EntriesModule } from './entries/entries.module';
import { QuotesModule } from './quotes/quotes.module';
import { NotificationsModule } from './notifications/notifications.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    ScheduleModule.forRoot(),
    AuthModule,
    HabitModule,
    EntriesModule,
    QuotesModule,
    NotificationsModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
```

- [ ] **Step 7: Add the new environment variables**

Append to `backend/.env` (real values, not placeholders — see the Environment Variables section at the end of this plan for how to obtain each one):

```
GEMINI_API_KEY=
GEMINI_MODEL=gemini-2.5-flash
GEMINI_MIN_INTERVAL_MS=7000
FIREBASE_SERVICE_ACCOUNT_BASE64=
NOTIFICATIONS_ENABLED=false
```

Leave `NOTIFICATIONS_ENABLED=false` until Task 11 passes and you are ready for the manual push check.

- [ ] **Step 8: Run the test and the whole suite**

Run: `cd backend && pnpm test`
Expected: PASS — every spec from Tasks 1–10 green (41 tests across 10 suites).

- [ ] **Step 9: Verify the app still boots**

Run: `cd backend && pnpm build`
Expected: exit code 0, no TypeScript errors.

- [ ] **Step 10: Commit**

```bash
cd backend
git add package.json pnpm-lock.yaml src/notifications/notifications.scheduler.ts src/notifications/notifications.scheduler.spec.ts src/notifications/notifications.module.ts src/app.module.ts
git commit -m "feat(notifications): schedule the hourly push run behind an env flag"
```

---

## Task 11: End-to-end test of the REST surface

Proves the guard, the DTO validation, and ownership all behave through a real HTTP stack. **Requires a running Postgres reachable via `DATABASE_URL`** and the Task 3 migration applied.

**Files:**
- Create: `backend/test/notifications.e2e-spec.ts`

**Interfaces:**
- Consumes: `AppModule`, the `/auth/register` endpoint, all four `/notifications` routes.
- Produces: nothing other tasks depend on.

- [ ] **Step 1: Write the failing test**

Create `backend/test/notifications.e2e-spec.ts`:

```ts
import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from './../src/app.module';
import { HttpExceptionFilter } from './../src/common/filters/all-exceptions.filter';

describe('Notifications (e2e)', () => {
  let app: INestApplication<App>;
  let accessToken: string;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalFilters(new HttpExceptionFilter());
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();

    const email = `notif-${Date.now()}@example.com`;
    const registered = await request(app.getHttpServer())
      .post('/auth/register')
      .send({ email, password: 'password123' })
      .expect(201);

    accessToken = registered.body.accessToken;
  });

  afterAll(async () => {
    await app.close();
  });

  const auth = () => ({ Authorization: `Bearer ${accessToken}` });

  it('rejects an unauthenticated settings read', async () => {
    await request(app.getHttpServer()).get('/notifications/settings').expect(401);
  });

  it('accepts the token issued by register', async () => {
    expect(accessToken).toBeDefined();
    await request(app.getHttpServer())
      .get('/notifications/settings')
      .set(auth())
      .expect(200);
  });

  it('creates default settings on first read', async () => {
    const response = await request(app.getHttpServer())
      .get('/notifications/settings')
      .set(auth())
      .expect(200);

    expect(response.body).toMatchObject({
      enabled: true,
      reminderHour: 8,
      timezone: 'UTC',
    });
  });

  it('updates settings', async () => {
    const response = await request(app.getHttpServer())
      .put('/notifications/settings')
      .set(auth())
      .send({ reminderHour: 6, timezone: 'Asia/Ho_Chi_Minh' })
      .expect(200);

    expect(response.body).toMatchObject({
      reminderHour: 6,
      timezone: 'Asia/Ho_Chi_Minh',
    });
  });

  it('rejects an out-of-range reminder hour', async () => {
    await request(app.getHttpServer())
      .put('/notifications/settings')
      .set(auth())
      .send({ reminderHour: 25 })
      .expect(400);
  });

  it('rejects an unknown timezone', async () => {
    await request(app.getHttpServer())
      .put('/notifications/settings')
      .set(auth())
      .send({ timezone: 'Mars/Olympus_Mons' })
      .expect(400);
  });

  it('registers and then removes a device token', async () => {
    const token = `fcm-test-${Date.now()}`;

    await request(app.getHttpServer())
      .post('/notifications/device-tokens')
      .set(auth())
      .send({ token })
      .expect(201);

    // Re-registering the same token is idempotent, not a duplicate.
    await request(app.getHttpServer())
      .post('/notifications/device-tokens')
      .set(auth())
      .send({ token })
      .expect(201);

    await request(app.getHttpServer())
      .delete('/notifications/device-tokens')
      .set(auth())
      .send({ token })
      .expect(200);

    await request(app.getHttpServer())
      .delete('/notifications/device-tokens')
      .set(auth())
      .send({ token })
      .expect(404);
  });

  it('rejects a device token registration with no token', async () => {
    await request(app.getHttpServer())
      .post('/notifications/device-tokens')
      .set(auth())
      .send({})
      .expect(400);
  });
});
```

- [ ] **Step 2: Run the e2e suite and watch it fail if anything is wrong**

Run: `cd backend && pnpm test:e2e -- notifications`
Expected: PASS, 8 tests. If `/auth/register` returns a token that 401s on `/notifications/settings`, Task 1 was not applied.

- [ ] **Step 3: Commit**

```bash
cd backend
git add test/notifications.e2e-spec.ts
git commit -m "test(notifications): add e2e coverage for the notifications rest surface"
```

---

## Manual Verification (one real push)

Automated tests never touch Firebase or Google. Do this once, by hand, to prove the wiring end to end. No Flutter app is needed.

1. In the [Firebase console](https://console.firebase.google.com/), create a project, then **Project settings → Service accounts → Generate new private key**. Save the JSON outside the repo.
2. Encode it and paste the result into `backend/.env` as `FIREBASE_SERVICE_ACCOUNT_BASE64`:
   ```bash
   base64 -i ~/Downloads/<your-service-account>.json | tr -d '\n'
   ```
3. Get a Gemini API key from [Google AI Studio](https://aistudio.google.com/apikey) and set `GEMINI_API_KEY`.
4. Obtain a real FCM registration token. Without the Flutter app, the quickest source is the Firebase console's **Cloud Messaging → Send test message** flow, which asks for a token from a registered app instance; alternatively register any test Android client. Paste it into the app via:
   ```bash
   curl -X POST http://localhost:3000/notifications/device-tokens \
     -H "Authorization: Bearer <your-access-token>" \
     -H 'Content-Type: application/json' \
     -d '{"token":"<fcm-registration-token>"}'
   ```
5. Set your reminder hour to the *current* hour in your timezone:
   ```bash
   curl -X PUT http://localhost:3000/notifications/settings \
     -H "Authorization: Bearer <your-access-token>" \
     -H 'Content-Type: application/json' \
     -d '{"reminderHour":<current-local-hour>,"timezone":"Asia/Ho_Chi_Minh"}'
   ```
6. Create at least one habit so the prompt has something to personalise with.
7. Set `NOTIFICATIONS_ENABLED=true` in `backend/.env`, restart with `pnpm start:dev`, and wait for the top of the hour.

**Done when:** the device receives a notification titled "One Percent" whose body names one of your habits, and the server logs `Daily push run: {"considered":1,"due":1,"sent":1,...}`. Check the `daily_quotes` row: `source` should be `gemini` and `sentAt` non-null. If `source` is `fallback`, the Gemini call failed — the log line from `GeminiService` says why, and the push still went out, which is the fallback working as designed.

Set `NOTIFICATIONS_ENABLED=false` again when you are done testing.

---

## Environment Variables

Added to `backend/.env` by Task 10. Never commit this file or the service-account JSON.

| Variable | Example | Notes |
|---|---|---|
| `GEMINI_API_KEY` | `AIza...` | From [Google AI Studio](https://aistudio.google.com/apikey). If unset, every quote uses the fallback pool and the app still runs. |
| `GEMINI_MODEL` | `gemini-2.5-flash` | Free tier 10 RPM / 250 RPD. Switch to `gemini-2.5-flash-lite` (15 RPM / 1,000 RPD) if you outgrow it. |
| `GEMINI_MIN_INTERVAL_MS` | `7000` | Minimum gap between Gemini calls in one run — 7s keeps a batch under the 10 RPM ceiling. |
| `FIREBASE_SERVICE_ACCOUNT_BASE64` | `ewogICJ0e...` | Base64 of the service-account JSON. If unset, FCM is inert and nothing is sent. |
| `NOTIFICATIONS_ENABLED` | `false` | Must be exactly `true` for the cron to do anything. Keep `false` in dev and test. |

---

## Out of Scope (deliberate)

- **All Flutter work.** Firebase init, the runtime notification permission, token fetch, and calling `POST /notifications/device-tokens` need an authenticated mobile client, which does not exist until spec Phase 4. That is a separate plan.
- **Refresh-token rotation.** `/auth/refresh` is in the MVP spec but is not implemented today; this feature does not depend on it.
- **The `deleteEntry` ownership hole** described in Design Decisions.
- **Reconciling `/habits` streak semantics** with the spec's stated rule.
- **Retry of a failed send.** A push that fails delivery is not retried until the next day, because the user's reminder hour matches only once per day. `sentAt` stays null, so the failure is visible in the database.
