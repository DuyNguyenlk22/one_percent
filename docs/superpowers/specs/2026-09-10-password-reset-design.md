# Password Reset by Emailed Code — Design

Date: 2026-09-10
Status: approved for planning

## Purpose

`ForgotPasswordPage` has shipped in the Flutter app as UI only: it accepts any
four digits after a fixed delay and pops back to `/login`. No `/auth/forgot-*`
route exists on the NestJS server, and there is no screen anywhere in the app
for choosing a new password. This design closes that gap end to end — a new
Prisma table, three auth endpoints, an SMTP-backed `EmailService`, and the
mobile wiring that makes them reachable.

## Success criteria

A user who has forgotten their password can enter their email, receive a
six-digit code by email within seconds, type it into the existing OTP screen,
choose a new password, and sign in with it. A user who did not request the
reset learns nothing about whether the address is registered, and cannot brute
force the code.

## Decisions taken

| Decision | Choice | Why |
|---|---|---|
| Code format | 6 digits, 15-minute TTL | 4 digits is 10,000 combinations — too few to defend with an attempt cap alone. The mobile OTP boxes are generated from one constant, so widening is cheap. |
| Transport | Nodemailer over SMTP | Provider-agnostic. Mailtrap in development, any SMTP host in production, no vendor SDK and no code change between them. |
| Step count | Three endpoints, reset token in the middle | Matches the screen order the app already has. The code crosses the wire once; the second leg carries a short-lived token instead. |
| Storage | Dedicated table, code stored hashed | A database dump must not be an account-takeover kit. |

## Data model

Added to `backend/prisma/schema.prisma`:

```prisma
model PasswordResetCode {
  id         String    @id @default(uuid())
  userId     String
  codeHash   String
  expiresAt  DateTime
  attempts   Int       @default(0)
  verifiedAt DateTime?
  consumedAt DateTime?
  createdAt  DateTime  @default(now())
  user       User      @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId, createdAt])
  @@map("password_reset_codes")
}
```

`User` gains the back-relation `passwordResetCodes PasswordResetCode[]`.

Field by field:

- **`codeHash`** — the code hashed with the existing `hashingPassword` helper in
  `backend/src/utils/bcrypt.ts`, never the code itself. The consequence is that
  rows are found by `userId` (resolved from the submitted email) and the
  candidate code is compared against the newest live row. There is no lookup by
  code, and there must not be one.
- **`expiresAt`** — set to `createdAt + 15 minutes` at insert. Stored rather than
  computed so the TTL can change without reinterpreting old rows.
- **`attempts`** — incremented on every failed verify. At 5 the row is dead.
  This is the control that makes a six-digit code defensible.
- **`verifiedAt`** — stamped when the correct code is presented and the reset
  token is issued. Distinguishes "code proven, password not yet set" from both
  the fresh and the finished state.
- **`consumedAt`** — terminal marker. Set when the password is actually reset,
  and also when a row is superseded by a newer request. A row with `consumedAt`
  set is never usable again, whatever the reason it was set.

A separate table rather than columns on `User` keeps `User` lean, cascade-deletes
with the account, and lets a resend insert a row instead of mutating one.

Migration: `pnpm prisma migrate dev --name add_password_reset_codes`, which also
regenerates the client into `backend/generated/prisma`.

## Endpoints

All three live on the existing `AuthController`, and all three are public — no
`JwtAuthGuard`.

### `POST /auth/forgot-password`

Body `{ email }`. **Always** returns 200 with a fixed generic message, whether
or not the address is registered. Internally, when the user exists:

1. `updateMany` every row for that user with `consumedAt: null`, setting
   `consumedAt` to now — a new request invalidates the old codes.
2. Generate the code with `crypto.randomInt(0, 1_000_000)`, zero-padded to six
   characters. Not `Math.random`.
3. Hash it, insert the row with `expiresAt` 15 minutes out.
4. `await emailService.sendPasswordResetCode(email, code)`.

A resend inside 60 seconds of the previous row's `createdAt` skips steps 1–4 and
still returns the same 200. The mobile screen already runs a resend countdown,
so this is a backstop, not the primary control.

### `POST /auth/verify-reset-code`

Body `{ email, code }`. Loads the newest row for the user where `consumedAt` is
null. Rejects — with the single message `Invalid or expired code` — when the
user does not exist, no row exists, `expiresAt` has passed, `attempts >= 5`, or
the bcrypt comparison fails. On the comparison failing specifically, increment
`attempts` first. Every one of those cases returns the same 400, so the response
distinguishes nothing an attacker can use.

On success: stamp `verifiedAt`, and return `{ resetToken }` — a JWT carrying
`{ userId, prcId, typ: 'pwd_reset' }`, signed via the existing `JwtService` with
an explicit `{ secret: JWT_RESET_SECRET, expiresIn: '10m' }` override.

The distinct secret is what keeps a reset token from being accepted as an access
token: `JwtStrategy` validates against `JWT_SECRET` and will reject it.

A row that has already been verified may be verified again while it is unexpired
and under the attempt cap — the code has not changed, and back-navigation in the
app must not strand the user. Re-verification restamps `verifiedAt` and issues a
fresh token.

### `POST /auth/reset-password`

Body `{ resetToken, newPassword }`. Verifies the token against
`JWT_RESET_SECRET`, checks `typ === 'pwd_reset'`, loads the row by `prcId`, and
requires `verifiedAt != null && consumedAt == null`. Then, in a single
`prisma.$transaction`: hash the new password with `hashingPassword`, update
`user.passwordHash`, and stamp `consumedAt`.

Deliberately does **not** return an access token. The user returns to `/login`
and signs in with the new password, which confirms it works and keeps a single
sign-in path.

`newPassword` reuses whatever validation `RegisterAuthDto` applies, so the two
paths cannot disagree about what a valid password is.

## Email service

`backend/src/email/` is currently an empty Nest scaffold. It gains:

- A Nodemailer transport built from `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`,
  `SMTP_USER`, `SMTP_PASS`, read through the already-installed
  `@nestjs/config`, with `MAIL_FROM` as the sender.
- `sendPasswordResetCode(to: string, code: string)` — a plain-text and simple
  HTML body carrying the code, the 15-minute expiry, and a line telling a
  recipient who did not request it to ignore the message.
- Failures are logged and swallowed. A dead SMTP host must not turn
  `forgot-password` into a 500 that reveals the address exists.

`EmailModule` exports `EmailService`; `AuthModule` imports `EmailModule`.
`email.controller.ts` is deleted — sending is internal and needs no HTTP surface.

New backend env vars, added to `.env.example` as well as `.env`: the six SMTP
values above plus `JWT_RESET_SECRET`.

## Rate limiting

Add `@nestjs/throttler` (not currently a dependency) and apply 5 requests per
minute per IP to `forgot-password` and `verify-reset-code`. The per-row
`attempts` cap stops one code being guessed; the throttle stops an attacker
cycling fresh codes to widen the target.

## Mobile changes

Layered the way the existing auth feature is, datasource → repository → usecase
→ provider → page, and registered in `lib/injection/dependency_injection.dart`.

- `ApiConstants` — three new paths beside `login` and `register`.
- `AuthRemoteDataSource` / `Impl` — `requestPasswordReset`, `verifyResetCode`
  (returns the token), `resetPassword`.
- `AuthRepository` / `Impl` — the same three, returning the project's `Result`
  type.
- Three usecases under `domain/usecases/`.
- `forgot_password_page.dart` — `_otpLength` 4 → 6; fire the
  `requestPasswordReset` call on entry using `widget.email` (the value
  `login_page.dart` already passes); submit calls `verifyResetCode`; the resend
  button calls `requestPasswordReset` again; render the real error message
  instead of the fixed delay.
- **New** `reset_password_page.dart` — new password and confirmation fields,
  receives the reset token from the verify step, calls `resetPassword`, then
  `goNamed(RouteNames.login)` with a success message.
- `RouteNames` — `resetPassword` / `resetPasswordPath`, added to `publicPaths`.
- `app_router.dart` — the new route, and `forgot-password` navigating to it on
  success rather than popping to login.

## Testing

Server, following the existing `auth.service.spec.ts` pattern with a mocked
`PrismaService` and a mocked `EmailService`:

- `forgot-password` returns the identical response for a known and an unknown
  address, and only sends for the known one.
- A new request marks prior unconsumed rows consumed.
- The resend cooldown suppresses a second send inside 60 seconds.
- Verify fails on a wrong code and increments `attempts`; fails at the 5th
  attempt; fails past `expiresAt` (jest fake timers); fails on an already
  consumed row — and returns the same message every time.
- Verify succeeds, stamps `verifiedAt`, and returns a token that
  `JwtStrategy`'s secret rejects.
- Reset succeeds once and fails the second time with the same token.
- Reset rejects a token whose row was never verified.

Mobile: unit tests for the three usecases and the repository mapping, matching
how the existing login and register usecases are covered.

## Out of scope

Password reset over anything but email. Account lockout on repeated reset
requests. Invalidating already-issued access tokens when the password changes —
worth doing, but it needs a token-versioning scheme on `User` and belongs in its
own piece of work.
