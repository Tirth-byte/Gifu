# Gufi Master Codebase Map

> **Master Architectural Index for Coding Agents**
> Consult this map before modifying the repository. Do not perform blind codebase scans.

---

## 1. Project Entry & Lifecycle

* **Entrypoint:** `lib/main.dart`
  * Initializes Flutter bindings (`WidgetsFlutterBinding.ensureInitialized()`).
  * Initializes local storage: `AppPreferencesService.instance.init()`, `GufiBackendStore.instance.init()`.
  * Initializes backend: `Supabase.initialize(url, anonKey)` using `SupabaseConfig`.
  * Configures system UI overlay (transparent status/navigation bars).
  * Boots root widget inside Riverpod: `runApp(const ProviderScope(child: App()))`.
* **App Root:** `lib/app/app.dart`
  * Configures `MaterialApp.router` with `AppTheme.lightTheme` and `appRouter`.
  * Precaches hero asset: `assets/images/gufi_hero_eye.png`.
* **Router & Navigation:** `lib/app/router.dart`
  * Implements `createAppRouter()`, session resolution `_resolveUserLandingRoute()`, route guards, and custom transitions.
  * Router instances: `SupabaseAuthRepository.instance`, `SupabaseCircleRepository.instance`.

---

## 2. Core Infrastructure (`lib/core/`)

* **Config:**
  * `lib/core/config/supabase_config.dart`: Supabase URL and Anon key loading with environment fallback.
  * `lib/core/config/app_config.dart`: App scheme (`gufi`), invite link builders, deep linking config.
* **Theme & Typography:**
  * `lib/core/theme/app_colors.dart`: Primary palettes, background, text, accent, feedback colors.
  * `lib/core/theme/gufi_colors.dart`: Semantic tokens, button gradients, glass surface colors.
  * `lib/core/theme/app_typography.dart`: Heading styles (Gambarino font family), body styles, captions.
  * `lib/core/theme/app_theme.dart`: ThemeData definition.
* **Shared Services:**
  * `lib/core/services/app_preferences_service.dart`: SharedPreferences wrapper (`pendingInviteCode`, flags).
  * `lib/core/services/gufi_backend_store.dart`: In-memory single-source-of-truth store for mock/preview/testing parity.
  * `lib/core/services/disposable_email_service.dart`: Email validation, normalization, and disposable domain blocklist.
  * `lib/core/services/csv_export_service.dart`: Data export utility for admin reporting.
* **Shared Widgets & Utilities:**
  * `lib/core/widgets/user_avatar.dart`: Deterministic avatar rendering, photo loader with initials fallback.
  * `lib/core/widgets/account_action_button.dart`: Standardized action button component.
  * `lib/core/utils/uuid_util.dart`: UUID generation helper.
  * `lib/core/haptics/app_haptics.dart`: System feedback haptic triggers.

---

## 3. Features

### Auth & Onboarding
* **Purpose:** First-run onboarding slides, authentication, email verification, session restore, and quick login tools.
* **Directory:** `lib/features/auth/`, `lib/features/onboarding/`
* **Presentation:**
  * `lib/features/onboarding/presentation/onboarding_page.dart`: Multi-step onboarding carousel with momentum gauges and pipeline trackers.
  * `lib/features/onboarding/presentation/screens/bootstrap_screen.dart`: Cold-launch fallback spinner.
  * `lib/features/onboarding/presentation/screens/onboarding_screen_2.dart`: Secondary onboarding view.
  * `lib/features/auth/presentation/auth_page.dart`: Email input, verification code entry, Quick Login buttons (Dev A / Dev B).
  * `lib/features/auth/presentation/screens/email_verification_screen.dart`: OTP input and code verification.
* **Domain / Models:**
  * `lib/features/auth/domain/models/user_profile.dart`: `UserProfile`, roles (`user`, `admin`), account status.
  * `lib/features/auth/domain/repositories/auth_repository.dart`: Interface for authentication operations.
* **Data / Repositories:**
  * `lib/features/auth/data/repositories/supabase_auth_repository.dart`: Supabase Auth client, session caching, OTP, profile syncing.
* **Providers:**
  * `lib/features/auth/presentation/providers/auth_providers.dart`: Riverpod auth state stream & profile providers.
* **Related Tests:**
  * `test/onboarding/cold_launch_flow_test.dart`
  * `test/onboarding/startup_state_machine_test.dart`
  * `test/widgets/quick_login_test.dart`
  * `test/widgets/auth_back_transition_test.dart`
  * `test/e2e_real_auth_admin_test.dart`

---

### Circles (Accountability Groups)
* **Purpose:** Creating, joining, previewing, and managing accountability circles with invite codes.
* **Directory:** `lib/features/circles/`
* **Presentation:**
  * `lib/features/circles/presentation/circle_entry_page.dart`: Gateway screen choosing "Create Circle" or "Join Circle".
  * `lib/features/circles/presentation/circle_create_page.dart`: Form to name circle and generate invite code.
  * `lib/features/circles/presentation/circle_join_page.dart`: Invite code resolver, QR code scanner integration (`mobile_scanner`).
  * `lib/features/circles/presentation/circle_invite_page.dart`: Waiting/invite room for circle creator (pending >= 2 members).
* **Domain / Models:**
  * `lib/features/circles/domain/models/circle.dart`: Circle entity, status, owner.
  * `lib/features/circles/domain/models/circle_member.dart`: CircleMember entity, roles (`owner`, `admin`, `member`), statuses.
  * `lib/features/circles/domain/models/circle_invite.dart`: Invite entity, usage counts, expiration, code formatting.
  * `lib/features/circles/domain/repositories/circle_repository.dart`: Interface for circle operations.
* **Data / Repositories:**
  * `lib/features/circles/data/repositories/supabase_circle_repository.dart`: Supabase database queries & RPCs for circles and members.
* **Providers:**
  * `lib/features/circles/presentation/providers/circle_providers.dart`: User circles provider, active circle provider.
* **Related Tests:**
  * `test/circles/circle_entry_routing_test.dart`
  * `test/circles/circle_create_page_test.dart`
  * `test/circles/circle_creation_idempotency_test.dart`
  * `test/circles/circle_join_page_test.dart`
  * `test/circles/circle_invite_page_test.dart`

---

### Commitments, Proofs, Reviews & Momentum
* **Purpose:** Daily promises (max 3/day), proof submissions (camera/photo), friend peer reviews, daily results, and momentum calculations.
* **Directory:** `lib/features/commitments/`
* **Domain / Models:**
  * `lib/features/commitments/domain/models/commitment.dart`: Commitment entity, status, title, due date, gufiDay.
  * `lib/features/commitments/domain/models/commitment_status.dart`: State machine transitions (`draft` -> `committed` -> `completed` / `missed` / `cancelled`).
  * `lib/features/commitments/domain/models/accountability_scope.dart`: Scope (`circle`, `private`).
  * `lib/features/commitments/domain/models/proof.dart`: Proof metadata, storage photo path, submission timestamps.
  * `lib/features/commitments/domain/models/proof_type.dart`: Allowed proof formats (`photo`, `checklist`, `numeric`, `text`).
  * `lib/features/commitments/domain/models/review.dart`: Peer review record, verdicts (`approved`, `rejected`), comments.
  * `lib/features/commitments/domain/models/daily_result.dart`: Day-level aggregation of promises and success outcome.
  * `lib/features/commitments/domain/models/momentum_result.dart`: Score computation, streak counters, status tags.
  * `lib/features/commitments/domain/models/commitment_event.dart`: Immutable audit event log.
  * `lib/features/commitments/domain/utils/gufi_day_utils.dart`: Gufi day cutoff calculation (4:00 AM local timezone transition).
* **Data / Repositories:**
  * `lib/features/commitments/data/repositories/supabase_commitment_repository.dart`: Commitments CRUD & commit RPC.
  * `lib/features/commitments/data/repositories/supabase_proof_repository.dart`: Supabase Storage upload and proof record creation.
  * `lib/features/commitments/data/repositories/supabase_review_repository.dart`: Peer review creation and approval flow.
  * `lib/features/commitments/data/repositories/supabase_momentum_repository.dart`: Daily result & momentum score calculation.
* **Providers:**
  * `lib/features/commitments/presentation/providers/commitment_providers.dart`: Riverpod access to repositories and active commitments.
* **Related Tests:**
  * `test/domain/commitment_lifecycle_test.dart`
  * `test/domain/commitment_limits_test.dart`
  * `test/domain/gufi_day_test.dart`
  * `test/domain/momentum_test.dart`
  * `test/domain/review_security_test.dart`
  * `test/domain/late_review_and_correction_test.dart`
  * `test/domain/core_loop_e2e_test.dart`

---

### Today (Main Dashboard & Core Loop)
* **Purpose:** Primary authenticated home screen: active promises list, hero momentum ring, peer reviews requiring action, bottom navigation.
* **Directory:** `lib/features/today/`
* **Presentation:**
  * `lib/features/today/presentation/today_page.dart`: Dashboard host, pull-to-refresh, bottom sheets orchestrator.
  * `lib/features/today/presentation/components/today_top_bar.dart`: User profile avatar, current date, notification bells.
  * `lib/features/today/presentation/components/today_hero_card.dart`: Momentum score display, streak ring, gauge.
  * `lib/features/today/presentation/components/today_commitment_card.dart`: Individual promise row with proof status pill.
  * `lib/features/today/presentation/components/friend_review_card.dart`: Pending review carousel from circle peers.
  * `lib/features/today/presentation/components/make_promise_sheet.dart`: Bottom modal sheet to draft and commit a new promise.
  * `lib/features/today/presentation/components/completion_proof_sheet.dart`: Modal to capture/upload proof photo for a commitment.
  * `lib/features/today/presentation/components/review_proof_sheet.dart`: Modal to inspect peer proof and approve/reject.
  * `lib/features/today/presentation/components/today_bottom_nav.dart`: Main 5-tab persistent bottom bar (Today, Circle, Add, Activity, Profile).
* **Controller / State:**
  * `lib/features/today/presentation/controllers/today_controller.dart`: StateNotifier managing dashboard loading, promise creation, proof submission, review approval.
  * `lib/features/today/presentation/controllers/today_state.dart`: Immutable state snapshot (`TodayState`).
* **Related Tests:**
  * `test/today/today_screen_test.dart`
  * `test/today/today_deterministic_copy_test.dart`
  * `test/two_account_acceptance_test.dart`

---

### Admin Dashboard & Data Grid
* **Purpose:** System oversight, user moderation, status toggling, raw database inspection for development.
* **Directory:** `lib/features/admin/`
* **Presentation:**
  * `lib/features/admin/presentation/admin_dashboard_page.dart`: Metrics cards, user summaries table, audit logs.
  * `lib/features/admin/presentation/admin_database_grid_page.dart`: Live table inspector for all Supabase tables.
  * `lib/features/admin/presentation/widgets/admin_user_detail_sheet.dart`: User detail modal with enable/disable toggles.
* **Domain / Data:**
  * `lib/features/admin/domain/models/admin_user_summary.dart`: Aggregated user record.
  * `lib/features/admin/domain/models/admin_audit_log.dart`: Admin audit log entry.
  * `lib/features/admin/data/repositories/supabase_admin_repository.dart`: Admin queries, disable user RPC, audit logger.
* **Related Tests:**
  * `test/admin_database_grid_test.dart`
  * `test/e2e_real_auth_admin_test.dart`
