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
8. Done               → `onboardingCompleted = true`, routed to `/coming-soon`
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
UI (`ComingSoonPage`, `AuthPage`)
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
| **Standard User** | Authenticated + `onboardingCompleted` | `/coming-soon` ("This Is Yours" holding screen) |
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
