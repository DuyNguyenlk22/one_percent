# One Percent — Mobile

Flutter client for the One Percent habit tracker. Talks to the NestJS backend
in [`../backend`](../backend).

The app is organised as **feature-first clean architecture**: shared
infrastructure lives in `core/`, and every feature owns its own `data`,
`domain`, and `presentation` layers.

---

## Table of contents

- [Quick start](#quick-start)
- [Directory structure](#directory-structure)
- [The three layers](#the-three-layers)
- [The dependency rule](#the-dependency-rule)
- [How a request flows](#how-a-request-flows)
- [Error handling](#error-handling)
- [Dependency injection](#dependency-injection)
- [Routing](#routing)
- [Theming](#theming)
- [Adding a new feature](#adding-a-new-feature)
- [Testing](#testing)
- [Conventions](#conventions)
- [Backend contract](#backend-contract)
- [Current status](#current-status)

---

## Quick start

```bash
flutter pub get
flutter run                                     # localhost:3000 by default
flutter run --dart-define=API_BASE_URL=https://api.example.com

flutter analyze                                 # static analysis
flutter test                                    # full test suite
flutter test test/features/auth                 # one feature
```

The Android emulator cannot reach the host on `localhost`, so
[`api_constants.dart`](lib/core/constants/api_constants.dart) resolves
`10.0.2.2:3000` there and `localhost:3000` everywhere else. Override either with
`--dart-define=API_BASE_URL`.

Start the backend first:

```bash
cd ../backend && pnpm start:dev
```

---

## Directory structure

```
lib/
├── app/                              App shell — nothing feature-specific
│   ├── app.dart                        Root widget: theme + router
│   ├── router/
│   │   ├── app_router.dart             GoRouter config and auth redirects
│   │   └── route_names.dart            Every path and route name
│   └── theme/
│       ├── app_colors.dart             "Bloom" palette + Material 3 ColorScheme
│       ├── app_spacing.dart            Spacing, radii, shadows
│       ├── app_typography.dart         Manrope text styles
│       ├── app_theme.dart              Assembled ThemeData
│       └── theme.dart                  Barrel — import this one
│
├── core/                             Shared by every feature; imports no feature
│   ├── constants/
│   │   ├── api_constants.dart          Base URL, timeouts, endpoint paths
│   │   ├── app_constants.dart          Storage keys, validation limits, durations
│   │   ├── app_assets.dart             Asset paths
│   │   ├── app_icons.dart              Semantic icon mappings
│   │   └── constants.dart              Barrel
│   ├── errors/
│   │   ├── exceptions.dart             AppException — thrown by data sources
│   │   ├── failures.dart               Failure — returned to the domain layer
│   │   ├── result.dart                 Result<T> = Success | ResultError
│   │   └── errors.dart                 Barrel
│   ├── network/
│   │   ├── api_client.dart             Dio wrapper; maps errors to exceptions
│   │   ├── network_info.dart           Connectivity check via DNS lookup
│   │   └── interceptors/
│   │       └── auth_interceptor.dart   Attaches the bearer token, clears it on 401
│   ├── storage/
│   │   ├── secure_storage.dart         Keychain / EncryptedSharedPreferences
│   │   └── local_storage.dart          SharedPreferences wrapper
│   ├── utils/
│   │   ├── validators.dart             Form validators matching the backend DTOs
│   │   ├── date_utils.dart             Calendar-day helpers
│   │   └── logger.dart                 Debug-only logging
│   └── widgets/
│       ├── app_button.dart             Four variants, built-in loading state
│       ├── app_text_field.dart         Text and OTP input
│       ├── app_loading.dart            Spinner and full-screen overlay
│       ├── app_error.dart              Error page and inline banner
│       └── widgets.dart                Barrel
│
├── features/
│   ├── auth/                         ✅ Fully implemented
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   ├── auth_remote_datasource.dart    HTTP calls
│   │   │   │   └── auth_local_datasource.dart     Token + cached profile
│   │   │   ├── models/
│   │   │   │   ├── user_model.dart                User + JSON
│   │   │   │   └── auth_response_model.dart       { accessToken, user }
│   │   │   └── repositories/
│   │   │       └── auth_repository_impl.dart      Exceptions → failures
│   │   ├── domain/
│   │   │   ├── entities/user.dart                 Pure Dart, no JSON
│   │   │   ├── repositories/auth_repository.dart  Interface
│   │   │   └── usecases/
│   │   │       ├── login.dart
│   │   │       ├── register.dart
│   │   │       ├── logout.dart
│   │   │       └── get_current_user.dart
│   │   └── presentation/
│   │       ├── pages/
│   │       │   ├── login_page.dart
│   │       │   ├── register_page.dart
│   │       │   └── forgot_password_page.dart
│   │       ├── providers/auth_provider.dart       AuthNotifier + AuthState
│   │       └── widgets/                           (empty)
│   │
│   ├── habits/                       🚧 Domain contract only
│   │   ├── domain/entities/habit.dart
│   │   ├── domain/repositories/habit_repository.dart
│   │   ├── data/ · presentation/                  (empty)
│   │
│   ├── entries/                      🚧 Domain contract only
│   │   ├── domain/entities/habit_entry.dart
│   │   ├── domain/repositories/entry_repository.dart
│   │   ├── data/ · presentation/                  (empty)
│   │
│   ├── insights/                     📁 Folders only
│   └── profile/                      📁 Folders only
│
├── injection/
│   └── dependency_injection.dart     The object graph, as Riverpod providers
│
└── main.dart                         Bootstrap: async deps → ProviderScope → App

test/                                 Mirrors lib/
├── app/theme/
├── core/{errors,utils}/
├── features/auth/{data,domain,presentation}/
└── helpers/                          Shared mocks and pumpApp()
```

---

## The three layers

Each feature is split into three layers with one job apiece.

### `domain/` — what the app does

Pure Dart. No Flutter, no Dio, no JSON. This layer would compile unchanged if
the app moved to a different UI toolkit or a different backend.

| Folder | Holds | Example |
|---|---|---|
| `entities/` | Business objects with no serialisation | `User`, `Habit` |
| `repositories/` | **Interfaces** stating what the feature needs | `AuthRepository` |
| `usecases/` | One operation each, with its rules | `Login`, `Register` |

A use case is a callable class, so it reads as a verb at the call site:

```dart
final result = await ref.read(loginUseCaseProvider)(
  email: email,
  password: password,
);
```

Validation that must hold regardless of UI lives in the use case, not the
notifier — that is what makes it testable without a widget tree.

### `data/` — how it is fulfilled

The only layer that knows about HTTP and device storage.

| Folder | Holds | Rule |
|---|---|---|
| `models/` | Entity subclasses that add `fromJson`/`toJson` | JSON never leaks past this folder |
| `datasources/` | One source of truth each — remote or local | **Throws** `AppException` |
| `repositories/` | Implementations of the domain interfaces | **Returns** `Result<T>`, never throws |

The repository is the seam: it catches every exception, decides between the
remote and local source, and hands the domain layer a value.

### `presentation/` — what the user sees

| Folder | Holds |
|---|---|
| `pages/` | Full screens, one per route |
| `providers/` | Riverpod notifiers holding page state |
| `widgets/` | Widgets used by **this feature only** — anything reusable belongs in `core/widgets/` |

A page reads state and calls a notifier. It never touches a repository, a data
source, or Dio.

---

## The dependency rule

Dependencies point inward. The domain layer at the centre depends on nothing.

```
  presentation  ──────►  domain  ◄──────  data
        │                                   │
        └──────────►  core  ◄───────────────┘
```

| Rule | Why |
|---|---|
| `domain/` imports nothing from `data/` or `presentation/` | Keeps business rules independent of the wire format and the UI |
| `data/` implements `domain/` interfaces | Lets the backend be swapped without touching the domain |
| `presentation/` depends on `domain/`, reaching `data/` only through DI | Lets pages be tested with a mocked repository |
| `core/` never imports a feature | Otherwise `core` stops being shareable |
| Cross-feature access goes through the other feature's `domain/` | Never import another feature's `data/` or `presentation/` |

If a change would break one of these, the fix is usually a new entry in
`core/` or a new use case — not an import that skips a layer.

---

## How a request flows

Signing in, top to bottom:

```
LoginPage
   │  ref.read(authNotifierProvider.notifier).login(...)
   ▼
AuthNotifier                       presentation/providers
   │  ref.read(loginUseCaseProvider)(...)
   ▼
Login                              domain/usecases — validates locally first
   │  repository.login(...)
   ▼
AuthRepositoryImpl                 data/repositories
   │  ├── NetworkInfo.isConnected  ── offline? → ResultError(NetworkFailure())
   │  ├── remote.login(...)        ── throws AppException on failure
   │  └── local.cacheSession(...)  ── token → secure storage
   ▼
AuthRemoteDataSource → ApiClient → Dio → POST /auth/login
```

The result travels back as a `Result<User>`. `AuthNotifier` pattern-matches it
into `AuthState`, the router notices the status change, and the redirect moves
the user into the app. No layer above the repository ever sees an exception.

---

## Error handling

Two types, each with one job:

- **`AppException`** — *thrown*, and only inside `data/`. `ApiClient` produces
  these from the backend's error envelope.
- **`Failure`** — *returned*, and read everywhere above `data/`. Repositories
  translate exceptions into failures.

They meet in `Result<T>`, a sealed type with two variants. Because it is
sealed, the compiler rejects a `switch` that forgets a case:

```dart
switch (await repository.login(email: email, password: password)) {
  case Success(:final data):
    state = AuthState(status: AuthStatus.authenticated, user: data);
  case ResultError(:final failure):
    state = state.copyWith(failure: failure);   // failure.message is display-ready
}
```

`fold`, `map`, `dataOrNull`, and `failureOrNull` are there for the cases where a
full `switch` is more ceremony than the call site needs.

The mapping, in `AuthRepositoryImpl._toFailure`:

| Backend | Exception | Failure |
|---|---|---|
| 400 / 422 | `ValidationException` | `ValidationFailure` (keeps field messages) |
| 401 / 403 | `UnauthorizedException` | `AuthFailure` |
| 404 | `NotFoundException` | `NotFoundFailure` |
| 5xx | `ServerException` | `ServerFailure` |
| No connection, timeout | `NetworkException` | `NetworkFailure` |
| Storage read/write | `CacheException` | `CacheFailure` |

---

## Dependency injection

[`injection/dependency_injection.dart`](lib/injection/dependency_injection.dart)
is the one file that knows which class implements which interface. It uses
Riverpod providers rather than `get_it`, so the app has a single DI mechanism.

```dart
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repository = AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    localDataSource: ref.watch(authLocalDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});
```

Everything else asks `ref` for an **interface** and never names a concrete
class. That is what makes a test able to swap one out:

```dart
ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(MockAuthRepository())],
  child: const App(),
);
```

`sharedPreferencesProvider` throws by design. `SharedPreferences.getInstance()`
is asynchronous and providers are not, so `main()` resolves it and injects it as
an override — a missing override fails loudly instead of silently constructing
a second instance.

---

## Routing

[`app_router.dart`](lib/app/router/app_router.dart) holds a GoRouter whose
`redirect` is the app's only auth gate:

| Auth status | Behaviour |
|---|---|
| `unknown` | Hold on the splash screen while the stored session is checked |
| `unauthenticated` | Any private route redirects to `/login` |
| `authenticated` | The auth pages redirect to `/today` |

Because the guard lives here, no page has to check whether the user may see it.
Navigate with names, never literal paths:

```dart
context.goNamed(RouteNames.today);                 // replace
context.pushNamed(RouteNames.register);            // stack
context.pushNamed(
  RouteNames.forgotPassword,
  queryParameters: {'email': email},
);
```

`/today`, `/habits`, `/insights`, and `/profile` currently render placeholders.
Replace the builder as each feature lands; the route itself does not change.

---

## Theming

Every colour, radius, and text style is a token in `app/theme/`. Import the
barrel and use the token — never a raw `Color(0xFF…)` or a magic number:

```dart
import '../../../../app/theme/theme.dart';

Container(
  padding: const EdgeInsets.all(AppSpacing.cardPadding),
  decoration: BoxDecoration(
    color: AppColors.surfaceContainer,
    borderRadius: AppSpacing.borderRadiusCard,
    boxShadow: AppSpacing.ambientShadow,
  ),
  child: Text('Morning run', style: AppTypography.bodyLarge),
);
```

The palette and spacing scale come from [`../docs/DESIGN.md`](../docs/DESIGN.md).

---

## Adding a new feature

Say you are building `habits`. Work inward-out — contract first, UI last.

**1. Domain — the contract**

```
features/habits/domain/entities/habit.dart              # already written
features/habits/domain/repositories/habit_repository.dart   # already written
features/habits/domain/usecases/get_habits.dart
features/habits/domain/usecases/create_habit.dart
```

**2. Data — the implementation**

```
features/habits/data/models/habit_model.dart            # Habit + fromJson/toJson
features/habits/data/datasources/habit_remote_datasource.dart
features/habits/data/repositories/habit_repository_impl.dart
```

The data source throws; the repository catches and returns a `Result`.

**3. Injection — wire it up**

```dart
final habitRepositoryProvider = Provider<HabitRepository>(
  (ref) => HabitRepositoryImpl(
    remoteDataSource: ref.watch(habitRemoteDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  ),
);
```

**4. Presentation — the screen**

```
features/habits/presentation/providers/habits_provider.dart
features/habits/presentation/pages/habits_page.dart
```

**5. Route** — swap the placeholder in `app_router.dart` for the real page.

**6. Tests** — mirror the paths under `test/`.

Rules of thumb while you go: a widget used by two features moves to
`core/widgets/`; an endpoint path goes in `api_constants.dart`; a storage key
goes in `app_constants.dart`; and a file that has grown past a few hundred
lines is usually doing two jobs.

---

## Testing

`test/` mirrors `lib/` exactly, so the test for `lib/a/b.dart` is at
`test/a/b_test.dart`. Shared mocks and the `pumpApp` helper live in
`test/helpers/`.

```bash
flutter test                                   # everything
flutter test test/features/auth                # one feature
flutter test --coverage                        # with coverage
```

What each layer's tests look like:

| Layer | Approach |
|---|---|
| `domain/usecases` | Mock the repository; assert on validation and delegation |
| `data/repositories` | Mock the data sources; assert exception → failure mapping |
| `core/utils` | Plain unit tests, no mocks |
| `presentation/pages` | `pumpApp` with a mocked repository override |

A widget test must override `authRepositoryProvider`, or the graph will try to
build the real HTTP client and hit `sharedPreferencesProvider`, which throws
outside `main()`:

```dart
await pumpApp(tester, const LoginPage(), overrides: signedOutOverrides());
```

---

## Conventions

**Files and folders** — `snake_case.dart`, singular folder names for a single
concept (`domain/`) and plural for collections (`usecases/`, `entities/`).
Suffix by role: `*_page.dart`, `*_provider.dart`, `*_model.dart`,
`*_repository.dart`, `*_repository_impl.dart`, `*_datasource.dart`.

**Classes** — interfaces take the bare name (`AuthRepository`) and
implementations take the `Impl` suffix (`AuthRepositoryImpl`). Models are named
`<Entity>Model`. Use cases are named for the verb (`Login`, `GetCurrentUser`).

**Imports** — relative within `lib/`, `package:mobile/…` in tests. Prefer the
barrel where one exists (`theme.dart`, `constants.dart`, `errors.dart`,
`widgets.dart`).

**State** — one notifier per feature area. `AuthState` and its siblings are
immutable with a `copyWith`; an error field is cleared on the next submission
rather than lingering.

---

## Backend contract

Base URL from `ApiConstants.baseUrl`. Everything except login and register
requires `Authorization: Bearer <token>`, attached automatically by
`AuthInterceptor`.

| Method | Path | Body / Query | Returns |
|---|---|---|---|
| `POST` | `/auth/login` | `{ email, password }` | `{ accessToken, user }` |
| `POST` | `/auth/register` | `{ email, password }` | `{ accessToken, user }` |
| `GET` | `/auth/me` | — | `user` |
| `GET` | `/habits` | `?date` | `habit[]` |
| `POST` | `/habits` | `{ name, color? }` | `habit` |
| `PATCH` | `/habits/:id` | `{ name?, color?, archived? }` | `habit` |
| `DELETE` | `/habits/:id` | — | — |
| `GET` | `/habits/:id/entries` | `?from&to` | `entry[]` |
| `POST` | `/habits/:id/entries` | `{ date }` | `entry` |
| `DELETE` | `/habits/:id/entries/:date` | — | — |

Errors arrive in one shape, from the backend's `HttpExceptionFilter`:

```json
{
  "statusCode": 401,
  "isSuccess": false,
  "timestamp": "2026-09-09T10:00:00.000Z",
  "path": "/auth/login",
  "error": "Invalid credentials"
}
```

`error` is a string for most failures and an array of strings when
class-validator rejects a DTO. `ApiClient` handles both.

---

## Current status

| Feature | State |
|---|---|
| `auth` | ✅ Login, register, session restore, logout — wired to the backend |
| `habits` | 🚧 Entity and repository interface; no implementation |
| `entries` | 🚧 Entity and repository interface; no implementation |
| `insights` | 📁 Folders only |
| `profile` | 📁 Folders only |

Forgot-password is UI only — the backend has no reset endpoint yet.
`/today`, `/habits`, `/insights`, and `/profile` render placeholders.

The design spec for this structure is in
[`../docs/superpowers/specs/2026-09-09-mobile-clean-architecture-design.md`](../docs/superpowers/specs/2026-09-09-mobile-clean-architecture-design.md).
