# LLD — padosipro-nano

Companion to HLD.md. This is the detail you need while actually writing code:
exact schemas, exact request/response shapes, file-level breakdown.

## 1. Database schema (DDL-level detail)

```sql
PRAGMA foreign_keys = ON;

CREATE TABLE users (
    id                    TEXT PRIMARY KEY,
    email                 TEXT UNIQUE NOT NULL,
    password_hash         TEXT NOT NULL,
    is_verified           INTEGER NOT NULL DEFAULT 0 CHECK (is_verified IN (0, 1)),
    has_completed_profile INTEGER NOT NULL DEFAULT 0 CHECK (has_completed_profile IN (0, 1)),
    created_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_users_email ON users(email);

CREATE TABLE profiles (
    id             TEXT PRIMARY KEY,
    user_id        TEXT UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name           TEXT NOT NULL,
    mobile_number  TEXT NOT NULL,
    address        TEXT NOT NULL,
    business_name  TEXT,
    updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE otp_codes (
    id          TEXT PRIMARY KEY,
    user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    code_hash   TEXT NOT NULL,
    expires_at  DATETIME NOT NULL,
    attempts    INTEGER NOT NULL DEFAULT 0,
    consumed    INTEGER NOT NULL DEFAULT 0 CHECK (consumed IN (0, 1)),
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_otp_user_created ON otp_codes(user_id, created_at DESC);

CREATE TABLE tasks (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    category    TEXT NOT NULL,
    description TEXT NOT NULL
);
CREATE INDEX idx_tasks_category ON tasks(category);

CREATE TABLE task_selections (
    id             TEXT PRIMARY KEY,
    user_id        TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    task_id        TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    requested_time DATETIME,                  -- customer's preferred service time (nullable)
    note           VARCHAR(280),              -- short note ≤ 280 chars (nullable)
    created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (user_id, task_id)
);
```

Notes:
- `PRAGMA foreign_keys = ON;` is required so SQLite enforces `ON DELETE CASCADE` as expected. Without it, SQLite silently ignores foreign-key enforcement in normal DML.
- `otp_codes` keeps history (no delete on new code); always query the latest unconsumed row ordered by `created_at DESC`.
- `task_selections` has a unique constraint on `(user_id, task_id)` so a replace can be done as delete-then-insert without worrying about duplicates.
- Redis is not a table. It holds exactly one key per user during the resend cooldown: `otp:resend_cooldown:{email}`, value `"1"`, TTL 30s. Nothing else lives there.
- Only one process should write to the SQLite file at a time in v1; the app is single-writer by design.

## 2. API contracts

All error responses: `{"detail": "<message>"}`. All timestamps ISO 8601 UTC.

### POST /auth/register
Request:
```json
{ "email": "user@example.com", "password": "Passw0rd1" }
```
Validation: email format; password ≥8 chars, at least one letter and one digit.
Success `201`:
```json
{ "message": "Account created. Check your email for a verification code.", "email": "user@example.com" }
```
Errors: `409` email already exists · `422` validation failure.

### POST /auth/resend-otp
Request: `{ "email": "user@example.com" }`
Success `200`: `{ "message": "A new verification code has been sent" }`
Errors: `404` no account · `400` already verified · `429` cooldown active (message includes seconds remaining).

### POST /auth/verify-otp
Request: `{ "email": "user@example.com", "code": "123456" }`
Validation: code is exactly 6 digits.
Success `200`:
```json
{ "access_token": "<jwt>", "token_type": "bearer", "has_completed_profile": false }
```
Errors: `404` no account · `400` already verified / no active code / expired / already used / wrong code (message includes attempts remaining) · `429` too many wrong attempts.

### POST /auth/login
Request: `{ "email": "user@example.com", "password": "Passw0rd1" }`
Success `200`: same shape as verify-otp.
Errors: `401` invalid credentials · `403` unverified (message tells the client to route to verify-otp).

### PUT /profile  (Authorization: Bearer required)
Request:
```json
{ "name": "Asha Rao", "mobile_number": "9876543210", "address": "12 MG Road, Indore", "business_name": null }
```
Validation: mobile exactly 10 digits starting 6-9; name ≥2 chars; address ≥5 chars; business_name optional.
Success `200`: the saved profile object (same shape as request, echoing what was stored).
Errors: `401` invalid/missing token · `422` validation.

### GET /profile  (auth required)
Success `200`: profile object. **`404`: no profile yet** — this is the signal the app uses to route first-login users to the Profile screen.

### GET /tasks/catalogue  (no auth)
Success `200`: array of `{ "id", "name", "category", "description" }`.

### PUT /tasks/selection  (auth required)
Request:
```json
{
  "selections": [
    {
      "task_id": "<uuid>",
      "requested_time": "2026-10-10T09:00:00Z",
      "note": "Please come after 9 AM"
    }
  ]
}
```
Validation: `selections` must be non-empty; every `task_id` must exist in `tasks`; `note` length ≤ 280 chars.
Success `200`: array of saved selection objects (full replace) — each item has:
```json
{
  "id": "<task-uuid>",
  "name": "...",
  "category": "...",
  "description": "...",
  "requested_time": "2026-10-10T09:00:00Z",
  "note": "Please come after 9 AM"
}
```
Errors: `401` · `422` empty selections, unknown id, note > 280 chars.

### GET /tasks/selection  (auth required)
Success `200`: array of currently selected task objects with `requested_time` and `note` fields included (same shape as PUT 200 response). Empty array if none selected.

## 3. OTP state machine (the core risky logic)

States a code can be in, and what each verify attempt does:

| Current state | Submitted code | Outcome | Side effect |
|---|---|---|---|
| consumed = true | any | `already_consumed` | none |
| attempts ≥ 5 | any | `too_many_attempts` | none — caller must resend |
| now > expires_at | any (even correct) | `expired` | none |
| not expired, attempts < 5 | wrong | `wrong_code` | attempts += 1 |
| not expired, attempts < 5 | correct | `ok` | consumed = true, user.is_verified = true |

Check order matters: `consumed` beats `too_many_attempts` beats `expired` beats the
actual hash comparison. This is exactly what `evaluate_otp_attempt()` in the HLD's
otp.py should implement as a pure function — no DB, no async, so it's trivial to
hit every branch in a unit test.

## 4. Backend file-level breakdown

```
app/
  config.py       Settings (env vars) — one object, imported everywhere
  database.py     async engine + session factory
  models.py       SQLAlchemy models: User, Profile, OtpCode, Task, TaskSelection
  schemas.py      Pydantic request/response models, field validators live here
  security.py     hash_password, verify_password, create_access_token, decode_access_token
  otp.py          generate_otp_code, hash_otp, verify_otp_hash, evaluate_otp_attempt (pure)
  email_sender.py send_otp_email (SMTP)
  redis_client.py resend-cooldown key helper
  deps.py         get_current_user (FastAPI dependency, decodes JWT, loads user)
  seed.py         seeds tasks table
  routers/
    auth.py       register, resend-otp, verify-otp, login
    profile.py    PUT/GET /profile
    tasks.py      GET /tasks/catalogue, PUT/GET /tasks/selection
  main.py         app instance, exception handlers, router includes
tests/
  test_otp.py     unit tests on otp.py — write these before the endpoints
```

Build order: `otp.py` + its tests → `models.py` → `auth.py` router → try it with curl
→ `profile.py` → `tasks.py` → `seed.py`.

## 5. Mobile file-level breakdown

```
lib/
  main.dart              app entry, ChangeNotifierProvider, root router
  theme.dart             AppColors, ThemeData
  models/
    profile.dart         UserProfile (fromJson/toJson)
    task.dart             Task (fromJson)
  services/
    api_client.dart       thin http wrapper, throws ApiException(statusCode, message)
    auth_service.dart      register, resendOtp, verifyOtp, login
    profile_service.dart   saveProfile, getProfile
    task_service.dart      getCatalogue, saveSelection, getSelection
    session_storage.dart    secure_storage wrapper for the JWT
  state/
    app_state.dart         ChangeNotifier: token, isLoggedIn, hasCompletedProfile, bootstrap()
  screens/
    login_screen.dart
    register_screen.dart
    verify_otp_screen.dart
    home_gate.dart          not a visible screen — decides Profile vs Home after login
    profile_screen.dart
    task_selection_screen.dart
    home_screen.dart
  widgets/
    primary_button.dart
    error_banner.dart
    loading_view.dart       LoadingView, EmptyStateView, RetryErrorView
```

`ApiClient` contract every service relies on: `get/post/put` return decoded JSON on
2xx, throw `ApiException` with the backend's `detail` message otherwise. Every
screen catches `ApiException` for the exact backend message and a generic
`catch (_)` for network failures — that split is what gives you the loading/
error states the HLD asks for, without duplicating logic per screen.

Build order: `api_client.dart` → `auth_service.dart` → Register + Verify OTP
screens wired to a running backend → `app_state.dart` + secure storage →
Login + Home Gate → `profile_service.dart` + Profile screen → `task_service.dart`
+ Task Selection + Home.

## 6. Error message conventions
Keep these consistent, they're what the UI shows verbatim:
- Wrong OTP: `"Incorrect code. {n} attempt(s) left."`
- Too many attempts: `"Too many wrong attempts. Please request a new code."`
- Expired: `"This code has expired. Please request a new one."`
- Unverified login: `"Please verify your email before logging in"`
- Resend cooldown: `"Please wait {n}s before requesting another code"`
