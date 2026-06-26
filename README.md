# Habit Tracker

A simple daily habit tracker. Sign in, create habits, check them off once per day, and watch your streaks grow. Built as a learning-first, finishable MVP across a full mobile + backend stack.

**Stack:** Flutter (Android) · NestJS · PostgreSQL · Prisma

📄 Full design & build plan: [docs/habit-tracker-mvp-design-and-build-plan.md](docs/habit-tracker-mvp-design-and-build-plan.md)

---

## Features (MVP)

- Email + password accounts (JWT auth)
- Create / rename / archive habits
- Daily check-off (mark a habit done for a day; un-check to undo)
- Current streak per habit (computed server-side)
- History view (calendar of completed days)
- Online-only — the app always talks to the backend

**Out of scope for v1:** reminders/notifications, count/quantity habits, custom schedules, offline-first sync, social login, sharing, analytics.

---

## Architecture

Online-only, three layers. The Flutter app holds **no business logic** beyond UI state — every read/write goes to the API. The API owns all rules (auth, ownership, streak computation) and is the only thing touching Postgres.

```
Flutter app (Android)  ──HTTPS/JSON──>  NestJS API  ──>  PostgreSQL
   - screens / UI                        - REST endpoints     - users
   - Riverpod state                      - JWT auth guards    - habits
   - dio api client                      - DTO validation     - habit_entries
   - secure token storage                - streak logic
```

---

## Repo layout

```
one_percent/
  backend/            # NestJS + Prisma API
  mobile/             # Flutter app (Android)
  docs/               # design + notes
  docker-compose.yml  # local Postgres (+ optional backend)
  README.md
```

---

## Data model

Three tables. A "check-off" is just a row in `habit_entries`. Streaks are **computed from entries**, never stored — so there is nothing to keep in sync.

- **users** — `id`, `email` (unique), `password_hash` (bcrypt), `created_at`
- **habits** — `id`, `user_id` (FK), `name`, `color?`, `created_at`, `archived_at?`
- **habit_entries** — `id`, `habit_id` (FK), `date`, `created_at` — `UNIQUE (habit_id, date)`

Un-checking a day = delete the entry row.

---

## API overview

REST + JSON. All `/habits/**` routes require a valid JWT and enforce ownership.

| Method | Path | Notes |
|--------|------|-------|
| POST | `/auth/register` | `{ email, password }` → tokens |
| POST | `/auth/login` | `{ email, password }` → tokens |
| POST | `/auth/refresh` | `{ refreshToken }` → new tokens |
| GET | `/auth/me` | current user |
| GET | `/habits?date=YYYY-MM-DD` | active habits (+ `doneToday`, `currentStreak`) |
| POST | `/habits` | `{ name, color? }` |
| PATCH | `/habits/:id` | rename / recolor / archive |
| DELETE | `/habits/:id` | hard delete (prefer archive in UI) |
| GET | `/habits/:id/entries?from=&to=` | completed dates in range |
| POST | `/habits/:id/entries` | `{ date }` — check off a day |
| DELETE | `/habits/:id/entries/:date` | un-check a day |

See the [design doc](docs/habit-tracker-mvp-design-and-build-plan.md) for streak rules and module structure.

---

## Getting started

### Prerequisites

- Node.js + a package manager (`pnpm`/`npm`)
- Flutter SDK + an Android emulator or device
- PostgreSQL running locally

### 1. Database

Make sure your local PostgreSQL is running and a `habit` database exists. Point `DATABASE_URL` (below) at it.

### 2. Backend

```bash
cd backend
pnpm install
cp .env.example .env         # then fill in secrets (see below)
pnpm prisma migrate dev      # apply schema
pnpm run start:dev           # http://localhost:3000
```

**backend/.env**

```
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/habit
JWT_ACCESS_SECRET=<random-long-string>
JWT_REFRESH_SECRET=<different-random-long-string>
JWT_ACCESS_TTL=15m
JWT_REFRESH_TTL=30d
PORT=3000
```

### 3. Mobile

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<LAN-IP>:3000
```

> Use your machine's LAN IP (not `localhost`) when running on a physical device.

---

## Testing

**Backend (Jest):** unit tests for `computeCurrentStreak` and auth; an e2e happy-path (register → login → create habit → check off → streak → uncheck).

```bash
cd backend && pnpm test
```

**Mobile:** widget tests for login validation and the Today toggle.

```bash
cd mobile && flutter test
```

---

## Deployment

- **Backend:** Dockerize and deploy to Railway or Render (managed Postgres + Git deploys). Set env vars and run migrations on deploy.
- **Android:** generate a signing keystore, then `flutter build apk --release --dart-define=API_BASE_URL=<prod URL>`. Install the signed APK directly for yourself/testers.

---

## Build plan

Work is organized into vertical phases (each verifiable before moving on):

0. Project setup → 1. Backend auth → 2. Habits + entries + streak → 3. Backend tests & hardening → 4. Flutter foundation + auth → 5. Today screen → 6. Habit management + history → 7. Polish & tests → 8. Deploy

Full checklist in [docs/habit-tracker-mvp-design-and-build-plan.md](docs/habit-tracker-mvp-design-and-build-plan.md#9-build-plan--phased-checklist).

---

## Notes

- Never commit `.env` or the Android keystore — keep them in `.gitignore`.
- Build the backend before the mobile app: every endpoint is testable with Postman/curl before any UI exists.
