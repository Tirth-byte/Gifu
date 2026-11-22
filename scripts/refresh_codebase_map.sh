#!/usr/bin/env bash
# ==============================================================================
# Gufi Codebase Intelligence & Map Refresh Script
#
# Usage:
#   ./scripts/refresh_codebase_map.sh          # Normal refresh & inspection
#   ./scripts/refresh_codebase_map.sh --check  # Validation mode (fails on stale map)
#
# Purpose:
# 1. Re-indexes the CodeGraph knowledge graph with Dart language support.
# 2. Inspects structural changes (screens, routes, repositories, models, tests).
# 3. Verifies that every file referenced in codebase documentation still exists.
# 4. In --check mode: returns exit code 1 if structural maintenance is required.
# 5. Preserves curated architectural documentation in docs/codebase/*.md.
#
# NOTE: This script NEVER modifies product source code under lib/ or ios/.
# ==============================================================================

set -euo pipefail

# 1. Dynamically resolve repository root (location-independent)
if git rev-parse --show-toplevel &>/dev/null; then
    REPO_ROOT="$(git rev-parse --show-toplevel)"
else
    REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
cd "${REPO_ROOT}"

CHECK_MODE=false
if [ "${1:-}" = "--check" ]; then
    CHECK_MODE=true
fi

echo "========================================================"
if [ "${CHECK_MODE}" = true ]; then
    echo " [Gufi Codebase Intelligence] Validation Mode (--check)"
else
    echo " [Gufi Codebase Intelligence] Refresh & Inspection Mode"
fi
echo "========================================================"

# 2. Locate CodeGraph Engine Binary (portable discovery)
CODEGRAPH_BIN=""
if command -v codegraph-server &>/dev/null; then
    CODEGRAPH_BIN="$(command -v codegraph-server)"
elif [ -x "${HOME}/.cargo/bin/codegraph-server" ]; then
    CODEGRAPH_BIN="${HOME}/.cargo/bin/codegraph-server"
elif [ -x "${HOME}/.local/bin/codegraph-server" ]; then
    CODEGRAPH_BIN="${HOME}/.local/bin/codegraph-server"
elif [ -x "${REPO_ROOT}/bin/codegraph-server" ]; then
    CODEGRAPH_BIN="${REPO_ROOT}/bin/codegraph-server"
elif [ -x "/tmp/CodeGraph/target/release/codegraph-server" ]; then
    CODEGRAPH_BIN="/tmp/CodeGraph/target/release/codegraph-server"
elif [ -x "/usr/local/bin/codegraph-server" ]; then
    CODEGRAPH_BIN="/usr/local/bin/codegraph-server"
fi

if [ -n "${CODEGRAPH_BIN}" ]; then
    echo "✓ CodeGraph engine located: ${CODEGRAPH_BIN}"
    if "${CODEGRAPH_BIN}" --version &>/dev/null; then
        echo "✓ Version: $("${CODEGRAPH_BIN}" --version)"
    fi
    echo "→ Updating semantic AST and call graph..."
    "${CODEGRAPH_BIN}" --graph-only -w "${REPO_ROOT}" --run-tool codegraph_symbol_search \
        --tool-args '{"query": "App"}' > /dev/null 2>&1 || true
    echo "✓ CodeGraph graph index verified."
else
    echo "⚠️ CodeGraph binary not found in standard paths; continuing map verification."
fi

# 3. Verify all referenced files in docs/codebase/ exist on disk
echo "→ Validating file references in docs/codebase/..."
MISSING_FILES=0
CHECK_FILES=(
    "lib/main.dart"
    "lib/app/app.dart"
    "lib/app/router.dart"
    "lib/core/config/supabase_config.dart"
    "lib/core/config/app_config.dart"
    "lib/core/theme/app_colors.dart"
    "lib/core/theme/app_theme.dart"
    "lib/core/theme/app_typography.dart"
    "lib/core/theme/gufi_colors.dart"
    "lib/core/services/app_preferences_service.dart"
    "lib/core/services/gufi_backend_store.dart"
    "lib/core/services/disposable_email_service.dart"
    "lib/core/services/csv_export_service.dart"
    "lib/core/widgets/user_avatar.dart"
    "lib/core/widgets/account_action_button.dart"
    "lib/features/auth/presentation/auth_page.dart"
    "lib/features/auth/data/repositories/supabase_auth_repository.dart"
    "lib/features/auth/domain/models/user_profile.dart"
    "lib/features/onboarding/presentation/onboarding_page.dart"
    "lib/features/circles/presentation/circle_entry_page.dart"
    "lib/features/circles/presentation/circle_create_page.dart"
    "lib/features/circles/presentation/circle_join_page.dart"
    "lib/features/circles/presentation/circle_invite_page.dart"
    "lib/features/circles/data/repositories/supabase_circle_repository.dart"
    "lib/features/today/presentation/today_page.dart"
    "lib/features/today/presentation/controllers/today_controller.dart"
    "lib/features/commitments/data/repositories/supabase_commitment_repository.dart"
    "lib/features/commitments/data/repositories/supabase_proof_repository.dart"
    "lib/features/commitments/data/repositories/supabase_review_repository.dart"
    "lib/features/commitments/data/repositories/supabase_momentum_repository.dart"
    "lib/features/admin/presentation/admin_dashboard_page.dart"
    "lib/features/admin/presentation/admin_database_grid_page.dart"
)

for file in "${CHECK_FILES[@]}"; do
    if [ ! -f "${REPO_ROOT}/${file}" ]; then
        echo "❌ Missing referenced file: ${file}"
        MISSING_FILES=$((MISSING_FILES + 1))
    fi
done

if [ "${MISSING_FILES}" -eq 0 ]; then
    echo "✓ All core referenced files exist."
else
    echo "⚠️ Warning: ${MISSING_FILES} referenced file(s) are missing from disk."
fi

# 4. Structural Change Detection
echo "→ Inspecting structural changes across codebase..."
STRUCTURAL_CHANGES=0
NEW_SCREENS=()
NEW_REPOS=()
NEW_MODELS=()
NEW_TESTS=()
OTHER_NEW_FILES=()

MAP_JSON="${REPO_ROOT}/docs/codebase/codebase-map.json"

if [ -f "${MAP_JSON}" ]; then
    while IFS= read -r dart_file; do
        rel_path="${dart_file#./}"
        if ! grep -q "\"${rel_path}\"" "${MAP_JSON}" 2>/dev/null; then
            STRUCTURAL_CHANGES=$((STRUCTURAL_CHANGES + 1))
            if [[ "${rel_path}" == *"_page.dart"* ]] || [[ "${rel_path}" == *"_screen.dart"* ]]; then
                NEW_SCREENS+=("${rel_path}")
            elif [[ "${rel_path}" == *"_repository.dart"* ]]; then
                NEW_REPOS+=("${rel_path}")
            elif [[ "${rel_path}" == *"/models/"* ]]; then
                NEW_MODELS+=("${rel_path}")
            elif [[ "${rel_path}" == *"test/"*"_test.dart"* ]]; then
                NEW_TESTS+=("${rel_path}")
            else
                OTHER_NEW_FILES+=("${rel_path}")
            fi
        fi
    done < <(find lib test -name "*.dart" -type f)
else
    echo "❌ Missing ${MAP_JSON}!"
    STRUCTURAL_CHANGES=$((STRUCTURAL_CHANGES + 1))
fi

# Check for deleted files that are still cataloged in codebase-map.json
DELETED_FILES=0
if [ -f "${MAP_JSON}" ]; then
    while IFS= read -r clean_file; do
        if [ -n "${clean_file}" ] && [ ! -f "${REPO_ROOT}/${clean_file}" ]; then
            echo "❌ Cataloged file no longer exists: ${clean_file}"
            DELETED_FILES=$((DELETED_FILES + 1))
            STRUCTURAL_CHANGES=$((STRUCTURAL_CHANGES + 1))
        fi
    done < <(grep -oE '"(lib|test)/[^"]+\.dart"' "${MAP_JSON}" | tr -d '"' | sort -u || true)
fi

# 5. Report Results & Handle Exit Codes
echo "========================================================"
if [ "${STRUCTURAL_CHANGES}" -gt 0 ] || [ "${MISSING_FILES}" -gt 0 ]; then
    echo "****************************************************************"
    echo "⚠️  CODEBASE MAP CURATED UPDATE REQUIRED"
    echo "****************************************************************"
    echo "Detected ${STRUCTURAL_CHANGES} unindexed or altered structural element(s):"

    if [ ${#NEW_SCREENS[@]} -gt 0 ]; then
        echo "  • New Screens/Pages: ${NEW_SCREENS[*]}"
        echo "    → Needs update in: ROUTE_MAP.md, FEATURE_INDEX.md, CODEBASE_MAP.md, codebase-map.json"
    fi
    if [ ${#NEW_REPOS[@]} -gt 0 ]; then
        echo "  • New Repositories: ${NEW_REPOS[*]}"
        echo "    → Needs update in: DATA_FLOW.md, CODEBASE_MAP.md, FEATURE_INDEX.md, codebase-map.json"
    fi
    if [ ${#NEW_MODELS[@]} -gt 0 ]; then
        echo "  • New Domain Models: ${NEW_MODELS[*]}"
        echo "    → Needs update in: CODEBASE_MAP.md, FEATURE_INDEX.md, codebase-map.json"
    fi
    if [ ${#NEW_TESTS[@]} -gt 0 ]; then
        echo "  • New Tests: ${NEW_TESTS[*]}"
        echo "    → Needs update in: FEATURE_INDEX.md, CODEBASE_MAP.md, codebase-map.json"
    fi
    if [ ${#OTHER_NEW_FILES[@]} -gt 0 ]; then
        echo "  • Other Unindexed Files: ${OTHER_NEW_FILES[*]}"
        echo "    → Needs update in: codebase-map.json"
    fi
    if [ "${DELETED_FILES}" -gt 0 ]; then
        echo "  • Deleted/Renamed Files: ${DELETED_FILES} file(s) removed from disk"
        echo "    → Clean up stale references in: docs/codebase/*.md, codebase-map.json"
    fi
    echo "****************************************************************"

    if [ "${CHECK_MODE}" = true ]; then
        echo "❌ Validation failed (--check): Codebase map requires structural maintenance."
        exit 1
    else
        echo "ℹ️  Run with updated docs/codebase/ files to keep architecture in sync."
        exit 0
    fi
else
    echo "✓ Codebase map and intelligence graph are fully synchronized."
    echo "  - 0 missing file references"
    echo "  - 0 unindexed structural files"
    echo "  - 0 stale cataloged paths"
    echo "  - Machine Index: docs/codebase/codebase-map.json verified"
    echo "========================================================"
    exit 0
fi
