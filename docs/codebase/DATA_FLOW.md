# Gufi Data Flow Architecture

> **Data Flow Maps for Core Operations**
> Tracing UI interactions through Repositories, Supabase RPCs, and State Controllers.

---

## 1. Authentication & Session Restore Flow

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant UI as AuthPage
    participant Repo as SupabaseAuthRepository
    participant SupaAuth as Supabase.instance.client.auth
    participant DB as Supabase DB (users table)
    participant Router as appRouter

    Note over User,Router: Quick Login / Standard OTP Flow
    User->>UI: Enters email & password (or taps Dev A / Dev B)
    UI->>Repo: signInWithPassword(email, password)
    Repo->>SupaAuth: signInWithPassword(...)
    SupaAuth-->>Repo: AuthResponse (session + user)
    Repo->>DB: select profile where id = user.id
    DB-->>Repo: UserProfile record
    Repo-->>UI: AuthResultSuccess(profile)
    UI->>Router: context.go('/')
    Router->>Router: _resolveUserLandingRoute()
    Router-->>User: Navigates to /today, /circle-entry, or /circle-invite/:id
```

---

## 2. Circle Creation Flow

```mermaid
sequenceDiagram
    autonumber
    actor Creator
    participant UI as CircleCreatePage
    participant Repo as SupabaseCircleRepository
    participant DB as Supabase DB
    participant Router as appRouter

    Creator->>UI: Submits circle name & optional custom code
    UI->>Repo: createCircle(name: ..., ownerId: ..., requestId: ...)
    Note over Repo,DB: Idempotent atomic creation
    Repo->>DB: INSERT into circles (id, name, owner_id)
    Repo->>DB: INSERT into circle_members (circle_id, user_id, role='owner')
    Repo->>DB: INSERT into circle_invites (circle_id, code, creator_id)
    DB-->>Repo: Created Circle & primary CircleInvite
    Repo-->>UI: Circle object
    UI->>Router: context.go('/circle-invite/{circle.id}')
    Note over UI,Router: Shows QR code & invite share link (waiting room)
```

---

## 3. Circle Join Flow (Code / QR Scanner)

```mermaid
sequenceDiagram
    autonumber
    actor Member
    participant UI as CircleJoinPage
    participant Repo as SupabaseCircleRepository
    participant DB as Supabase DB
    participant Router as appRouter

    Member->>UI: Enters invite code or scans QR with mobile_scanner
    UI->>Repo: resolveInvite(code)
    Repo->>DB: SELECT invite, circle, active members
    DB-->>Repo: CirclePreview data
    UI-->>Member: Renders preview card (circle name, creator, member count)
    Member->>UI: Taps "Join Circle"
    UI->>Repo: joinCircle(inviteCode, userId)
    Repo->>DB: INSERT into circle_members (status='active')
    Repo->>DB: UPDATE circle_invites (increment use_count)
    DB-->>Repo: Success
    UI->>Router: context.go('/today')
```

---

## 4. Daily Promise Creation Flow (Atomic 3-Limit Enforcement)

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Sheet as MakePromiseSheet
    participant Controller as TodayController
    participant Repo as SupabaseCommitmentRepository
    participant DB as Supabase DB (commitments table)

    User->>Sheet: Fills title, due time, selects Circle/Private scope
    User->>Sheet: Taps "Make Promise"
    Sheet->>Controller: createCommitment(...)
    Controller->>Repo: createCommitment(ownerId, title, gufiDay, scope, ...)
    Note over Repo,DB: Server-side check: COUNT active commitments for user on gufiDay <= 3
    Repo->>DB: INSERT into commitments (status='committed')
    DB-->>Repo: Commitment record
    Repo-->>Controller: Updated commitment
    Controller->>Controller: Refresh today state & commitments list
    Controller-->>Sheet: Dismiss modal
```

---

## 5. Proof Submission & Peer Review Loop

```mermaid
sequenceDiagram
    autonumber
    actor Promiser
    actor Peer
    participant ProofUI as CompletionProofSheet
    participant ReviewUI as ReviewProofSheet
    participant ProofRepo as SupabaseProofRepository
    participant ReviewRepo as SupabaseReviewRepository
    participant Storage as Supabase Storage (bucket: proofs)
    participant MomentumRepo as SupabaseMomentumRepository

    Promiser->>ProofUI: Takes/picks photo & enters notes
    ProofUI->>ProofRepo: uploadProofPhoto(commitmentId, imageBytes)
    ProofRepo->>Storage: upload to proofs/{commitment_id}/{timestamp}.jpg
    Storage-->>ProofRepo: storagePath
    ProofRepo->>ProofRepo: submitProof(commitmentId, storagePath, ...)
    Note over ProofRepo: Commitment moves to status: 'pending_review'

    Note over Peer,ReviewUI: Circle peer opens Today page
    Peer->>ReviewUI: Views proof photo and promise details
    Peer->>ReviewRepo: submitReview(commitmentId, reviewerId, verdict='approved')
    ReviewRepo->>ReviewRepo: Updates review status & triggers resolution
    Note over ReviewRepo: Commitment moves to status: 'completed'
    ReviewRepo->>MomentumRepo: recalculateDailyResult(ownerId, gufiDay)
    MomentumRepo->>MomentumRepo: Updates streak counters and Momentum Score
```
