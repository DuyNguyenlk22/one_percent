# Wiring the Bloom screens to the API

Design for closing the gap documented in [APP_FLOW.md](../../APP_FLOW.md) §8: the
Stitch screens landed ahead of their data layers. `habits/data/` and
`entries/data/` hold only `.gitkeep`, there are no habit providers or use cases,
and four backend defects block the client outright.

## Framing decision

The screens model concepts the schema does not have:

| Screen shows | Backend has |
|---|---|
| Water habit: `1.5L / 2.0L`, "Add 250ml" | boolean check-off, one row per `(habitId, date)` |
| Add Habit: goal, frequency, reminder time | `{ name, color? }` |
| Routines: Sunrise Ritual / Focus Block / Wind Down | no routine or grouping table |
| Insights: best streak, weekly flow, focus-area % | `currentStreak` per habit only |
| Profile: 88% consistency, 14 habits, 28 streak | no aggregate endpoint |

**Decision: fit the UI to the real API.** No Prisma migrations, no new modules.
Anything the API cannot serve is removed from the screen rather than faked.
Extending the schema (quantity habits, routines, schedules) is a separate spec if
it is ever wanted.

Two consequences, both decided:

- **The Routines tab becomes "My Habits"** — a real list backed by `GET /habits`
  with rename, recolour, archive and delete. This is the only consumer of
  `PATCH`/`DELETE /habits/:id`, and the app currently offers no way to edit or
  remove a habit at all. Repurposing the tab closes a real capability gap
  instead of merely filling a screen.
- **Insights and Profile compute client-side.** `GET /habits` once, then
  `GET /habits/:id/entries?from&to` per habit in parallel over a 30-day window.
  Honest data with no backend change. N+1 is acceptable at personal-habit scale
  and the result is cached in a provider.

## Contract corrections

Six fixes, all in code this work depends on.

| # | File | Change | Why |
|---|---|---|---|
| 1 | `backend/src/auth/auth.service.ts` | `register` signs `{ userId: user.id }`, not `{ id }` | `JwtStrategy.validate` reads `payload.userId`, so a registration token resolves `undefined` and every subsequent call 401s |
| 2 | `backend/src/habit/habit.controller.ts`, `dto/get-habit.dto.ts`, `habit.service.ts` | bind `@Query() query: GetHabitsDto`; DTO field `date?: string`; service guards on `query?.date` | `@Query('date') date?: GetHabitsDto` binds the raw string while the service reads `.date`, so `dayjs(undefined)` silently falls back to now. An `@Query()` object is never null, so the existing `if (!dateDto)` branch must become `if (!query?.date)` or it goes dead |
| 3 | `backend/src/entries/entries.controller.ts`, `entries.service.ts` | DELETE takes `habitId` + `@CurrentUser('id')`; service checks ownership then deletes by the `habitId_date` unique key | the param is named `entryId` but the route supplies the habit id, so `findFirst({ id })` can never match; it is also the only `/habits/**` handler with no ownership check |
| 4 | `backend/src/utils/dayjs.ts` | `standardizeDate` returns a `Date` at UTC midnight; `TODAY` const becomes `today()` | `@db.Date` with `@@unique([habitId, date])` needs a stable day key, and a module-load constant hands out the boot day forever |
| 5 | `backend/src/habit/habit.service.ts` | `updateHabits` builds `data` from the DTO alone and touches `archivedAt` only when `archived` is present | it currently spreads the whole row (including `id`, `createdAt`) and forces `archivedAt: null` whenever `archived` is falsy, so a plain rename un-archives the habit — which would break the archive feature built on this endpoint |
| 6 | `mobile/lib/injection/dependency_injection.dart` | supply `AuthInterceptor.onUnauthorized` | the callback is never passed, so a 401 clears the token but nothing tells the router |

## Mobile architecture

Mirrors `features/auth` exactly: the datasource throws `AppException`, the
repository is the only place that maps to `Failure`, and presentation `switch`es
over `Result` and never sees a `try`/`catch`.

```
habits/data/     models/habit_model.dart · daily_habit_model.dart
                 datasources/habit_remote_datasource.dart
                 repositories/habit_repository_impl.dart
habits/domain/   entities/daily_habit.dart
                 usecases/ get_daily_habits · create_habit · update_habit · delete_habit
entries/data/    models/habit_entry_model.dart
                 datasources/entry_remote_datasource.dart
                 repositories/entry_repository_impl.dart
entries/domain/  usecases/ toggle_entry · get_entries
```

### Interface revisions

Both contracts were declared ahead of implementation and both are wrong about
what the endpoint returns.

- `HabitRepository.getHabits({DateTime? date})` splits into `getHabits()` and
  `getHabitsForDate(DateTime)`. `GET /habits?date=` returns rows decorated with
  `doneToday` and `currentStreak` — a genuinely different shape. Splitting keeps
  `Habit` a faithful mirror of the DB row and puts the decorated shape in its own
  entity, `DailyHabit`.
- `EntryRepository.getEntries` returns `List<DateTime>`, not `List<HabitEntry>`.
  `GET /habits/:id/entries` responds `{ entries: Date[] }` — bare dates with no
  ids. The `HabitEntry` entity stays, describing the `POST` response, which does
  return a full row.

### State

| Provider | Type | Serves |
|---|---|---|
| `dailyHabitsProvider` | `AsyncNotifier<List<DailyHabit>>` | Today and My Habits |
| `insightsProvider` | `AsyncNotifier<InsightsSummary>` | Insights and Profile stats |

Today and My Habits read one provider because they are two presentations of one
list, not two datasets.

`dailyHabitsProvider` exposes `toggle · create · rename · recolor · archive ·
delete`. **Toggle is optimistic with rollback**: the checkbox flips immediately,
and a failed request reverts it and surfaces a SnackBar. A check-off that waits
on a round trip feels broken. Every mutation invalidates `insightsProvider`.

`InsightsCalculator` is a pure Dart class — `(habits, entriesByHabit, window)` in,
`InsightsSummary` out. No Riverpod, no Dio, so completion rates, best streak and
per-habit percentages are testable without a widget tree or a mock client.

## Screens

- **Today** — habits from `GET /habits?date=today`. Ring is done/total, badge is
  the highest `currentStreak`. Toggling posts or deletes an entry. The water
  slider and three demo toggles go; the quote cycler stays, being decoration that
  costs nothing. Gains loading, error-with-retry and empty states, none of which
  exist today.
- **My Habits** (was Routines) — the full list with rename, colour, archive,
  delete.
- **Add Habit** — `POST /habits` with `{ name, color }`. The five seed chips
  become name-and-colour presets. Goal, frequency and reminder controls are
  removed; nothing stores them.
- **Insights** — 30-day window, parallel entry fetches, real chart and
  percentages.
- **Profile** — counts and streaks from the providers, consistency from the
  calculator, "Growing since" from `user.createdAt` rather than a hardcoded
  "Oct 2022".

## Testing

TDD throughout, following the repo's existing `mocktail` and `pump_app.dart`
patterns.

- Repository tests asserting each `AppException` maps to its `Failure`.
- `InsightsCalculator` unit tests: empty history, a perfect week, a gap, a
  single-day streak.
- Provider tests for optimistic toggle, including rollback on failure.
- Backend tests for all six fixes, each written against the defect first.
- The four existing page tests assert hardcoded strings and are rewritten against
  mocked providers.

## Known limitation

`GET /habits?date=` loads every entry ever recorded for every habit in order to
compute streaks. Acceptable at personal scale; it will need a bounded window
before the data grows. Not addressed here.

## Out of scope

Quantity habits, routines as a stored concept, schedules and reminders,
`/auth/forgot-password` (the OTP screen still verifies any four digits), and the
`/habits/:habitId` detail placeholder route.
