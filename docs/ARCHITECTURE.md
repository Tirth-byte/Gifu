# Gufi — Application Architecture & Data Flow

This document defines the single source of truth for Gufi's data flow, state management, and navigation contracts.

---

## 1. Auth Flow

```
Supabase GoTrue (or local GufiBackendStore)
  ↓
SupabaseAuthRepository (Singleton `SupabaseAuthRepository.instance`)
  ↓
authStateChanges Stream & cached UserProfile
  ↓
Riverpod Providers (`authRepositoryProvider`, `authStateChangesProvider`, `currentUserProfileAsyncProvider`)
  ↓
App Routing & UI Screens
```

- **One Shared Repository**: `SupabaseAuthRepository.instance` ensures that all Riverpod providers, router guards, and auth widgets observe the identical `_cachedProfile`.
- **Zero Mock Fallbacks**: When no user is authenticated, profile state is cleanly `null` or loading. No fake identities (e.g. `@gufiuser`, `@member`).

---

## 2. Signup Flow

```
1. Email Entry        → Disposable domain rejection & format validation
  ↓
2. Password Entry     → Strength requirements checked
  ↓
3. Confirmation       → Password matching verified
  ↓
4. Auth User Created  → Supabase GoTrue account provisioned
  ↓
5. Verification       → Email confirmation link/code verified
  ↓
6. Username Selection → Live uniqueness check against database
  ↓
7. Profile Completion → Display name & optional photo uploaded
  ↓
8. Done               → `onboardingCompleted = true`, routed to `/today`
```

---

## 3. User Data Flow

```
Backend Database (`public.users` table)
  ↓
SupabaseAuthRepository
  ↓
Canonical Domain Model (`UserProfile`)
  ↓
`currentUserProfileAsyncProvider` / `currentUserProfileProvider`
  ↓
UI (`TodayPage`, `AuthPage`)
```

- **Canonical Entity**: Exactly one profile entity (`UserProfile`) holds user identity across the application:
  `id`, `email`, `emailNormalized`, `emailVerified`, `username`, `usernameNormalized`, `displayName`, `profilePhotoUrl`, `authProvider`, `role`, `onboardingCompleted`, `accountStatus`, `createdAt`, `updatedAt`.

---

## 4. Admin Data Flow

```
Server-Verified Role (`role == 'admin' && accountStatus == 'active'`)
  ↓
SupabaseAdminRepository
  ↓
- Metrics Query       → Computed live from real user records (`fetchMetrics`)
- Database Grid Query → Filtered, searched, and sorted (`fetchUsers`)
- User Detail Sheet   → Status toggles (`setUserStatus`) with confirmation
- Audit Logs Query    → Sensitive actions tracked (`admin_audit_logs`)
- CSV Exporter        → RFC-4180 compliant with UTF-8 BOM & sanitized fields
  ↓
Admin UI (`AdminDashboardPage`, `AdminDatabaseGridPage`, `AdminUserDetailSheet`)
```

---

## 5. Routing Architecture

| State | Condition | Destination |
| :--- | :--- | :--- |
| **First Launch** | Unauthenticated | `/` (Onboarding Screen 1) → `/screen-2` → `/auth` |
| **Back Navigation** | `/auth` back button | Pops back to `/screen-2`, preserving onboarding state |
| **Incomplete Profile** | Authenticated + `!onboardingCompleted` | Pushes missing setup step (`username` or `profile`) |
| **Standard User** | Authenticated + `onboardingCompleted` | `/today` (Gufi Today Screen) |
| **Admin User** | Authenticated + `role == 'admin'` | `/admin` (Admin Control Center & Database Grid) |
| **Logout** | Session cleared | Resets auth state and redirects to `/auth` |

---

## 6. Admin Designation

Administrator privileges cannot be escalated on the client. To designate an admin in Supabase SQL Editor:

```sql
UPDATE public.users
SET role = 'admin',
    account_status = 'active',
    email_verified = true,
    onboarding_completed = true,
    updated_at = NOW()
WHERE email_normalized = LOWER(TRIM('your_admin_email@example.com'));
```

---

## 7. Gufi Core Loop

Gufi is NOT a generic task manager. Once a promise is committed, failure cannot be silently erased.

```
CHOOSE → COMMIT → DO → PROVE → VERIFY → GROW
(Circle → Commitment → Proof → Review → Daily Result → Momentum)
```

### State Machine

```
              ┌──────────────┐
              │    DRAFT     │
              └──────┬───────┘
                     │ Commit (max 3/day)
                     ▼
              ┌──────────────┐
       ┌─────▶│  COMMITTED   │───────────┬──────────────┐
       │      └──────┬───────┘           │              │
       │             │ Submit Proof      │ Cancel       │ Deadline expired
Resubmit             ▼                   ▼              ▼
       │      ┌──────────────┐     ┌───────────┐  ┌───────────┐
       │      │PROOF_SUBMITTED│    │ CANCELLED │  │  MISSED   │
       │      └───┬──────┬───┘     │ (Terminal)│  │ (Terminal)│
       │   Approve│      │ Reject  └───────────┘  └─────▲─────┘
       │          │      ▼                              │
       │          │  ┌──────────┐   Correction expired   │
       │          │  │ REJECTED │───────────────────────┘
       │          │  └────┬─────┘ (6-hour window if on-time)
       │          │       │
       │          │       └─▶ Resubmit Proof
       │          ▼
       │     ┌──────────┐
       └─────│ VERIFIED │ (Terminal)
             └──────────┘
```

- **Allowed Transitions**:
  `draft` → `committed` → `proof_submitted` → `verified`
  `proof_submitted` → `rejected` → `proof_submitted`
  `committed` → `cancelled`, `committed` → `missed`
  `rejected` → `missed` (after 6-hour correction deadline expires)
- **Terminal States**: `verified`, `missed`, `cancelled` (immutable once resolved).
- **Drafts**: Editable, deletable, zero impact on Momentum.

### Key Database Tables

| Table | Purpose | Integrity & Constraints |
| :--- | :--- | :--- |
| `public.circles` | Accountability groups | `owner_id` FK to `public.users(id)` |
| `public.circle_members` | Membership & roles | Unique `(circle_id, user_id)`, owner auto-joined |
| `public.commitments` | Sacred daily promises | Single state machine, server RPC atomic check |
| `public.proofs` | Photo / text verification | `submitter_id` FK, `status IN ('submitted', 'superseded')` |
| `public.reviews` | Peer verification decisions | Unique `(proof_id, reviewer_id)`, owner cannot self-review |
| `public.commitment_events` | Immutable audit stream | Append-only event log powering analytics & history |
| `public.daily_results` | Materialized daily summary | Unique `(user_id, gufi_day)`, live recalculated |
| `storage.buckets('proofs')` | Private media store | Accessible only by submitter, circle members & admin |

### Ownership & Security

- **Server-Authoritative**: Client cannot fabricate `status = 'verified'` or `status = 'missed'`.
- **Peer Review Only**: Only active circle members can review. Commitment owner cannot review own proof.
- **One Approval Rule**: Exactly 1 eligible circle member approval verifies the commitment.
- **3-Commitment Rule**: Maximum 3 committed commitments per user per Gufi day, transactionally locked server-side.

### Authoritative Gufi Day & IANA Timezone Strategy

A Gufi Day runs from **04:00 local time to 03:59:59.999 next calendar day**:
- **Timezone Identifier**: Canonical user timezone is stored as an **IANA Timezone Identifier** (e.g. `America/New_York`, `Europe/London`, `Asia/Kolkata`).
- **Daylight Saving Time (DST) Safety**: Named IANA zones automatically handle seasonal offset changes (e.g. EST/EDT, GMT/BST) without date arithmetic drifting or breaking the 04:00 boundary.
- **Fixed Offsets Supported**: Fallback support for fixed UTC offsets (`+05:30`, `UTC`).
- **Overnight Protection**: On-time proofs awaiting peer review across day boundaries are **never marked missed** overnight.
- **Correction Window**: If a proof submitted on time is rejected after the deadline, a **6-hour correction window** is created.

### Server-Side Missed Evaluation Scheduler (`pg_cron`)

- Missed evaluation is executed autonomously on the server via Supabase's native `pg_cron` extension.
- **Job Name**: `evaluate-missed-commitments-job`
- **Schedule**: `* * * * *` (every minute)
- **Function**: `SELECT public.evaluate_missed_commitments();`
- **Zero Client Reliance**: Evaluates unsubmitted overdue commitments and expired correction windows automatically without requiring any user to open Gufi.

### Momentum Formula

Calculated over a rolling 7-Gufi-day window:

$$\text{Momentum} = \frac{\text{Verified}}{\text{Verified} + \text{Missed} + \text{Cancelled}} \times 100$$

- **Cancelled = Not Kept**: Cancellations count in the denominator so users cannot game their score.
- **Excluded**: `draft`, `committed` (pending), `proof_submitted` (awaiting review), and `rejected` (in correction window).
- **Neutral State**: If resolved count is 0, score is `null` (displayed as neutral / no data, NOT 100%).
