# Gufi Engineering Change & Safety Rules

> **Mandatory Invariants for All Developers and Coding Agents**
> Every modification to the Gufi repository must respect the following constraints.

---

## 1. Routing & Lifecycle Invariants

* **Product State Owns Routing:** Navigation decisions must derive strictly from authenticated profile state, onboarding completion status, and active circle memberships (`lib/app/router.dart`).
* **Animations Never Control Navigation:** Animation controllers, tickers, or transition completions must NEVER determine the startup destination or gate routing redirects.
* **Unauthenticated Cold Launch:** Cold launches without a valid Supabase session MUST always land at Onboarding Screen 1 (`/`).
* **Circle Minimum Member Gate:** An authenticated user cannot enter `/today` unless they belong to at least one circle with $\ge 2$ active members; otherwise they must be held at `/circle-invite/:id` (waiting room) or `/circle-entry`.

---

## 2. Security & Credentials

* **`dev.secrets.json` Must Stay Gitignored:** Never stage or commit `dev.secrets.json` or any file containing live credentials.
* **No Service-Role Keys in Client:** The Flutter app must only ever receive the Supabase Anon Key. Never expose the Supabase `service_role` secret in Flutter code or `--dart-define`.
* **Zero Secrets in Git History:** Check `git diff --check` and verify no API keys, tokens, or personal passwords appear in staged changes.

---

## 3. Product & Domain Invariants

* **Max 3 Promises per Gufi Day:** No user may commit more than 3 promises in a single Gufi day. This limit is enforced at both the UI and repository levels.
* **Gufi Day Cutoff:** The Gufi day transitions at **4:00 AM** local time (`gufi_day_utils.dart`), not midnight. Promises due before 4:00 AM belong to the preceding calendar day.
* **Preserve Gufi Branding & Aesthetic:** Maintain the signature Gufi visual language:
  * Gambarino serif font for primary headings and momentum score figures.
  * Deep obsidian background (`#0B0E14`), subtle glass borders (`#1E2638`), and vibrant emerald/electric accents.
  * Haptic feedback on primary user commitments (`AppHaptics`).

---

## 4. Scope & Quality Control

* **Do Not Modify Unrelated Files:** Confine changes strictly to the feature, component, or bug under assignment.
* **Do Not Alter Supabase Schema Unprompted:** Database migrations and RPC modifications require explicit user direction.
* **Physical Device Verification:** Test on physical iPhone in Release mode (`flutter run --release`) before declaring mobile performance or frame-rate issues resolved.
* **Mandatory Pre-Commit Verification Suite:**
  ```bash
  dart format lib/ test/
  flutter analyze
  flutter test
  git diff --check
  ```
* **Controlled Incremental Changes:** Implement one logical change at a time with clean, descriptive git commit messages.
