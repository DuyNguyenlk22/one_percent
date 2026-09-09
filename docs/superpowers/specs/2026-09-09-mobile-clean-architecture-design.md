# Mobile Clean Architecture Restructure — Design

Date: 2026-09-09
Status: Approved

## Problem

`mobile/lib` holds only `core/theme`, `core/constants`, and
`features/auth/presentation`. There is no network layer, no storage, no
router, and no domain or data layer. `LoginController` fakes a login with
`Future.delayed(600ms)`. `main.dart` still carries the Flutter counter
template. Every new feature would have to invent its own plumbing.

## Goal

Restructure `mobile/` into a feature-first clean architecture, implement the
shared `core/` infrastructure for real, wire `auth` end to end against the
existing NestJS backend, and scaffold the remaining features so the tree is
honest about what exists.

## Target structure

```
lib/
├── app/                 app shell: MyApp, router, theme
├── core/                cross-feature infrastructure
│   ├── constants/  errors/  network/  storage/  utils/  widgets/
├── features/<feature>/  data/ · domain/ · presentation/
├── injection/           root Riverpod providers
└── main.dart            bootstrap only
```

Features: `auth` (full), `habits` and `entries` (domain contracts only),
`insights` and `profile` (folders only).

`test/` mirrors `lib/`, plus `test/helpers/`.

## The dependency rule

Dependencies point inward. `domain` is pure Dart and imports nothing from
`data` or `presentation`. `data` implements `domain` interfaces. `presentation`
depends on `domain` and reaches `data` only through DI. `core` and `app` may be
imported by any feature; `core` must never import a feature. Cross-feature
imports go through the other feature's `domain`, never its `data` or
`presentation`.

## Decisions

**Errors — sealed `Result`, no dartz/fpdart.** Data sources throw `AppException`
subtypes (`ServerException`, `NetworkException`, `UnauthorizedException`,
`CacheException`, `ValidationException`). Repositories catch them and return
`Result<T>` — a Dart 3 sealed type with `Success<T>` and `ResultError<T>(Failure)`
variants, consumed by pattern matching. Same discipline as `Either`, no extra
package, better call sites.

**DI — Riverpod, not get_it.** The app is already on `flutter_riverpod` 3.4.
`injection/dependency_injection.dart` holds the root providers and the override
points used by tests. One DI mechanism, not two.

**Connectivity — no `connectivity_plus`.** `NetworkInfo` uses
`InternetAddress.lookup`; the app is mobile-only, so `dart:io` is available.

**Pages, not screens.** `presentation/pages/` per the agreed template.

## Backend contract

Read from `backend/src`. Base path `/api` is not used; routes are root-relative.

| Method | Path | Auth | Body / Query | Response |
|---|---|---|---|---|
| POST | `/auth/login` | no | `{email, password}` | `{accessToken, user}` |
| POST | `/auth/register` | no | `{email, password}` | `{accessToken, user}` |
| GET | `/auth/me` | Bearer | — | `user` |
| POST | `/habits` | Bearer | `{name, color?}` | habit |
| GET | `/habits` | Bearer | `?date` | habit[] |
| PATCH | `/habits/:id` | Bearer | `{name?, color?, archived?}` | habit |
| DELETE | `/habits/:id` | Bearer | — | — |
| POST | `/habits/:id/entries` | Bearer | `{date}` | entry |
| GET | `/habits/:id/entries` | Bearer | `?from&to` | entry[] |
| DELETE | `/habits/:id/entries/:date` | Bearer | — | — |

Errors come from `HttpExceptionFilter` as
`{statusCode, isSuccess: false, timestamp, path, error}` where `error` is a
string or a string array. `ApiClient` parses this shape into `AppException`.

Entities mirror Prisma: `User{id, email, createdAt}`,
`Habit{id, userId, name, color?, createdAt, archivedAt?}`,
`HabitEntry{id, habitId, date, createdAt}`.

## Moves

| From | To |
|---|---|
| `lib/core/theme/*` | `lib/app/theme/*` |
| `features/auth/presentation/widgets/text_form_widget.dart` | `core/widgets/app_text_field.dart` |
| `features/auth/presentation/controllers/login_controller.dart` | `features/auth/presentation/providers/auth_provider.dart` |
| `features/auth/presentation/screens/*_screen.dart` | `features/auth/presentation/pages/*_page.dart` |
| `test/core/theme/theme_test.dart` | `test/app/theme/theme_test.dart` |
| `test/widget_test.dart` | `test/features/auth/presentation/login_page_test.dart` |

`TextFormWidget` is renamed `AppTextField`; its API is already generic
(`label`, `hintText`, `validator`, `isPassword`, `isOtp`, …) and carries no
auth-specific logic. `main.dart` loses the ~90 lines of `MyHomePage` counter
boilerplate.

## Auth end to end

- **domain** — `User` entity; `AuthRepository` interface; use cases `Login`,
  `Register`, `Logout`, `GetCurrentUser`.
- **data** — `UserModel`, `AuthResponseModel`; `AuthRemoteDataSource` over Dio;
  `AuthLocalDataSource` storing the token and cached user;
  `AuthRepositoryImpl` mapping exceptions to failures.
- **presentation** — `AuthNotifier` replaces the simulated login with a real
  call and exposes `AuthState` (`unknown`/`authenticated`/`unauthenticated`);
  `AuthInterceptor` attaches the bearer token and clears the session on 401.

The router redirects on auth state: unauthenticated users are sent to
`/login`, authenticated users away from the auth pages.

## New dependencies

`dio`, `go_router`, `flutter_secure_storage`, `shared_preferences`; `mocktail`
in dev. Base URL in `api_constants.dart`, defaulting to `10.0.2.2` on the
Android emulator and `localhost` elsewhere, overridable with
`--dart-define=API_BASE_URL`.

## Testing

`flutter analyze` clean and `flutter test` green are the acceptance bar.
New tests cover `Validators`, `AppDateUtils`, the `Result` type,
`AuthRepositoryImpl` against a mocked data source, and the auth use cases.
The existing login widget test keeps its assertions and gains the new import
path. `test/helpers/` holds the shared mocks and provider overrides.

## Out of scope

Implementations for `habits`, `entries`, `insights`, and `profile`. Those get
their folder trees and, where the contract is already known, their domain
entities and repository interfaces — nothing that pretends to work.
