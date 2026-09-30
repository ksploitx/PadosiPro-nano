# PadosiPro Nano — High Level Design

## 1. Scope

A native mobile app (Flutter) plus its own backend (FastAPI), replicating the
first-time-user journey of app.padosipro.com: register, verify email by OTP,
log in, fill profile, pick tasks, land on a home screen showing picks.

No WebView. No production PadosiPro API calls. Test data only.

## 2. System overview

```
[Flutter app] --HTTPS/JSON--> [FastAPI backend] --> [SQLite(padosipro.db)]
                                      |
                                      +--> [Redis]  (OTP resend cooldown)
                                      |
                                      +--> [SMTP]   (OTP email; Mailpit in dev)
```

Auth: JWT bearer token, issued on successful OTP verify or login, stored on
device, sent as `Authorization: Bearer <token>` on every protected call.

## 3. Backend modules

### 3.1 Auth module
Owns everything from signup to a valid session.

| Endpoint | Method | Auth | Purpose |
|---|---|---|---|
| `/auth/register` | POST | none | Create user (unverified), hash password, issue + email OTP |
| `/auth/resend-otp` | POST | none | Issue a new OTP if cooldown has passed and user isn't verified |
| `/auth/verify-otp` | POST | none | Check code, mark verified, return JWT |
| `/auth/login` | POST | none | Check credentials + verified flag, return JWT |

Rules it must enforce:
- Password: min 8 chars, letters + numbers. Hashed with bcrypt, never stored plain.
- OTP: 6 digits, numeric, hashed before storage, 10 min expiry, max 5 wrong attempts, single use, 30s resend cooldown.
- Login blocked for unverified users, with a message telling them to verify.
- Every validation error returns a consistent `{"detail": "..."}` shape.

### 3.2 Profile module
| Endpoint | Method | Auth | Purpose |
|---|---|---|---|
| `/profile` | PUT | JWT | Create or update Name, Mobile, Address, Business Name |
| `/profile` | GET | JWT | Fetch current profile (404 if not set yet — this is what the app uses to decide first-login vs. returning user) |

Rules:
- Mobile: exactly 10 digits, Indian format (starts 6-9), no country code stored.
- Business Name: optional (household users don't always have one).
- Name, Address: required, minimum length checks.

### 3.3 Task module
| Endpoint | Method | Auth | Purpose |
|---|---|---|---|
| `/tasks/catalogue` | GET | none | Return all tasks, grouped by category on the client |
| `/tasks/selection` | PUT | JWT | Replace the user's selected tasks with the given list |
| `/tasks/selection` | GET | JWT | Return the user's currently selected tasks |

Rules:
- Catalogue: minimum 20 tasks, minimum 4 categories, seeded at startup.
- Selection PUT is a full replace (idempotent), rejects empty list, rejects unknown task ids.

### 3.4 Cross-cutting
- Centralized exception handlers so validation errors (422) and business errors (4xx) both return `{"detail": "..."}`.
- CORS open in dev.
- `/health` endpoint for container healthchecks.

## 4. Data model

```
User            id, email (unique), password_hash, is_verified, has_completed_profile, created_at
Profile         id, user_id (FK, unique), name, mobile_number, address, business_name (nullable)
OtpCode         id, user_id (FK), code_hash, expires_at, attempts, consumed, created_at
Task            id, name, category, description
TaskSelection   id, user_id (FK), task_id (FK), created_at
```

One `User` has one `Profile`, many `OtpCode` rows (history), many `TaskSelection` rows.

## 5. Mobile app — screens

### 5.1 Splash / Root
- Purpose: decide where to land — checks for a stored JWT.
- No user-visible UI beyond a loading state.
- On no token → Login. On token present → ask backend for profile (see Home Gate below).

### 5.2 Register
- Fields: email, password, confirm password.
- Inline validation: email format, password strength (8+ chars, letter+number), password match.
- States: idle, submitting, error (inline banner with backend message).
- On success → Verify OTP screen, passing the email.

### 5.3 Verify OTP
- Fields: 6-digit code input.
- Countdown timer (30s) before "Resend" becomes tappable.
- States: idle, submitting, error (wrong code / expired / too many attempts — each a distinct backend message), resending.
- On success → first-login Profile screen (always shown right after verify, since this is a brand-new user).

### 5.4 Login
- Fields: email, password.
- States: idle, submitting, error.
- On success → Home Gate (decides Profile vs. Home based on live backend state, not a cached flag).
- Link to Register for new users.

### 5.5 Profile (first-login)
- Fields: Name, Mobile Number (+91 prefix shown, 10-digit input), Address (multiline), Business Name (optional).
- Inline validation matching backend rules.
- States: idle, submitting, error.
- On success → Task Selection.
- Shown once, right after first successful login/verify. Returning users with a saved profile skip straight to Home.

### 5.6 Task Selection
- Search bar (client-side filter on task name).
- Tasks grouped by category, each a checkbox row with name + short description.
- Multi-select, running count of selections.
- Confirm button, disabled/snackbar-blocked if nothing selected.
- States: loading catalogue, empty search results, network error with retry, saving.
- On confirm → Home.

### 5.7 Home
- Lists the user's selected tasks (name + category).
- Empty state if nothing selected yet.
- "Edit tasks" action → back into Task Selection, re-syncs on return.
- Logout action → clears token, back to Login.
- States: loading, error with retry, empty, populated.

### 5.8 Home Gate (routing logic, not a visible screen)
- After login/verify: calls `GET /profile`.
- 404 → Profile screen (first-login).
- 200 → Home.
- 401 → clear token, back to Login.
- other error → Home (which has its own retry state).

## 6. Non-functional requirements
- Every screen that talks to the network has loading, error (with retry where it makes sense), and empty states. No dead ends.
- Server validates every input regardless of what the client already checked.
- No secrets committed. `.env.example` only.
- OTP codes never logged or returned in any API response.
- Login persists across app restart (secure token storage).

## 7. Explicitly out of scope (v1)
- Password reset / forgot password.
- Push notifications.
- Real payment or task fulfillment logic.
- Multi-language support.
