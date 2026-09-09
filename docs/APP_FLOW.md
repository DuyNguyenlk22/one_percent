# Bloom — Full-Stack App Flow

A walkthrough of how the app actually behaves today: what the user touches, what
crosses the wire, and where the wiring stops. Written from a read of
`backend/src`, `backend/prisma`, and `mobile/lib` on the `staging` branch.

- **Mobile:** Flutter 3.11 · Riverpod 3 · go_router 17 · Dio 5 · flutter_secure_storage
- **Backend:** NestJS · Prisma · PostgreSQL · Passport-JWT · Swagger at `/api`
- **Shape:** online-only. The app holds no business logic beyond UI state; the API owns auth, ownership, and streaks.

---

## 1. System overview

```mermaid
flowchart LR
    subgraph Device["Flutter app"]
        UI["Pages<br/>(presentation)"]
        NOT["AuthNotifier<br/>(Riverpod)"]
        UC["Use cases<br/>(domain)"]
        REPO["Repository impl<br/>(data)"]
        RDS["Remote datasource"]
        LDS["Local datasource"]
        API["ApiClient (Dio)<br/>+ AuthInterceptor"]
        SEC[("SecureStorage<br/>Keychain / EncryptedSharedPrefs")]
        PREF[("SharedPreferences<br/>cached user JSON")]
    end

    subgraph Server["NestJS API :3000"]
        GUARD["JwtAuthGuard<br/>+ JwtStrategy"]
        AC["AuthController"]
        HC["HabitController"]
        EC["EntriesController"]
        SVC["Services<br/>+ computeCurrentStreak"]
        FILTER["HttpExceptionFilter<br/>(error envelope)"]
    end

    DB[("PostgreSQL<br/>users · habits · habit_entries")]

    UI --> NOT --> UC --> REPO
    REPO --> RDS --> API
    REPO --> LDS --> SEC
    LDS --> PREF
    API -- "HTTPS/JSON<br/>Bearer token" --> GUARD
    GUARD --> AC & HC & EC --> SVC -- Prisma --> DB
    SVC -.-> FILTER -.-> API
```

**Base URL resolution** (`core/constants/api_constants.dart`): `--dart-define=API_BASE_URL` wins;
otherwise Android emulator → `http://10.0.2.2:3000`, everything else → `http://localhost:3000`.

---

## 2. Clean-architecture layering (mobile)

Every feature folder repeats the same four-layer shape. Dependencies point inward
only; the DI file is the single place that knows concrete classes.

```mermaid
flowchart TD
    P["presentation/<br/>pages · providers · widgets"]
    D["domain/<br/>entities · repository interfaces · use cases"]
    DA["data/<br/>models · datasources · repository impls"]
    C["core/<br/>network · storage · errors · widgets · utils"]
    DI["injection/dependency_injection.dart<br/>binds interface → impl"]

    P -->|reads via ref| D
    DA -->|implements| D
    P --> C
    DA --> C
    DI -.provides.-> P
    DI -.provides.-> DA
```

**Error translation happens exactly once.** Datasources throw `AppException`
(`ServerException`, `NetworkException`, `UnauthorizedException`,
`ValidationException`, `NotFoundException`, `CacheException`). The repository
catches them and returns a sealed `Result<T>` carrying a `Failure`. Presentation
code never sees a `try`/`catch` — it `switch`es over `Success` / `ResultError`.

```mermaid
flowchart LR
    HTTP["DioException"] --> AC["ApiClient._toAppException<br/>reads {statusCode, error} envelope"]
    AC --> EX["AppException"]
    EX --> R["Repository._toFailure"]
    R --> F["Failure"]
    F --> RES["ResultError&lt;T&gt;"]
    RES --> BANNER["state.errorMessage → SnackBar"]
```

---

## 3. Startup and session restore

```mermaid
sequenceDiagram
    autonumber
    participant M as main()
    participant App as App (MaterialApp.router)
    participant R as GoRouter redirect
    participant N as AuthNotifier
    participant Repo as AuthRepositoryImpl
    participant S as SecureStorage
    participant API as GET /auth/me

    M->>M: SharedPreferences.getInstance()
    M->>App: ProviderScope(override: sharedPreferencesProvider)
    App->>R: initialLocation "/" (splash)
    R-->>App: status == unknown → hold on splash
    App->>N: build() → Future.microtask(restoreSession)
    N->>Repo: hasSession()
    Repo->>S: readAccessToken()
    alt no token
        S-->>N: null
        N->>N: status = unauthenticated
        R-->>App: redirect → /login
    else token present
        N->>API: GET /auth/me (Bearer)
        alt 200
            API-->>N: user → status = authenticated
            R-->>App: redirect → /today
        else 401
            Repo->>S: clearSession()
            N->>N: status = unauthenticated
            R-->>App: redirect → /login
        end
    end
```

The router is rebuilt from a `ValueNotifier<AuthStatus>` fed by
`ref.listen(authNotifierProvider.select(...))`, so **no page ever decides
whether it may be shown** — `redirect` in `app_router.dart` does.

Redirect rules:

| Status | Location | Result |
|---|---|---|
| `unknown` | anything but `/` | → `/` (splash) |
| `unauthenticated` | public path (`/login`, `/register`, `/forgot-password`) | stay |
| `unauthenticated` | anything else, incl. `/` | → `/login` |
| `authenticated` | a public path | → `/today` |
| `authenticated` | private path | stay |

---

## 4. Screen flow

```mermaid
flowchart TD
    SPLASH["/ — Splash<br/>AppLoading"]

    subgraph Public["Public (signed out)"]
        LOGIN["/login"]
        REG["/register"]
        FORGOT["/forgot-password?email="]
    end

    subgraph Shell["StatefulShellRoute.indexedStack — MainShellScaffold<br/>frosted-glass floating bottom nav, 4 branches"]
        TODAY["/today — TodayPage"]
        ROUT["/habits — MyHabitsPage"]
        INS["/insights — InsightsPage"]
        PROF["/profile — ProfilePage"]
    end

    ADD["/habits/add — AddHabitPage<br/>(root navigator, full-screen over the nav bar)"]
    DETAIL["/habits/:habitId<br/>_PlaceholderPage"]

    SPLASH -->|unauthenticated| LOGIN
    SPLASH -->|authenticated| TODAY
    LOGIN -->|"push · Sign up"| REG
    LOGIN -->|"push · Forgot password"| FORGOT
    REG -->|"pop / goNamed"| LOGIN
    FORGOT -->|"pop after verify"| LOGIN
    LOGIN -->|"auth success → router redirect"| TODAY
    REG -->|"auth success → router redirect"| TODAY

    TODAY <--> ROUT <--> INS <--> PROF
    TODAY -->|"avatar tap · goNamed"| PROF
    TODAY -->|"FAB · pushNamed"| ADD
    ROUT -->|"Add card · pushNamed"| ADD
    ROUT -->|"rename · recolour · archive · delete"| ROUT
    ROUT -.->|"route exists, no link yet"| DETAIL
    ADD -->|"Confirm / Close · pop"| ROUT
    PROF -->|"Log out → status flips"| LOGIN
```

Tab state is preserved per branch (`indexedStack`); tapping the active tab
re-navigates to that branch's initial location.

---

## 5. Auth: login and register end to end

```mermaid
sequenceDiagram
    autonumber
    participant U as User
    participant P as LoginPage
    participant N as AuthNotifier
    participant UC as Login use case
    participant Repo as AuthRepositoryImpl
    participant Net as NetworkInfo (DNS lookup)
    participant DS as AuthRemoteDataSource
    participant I as AuthInterceptor
    participant C as AuthController
    participant S as AuthService
    participant DB as Postgres

    U->>P: email + password, tap Sign In
    P->>P: Form validate (Validators)
    P->>N: login(email, password)
    N->>N: isSubmitting = true
    N->>UC: call()
    UC->>UC: Validators.email / .password
    Note over UC: local failure returns<br/>ValidationFailure without a round trip
    UC->>Repo: login()
    Repo->>Net: isConnected?
    Net-->>Repo: false → NetworkFailure (short-circuit)
    Repo->>DS: POST /auth/login
    DS->>I: onRequest
    Note over I: /auth/login is in _publicPaths<br/>→ no Bearer header attached
    I->>C: POST {email, password}
    C->>S: login()
    S->>DB: user.findUnique(email)
    alt not found
        S-->>C: 404 NotFoundException
    else bcrypt mismatch
        S-->>C: 401 UnauthorizedException
    else ok
        S->>S: jwtService.sign({ userId })
        S-->>C: { accessToken, user (passwordHash omitted) }
    end
    C-->>DS: 200 / error envelope
    Repo->>Repo: cacheSession → SecureStorage + SharedPreferences
    Repo->>N: Success(User)
    N->>N: status = authenticated
    N-->>P: true
    Note over P: router's refreshListenable fires → /today
```

Register follows the same path against `POST /auth/register`
(409 on a duplicate email) and additionally checks `confirmPassword` client-side,
since the backend DTO has no such field.

**Token handling:** `AuthInterceptor` attaches
`Authorization: Bearer <token>` to every request whose path is not
`/auth/login` or `/auth/register`. On a 401/403 from a *non-public* path it
deletes the token — a 401 on login means "wrong password", not "expired
session", so the stored token is left alone there.

---

## 6. Habits and entries (backend contract)

All `/habits/**` routes sit behind `@UseGuards(JwtAuthGuard)` and resolve the
caller through the `@CurrentUser('id')` param decorator.

| Method | Path | Body / Query | Behaviour |
|---|---|---|---|
| `POST` | `/habits` | `{ name, color? }` (`color` must be hex) | creates for the current user |
| `GET` | `/habits` | `?date=YYYY-MM-DD` | active habits (`archivedAt: null`); with a date, each row is decorated with `doneToday` + `currentStreak` |
| `PATCH` | `/habits/:id` | `{ name?, color?, archived? }` | ownership-checked; `archived: true` stamps `archivedAt`, anything else clears it |
| `DELETE` | `/habits/:id` | — | ownership-checked hard delete (cascades entries) |
| `POST` | `/habits/:id/entries` | `{ date? }`, defaults to today | `upsert` on `@@unique([habitId, date])` — idempotent check-off |
| `GET` | `/habits/:id/entries` | `?from=&to=` | ownership-checked; returns `{ entries: Date[] }` ascending |
| `DELETE` | `/habits/:id/entries/:date` | — | un-check a day |

### Check-off round trip

```mermaid
sequenceDiagram
    autonumber
    participant App
    participant G as JwtAuthGuard
    participant EC as EntriesController
    participant ES as EntriesService
    participant DB as Postgres

    App->>G: POST /habits/{id}/entries  Bearer …
    G->>G: JwtStrategy.validate(payload.userId)<br/>→ AuthService.validateUser → req.user
    G->>EC: ParseUUIDPipe(:id) + CreateEntryDto
    EC->>ES: checkOff(userId, habitId, dto)
    ES->>DB: habit.findFirst({id, userId, archivedAt: null})
    alt not owned / archived
        ES-->>App: 404
    else ok
        ES->>DB: habitEntry.upsert(habitId_date)
        DB-->>App: 201 entry
    end
```

### Streak computation

`computeCurrentStreak` (`backend/src/utils/streak.ts`) is pure: it takes the
habit's entry dates plus a target day, builds a `Set` of `YYYY-MM-DD` strings,
and walks backwards one day at a time until a gap.

```mermaid
flowchart LR
    A["entries: Date[]"] --> B["Set of YYYY-MM-DD"]
    T["target day"] --> L{"is current<br/>in the set?"}
    B --> L
    L -->|yes| I["streak++, current -= 1 day"] --> L
    L -->|no| O["return streak"]
```

Streaks are **never stored** — there is nothing to keep in sync. Un-checking a
day is a row delete, and the next read recomputes.

### Error envelope

`HttpExceptionFilter` normalises every `HttpException` into a single shape, which
`ApiClient._parseErrorBody` reads back on the client:

```json
{ "statusCode": 401, "isSuccess": false, "timestamp": "…",
  "path": "/auth/login", "error": "Invalid credentials" }
```

`error` is a string for most failures and a **list** when class-validator rejects
a DTO — the client keeps the list as `ValidationFailure.errors` and shows the
first message.

---

## 7. Data model

```mermaid
erDiagram
    users ||--o{ habits : owns
    habits ||--o{ habit_entries : "checked off on"

    users {
        uuid id PK
        string email UK
        string passwordHash
        datetime createdAt
    }
    habits {
        uuid id PK
        uuid userId FK
        string name
        string color "nullable, hex"
        datetime createdAt
        datetime archivedAt "nullable = soft delete"
    }
    habit_entries {
        uuid id PK
        uuid habitId FK
        date date "UNIQUE(habitId, date)"
        datetime createdAt
    }
```

Both FKs are `onDelete: Cascade`. A check-off is just a row; archiving keeps
history, deleting discards it.

---

## 8. What is wired

Every screen now reads and writes the real API. The Stitch mockups that had no
schema behind them were fitted to the contract rather than faked.

```mermaid
flowchart TD
    subgraph Live["Live end-to-end"]
        A1["Login · Register · Logout"]
        A2["Session restore, and 401 → router redirect"]
        A3["Today — GET /habits?date=, optimistic check-off"]
        A4["My Habits — rename · recolour · archive · delete"]
        A5["Add Habit — POST /habits with name + colour"]
        A6["Insights · Profile — 30 days of entry history"]
    end
    subgraph Local["Still UI-only"]
        B1["Forgot Password — 4-digit OTP, no endpoint exists"]
        B2["Today's quote cycler — decoration, no data"]
    end
```

Concretely:

- **Today** shows the real habit list. The ring is done/total, the badge is the
  highest `currentStreak`, and tapping a card posts or deletes an entry
  optimistically — the row flips first and rolls back if the write is rejected.
- **My Habits** replaced the Routines mockup. Routines were three hardcoded
  cards with no table behind them, while `PATCH` and `DELETE /habits/:id` had no
  caller anywhere in the app; the tab now uses both.
- **Add Habit** posts `{ name, color }`. The goal, frequency and reminder-time
  controls are gone: the schema stores none of them.
- **Insights and Profile** compute from history. There is no aggregate endpoint,
  so `insightsProvider` fetches `GET /habits` once and then each habit's entries
  in parallel over a 30-day window, and a pure `InsightsCalculator` turns that
  into streaks, per-day completion and per-habit rates.
- **Dropped rather than faked:** the water-quantity habit, routines as a stored
  concept, schedules and reminders, and the hardcoded 88% / 14 / 28 stat row.
  None of them had anywhere to live.

Extending the schema for quantity habits, routines and schedules is a separate
piece of work, specified nowhere yet.

## 9. Remaining rough edges

The six defects this document previously listed here — the register token claim,
the unbound `date` query DTO, the mis-keyed entry delete, the module-load
`TODAY`, the row-spreading `updateHabits`, and the unsupplied
`AuthInterceptor.onUnauthorized` — are fixed and covered by tests. What is left:

1. **`ForgotPasswordPage` has no backend.** There is no `/auth/forgot-password`
   or `/auth/reset-password` on the server; the OTP screen verifies any 4 digits
   after a fixed delay.

2. **`GET /habits?date=` loads a habit's whole entry history** to compute its
   streak. Fine at personal scale, but it needs a bounded window before the data
   grows.

3. **Insights costs N+1 requests** — one for the habit list, then one per habit
   for its entries. Acceptable for now, and the obvious fix is a single
   aggregate endpoint on the server.

4. **Day keys are UTC on both sides.** `HabitEntry.date` is written at UTC
   midnight and read back in UTC; the client's `AppDateUtils` does calendar
   arithmetic rather than adding 24-hour `Duration`s. Both suites are run under
   `Pacific/Kiritimati`, `Pacific/Midway` and `America/Santiago` because every
   one of those rules was broken until a test in one of those zones caught it.

## 10. File map

| Concern | Path |
|---|---|
| App entry / bootstrap | [mobile/lib/main.dart](../mobile/lib/main.dart) |
| Routing + redirects | [mobile/lib/app/router/app_router.dart](../mobile/lib/app/router/app_router.dart) |
| Route constants | [mobile/lib/app/router/route_names.dart](../mobile/lib/app/router/route_names.dart) |
| Habit state + optimistic toggle | [mobile/lib/features/habits/presentation/providers/daily_habits_provider.dart](../mobile/lib/features/habits/presentation/providers/daily_habits_provider.dart) |
| History maths (pure) | [mobile/lib/features/insights/domain/insights_calculator.dart](../mobile/lib/features/insights/domain/insights_calculator.dart) |
| Tab shell / bottom nav | [mobile/lib/app/shell/main_shell_scaffold.dart](../mobile/lib/app/shell/main_shell_scaffold.dart) |
| Object graph | [mobile/lib/injection/dependency_injection.dart](../mobile/lib/injection/dependency_injection.dart) |
| Auth state machine | [mobile/lib/features/auth/presentation/providers/auth_provider.dart](../mobile/lib/features/auth/presentation/providers/auth_provider.dart) |
| Exception → Failure | [mobile/lib/features/auth/data/repositories/auth_repository_impl.dart](../mobile/lib/features/auth/data/repositories/auth_repository_impl.dart) |
| HTTP client | [mobile/lib/core/network/api_client.dart](../mobile/lib/core/network/api_client.dart) |
| Token attach / clear | [mobile/lib/core/network/interceptors/auth_interceptor.dart](../mobile/lib/core/network/interceptors/auth_interceptor.dart) |
| Endpoint constants | [mobile/lib/core/constants/api_constants.dart](../mobile/lib/core/constants/api_constants.dart) |
| Auth endpoints | [backend/src/auth/auth.controller.ts](../backend/src/auth/auth.controller.ts) |
| Habit endpoints | [backend/src/habit/habit.controller.ts](../backend/src/habit/habit.controller.ts) |
| Entry endpoints | [backend/src/entries/entries.controller.ts](../backend/src/entries/entries.controller.ts) |
| Streak rule | [backend/src/utils/streak.ts](../backend/src/utils/streak.ts) |
| Error envelope | [backend/src/common/filters/all-exceptions.filter.ts](../backend/src/common/filters/all-exceptions.filter.ts) |
| Schema | [backend/prisma/schema.prisma](../backend/prisma/schema.prisma) |
