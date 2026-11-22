# AI Agent Guidance & Instructions for Gufi

This document defines mandatory protocols for all AI coding agents working on the Gufi codebase.

---

## Gufi Codebase Navigation

The Gufi codebase maintains a persistent architectural index and knowledge graph. Blind directory traversal, broad text-pattern grepping, and recursive file scanning waste context and are strictly prohibited.

### Protocol for Every Coding Agent

#### 1. Fast Agent Workflow (Minimum Token Usage)

```
USER REQUEST
   ↓
FEATURE_INDEX.md lookup
   ↓
CodeGraph symbol query (./scripts/query_codegraph.sh)
   ↓
Callers / dependencies check if modifying shared code
   ↓
Targeted file reads (strictly 2–5 relevant files)
   ↓
Code edit
   ↓
Relevant feature tests (flutter test test/path/to/test.dart)
   ↓
Refresh CodeGraph index
   ↓
Update curated architecture maps ONLY if structural change occurred
```

#### 2. BEFORE Editing Code:
1. **Consult the Feature Index:**
   Always start by reading [`docs/codebase/FEATURE_INDEX.md`](docs/codebase/FEATURE_INDEX.md). Locate the exact screen, controller, repository, models, and tests relevant to the user request.
2. **Consult Architectural Maps When Needed:**
   - Master architecture & dependencies: [`docs/codebase/CODEBASE_MAP.md`](docs/codebase/CODEBASE_MAP.md)
   - Navigation guards & router logic: [`docs/codebase/ROUTE_MAP.md`](docs/codebase/ROUTE_MAP.md)
   - End-to-end data flows & RPCs: [`docs/codebase/DATA_FLOW.md`](docs/codebase/DATA_FLOW.md)
   - Invariants and safety constraints: [`docs/codebase/CHANGE_RULES.md`](docs/codebase/CHANGE_RULES.md)
3. **Query CodeGraph:**
   Use CodeGraph or `./scripts/query_codegraph.sh` to look up symbol definitions, callers, callees, and dependencies instead of searching across the entire workspace.
4. **Targeted File Reads Only:**
   Read strictly the 2–5 files necessary for the change. Do not recursively inspect directory trees.
5. **Run Impact Analysis Before Modifying Shared/Core Code:**
   Before altering any file under `lib/core/` or `lib/app/`, verify all dependent features and call sites using `./scripts/query_codegraph.sh impact <file> <line>`.

#### 3. AFTER Making Structural Changes:
After any **STRUCTURAL** change, before considering the task complete, you MUST run:
```bash
./scripts/refresh_codebase_map.sh
```

**What counts as a structural change:**
* New, deleted, or renamed screen or page.
* New, deleted, or renamed Dart file in `lib/` or `test/`.
* Route additions, removals, or redirect logic changes in `lib/app/router.dart`.
* Repository, service, or domain model additions or signature changes.
* Major feature boundary or provider changes.
* Test suite architecture changes.

**What is NOT a structural change:**
* Ordinary styling, color, padding, typography, or copy edits inside an existing widget.
* Bug fixes or logic adjustments inside an existing function or controller without signature changes.
* For purely visual or localized changes, simple CodeGraph incremental re-indexing is sufficient. Do NOT force full documentation updates for small UI changes.

#### 4. Mandatory Verification Suite Before Finishing:
```bash
./scripts/refresh_codebase_map.sh --check
flutter analyze
flutter test
git diff --check
```
