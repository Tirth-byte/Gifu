#!/usr/bin/env bash
# ==============================================================================
# Gufi CodeGraph Query CLI Wrapper
#
# Location-independent query tool for AI coding agents and developers.
# Resolves repository root dynamically and queries semantic AST, symbol definitions,
# callers, callees, dependencies, and persistent memory without directory traversal.
#
# Usage:
#   ./scripts/query_codegraph.sh symbols <query>
#   ./scripts/query_codegraph.sh callers <symbol_name_or_file>
#   ./scripts/query_codegraph.sh callees <symbol_name_or_file>
#   ./scripts/query_codegraph.sh impact <file_path> <line_number>
#   ./scripts/query_codegraph.sh deps <file_path>
#   ./scripts/query_codegraph.sh tests <file_path>
#   ./scripts/query_codegraph.sh memories
#   ./scripts/query_codegraph.sh raw <tool_name> '<json_args>'
# ==============================================================================

set -euo pipefail

# Dynamically resolve repository root (location-independent)
if git rev-parse --show-toplevel &>/dev/null; then
    REPO_ROOT="$(git rev-parse --show-toplevel)"
else
    REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Portable CodeGraph binary discovery
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

if [ -z "${CODEGRAPH_BIN}" ]; then
    echo "Error: codegraph-server binary not found. Install it to ~/.cargo/bin or PATH." >&2
    exit 1
fi

ACTION="${1:-help}"

case "${ACTION}" in
    symbols|search)
        QUERY="${2:-}"
        if [ -z "${QUERY}" ]; then
            echo "Usage: $0 symbols <symbol_or_text>" >&2
            exit 1
        fi
        "${CODEGRAPH_BIN}" --graph-only -w "${REPO_ROOT}" --run-tool codegraph_symbol_search \
            --tool-args "{\"query\": \"${QUERY}\"}" 2>/dev/null
        ;;
    impact)
        FILE="${2:-}"
        LINE="${3:-1}"
        if [ -z "${FILE}" ]; then
            echo "Usage: $0 impact <file_path> [line_number]" >&2
            exit 1
        fi
        if [[ "${FILE}" != file://* ]]; then
            FILE="file://${REPO_ROOT}/${FILE#${REPO_ROOT}/}"
        fi
        "${CODEGRAPH_BIN}" --graph-only -w "${REPO_ROOT}" --run-tool codegraph_analyze_impact \
            --tool-args "{\"uri\": \"${FILE}\", \"line\": ${LINE}}" 2>/dev/null
        ;;
    tests)
        FILE="${2:-}"
        if [ -z "${FILE}" ]; then
            echo "Usage: $0 tests <file_path>" >&2
            exit 1
        fi
        if [[ "${FILE}" != file://* ]]; then
            FILE="file://${REPO_ROOT}/${FILE#${REPO_ROOT}/}"
        fi
        "${CODEGRAPH_BIN}" --graph-only -w "${REPO_ROOT}" --run-tool codegraph_find_related_tests \
            --tool-args "{\"uri\": \"${FILE}\"}" 2>/dev/null
        ;;
    deps|dependencies)
        FILE="${2:-}"
        if [ -z "${FILE}" ]; then
            echo "Usage: $0 deps <file_path>" >&2
            exit 1
        fi
        if [[ "${FILE}" != file://* ]]; then
            FILE="file://${REPO_ROOT}/${FILE#${REPO_ROOT}/}"
        fi
        "${CODEGRAPH_BIN}" --graph-only -w "${REPO_ROOT}" --run-tool codegraph_get_dependency_graph \
            --tool-args "{\"uri\": \"${FILE}\"}" 2>/dev/null
        ;;
    callers)
        SYMBOL="${2:-}"
        if [ -z "${SYMBOL}" ]; then
            echo "Usage: $0 callers <symbol_name>" >&2
            exit 1
        fi
        "${CODEGRAPH_BIN}" --graph-only -w "${REPO_ROOT}" --run-tool codegraph_get_callers \
            --tool-args "{\"symbol_name\": \"${SYMBOL}\"}" 2>/dev/null
        ;;
    callees)
        SYMBOL="${2:-}"
        if [ -z "${SYMBOL}" ]; then
            echo "Usage: $0 callees <symbol_name>" >&2
            exit 1
        fi
        "${CODEGRAPH_BIN}" --graph-only -w "${REPO_ROOT}" --run-tool codegraph_get_callees \
            --tool-args "{\"symbol_name\": \"${SYMBOL}\"}" 2>/dev/null
        ;;
    memories|memory)
        CODEGRAPH_SKIP_MEMORY_CHECK=1 "${CODEGRAPH_BIN}" -w "${REPO_ROOT}" \
            --run-tool codegraph_memory_list --tool-args '{}' 2>/dev/null
        ;;
    raw)
        TOOL="${2:-}"
        ARGS="${3:-{}}"
        if [ -z "${TOOL}" ]; then
            echo "Usage: $0 raw <tool_name> '<json_args>'" >&2
            exit 1
        fi
        "${CODEGRAPH_BIN}" --graph-only -w "${REPO_ROOT}" --run-tool "${TOOL}" \
            --tool-args "${ARGS}" 2>/dev/null
        ;;
    help|*)
        echo "Gufi CodeGraph Query Interface"
        echo ""
        echo "Commands:"
        echo "  $0 symbols <query>        Search functions, classes, and files by name"
        echo "  $0 impact <file> [line]   Analyze impact / blast radius of changing a file"
        echo "  $0 tests <file>           Find tests covering a specific source file"
        echo "  $0 deps <file>            Get dependency graph for a file"
        echo "  $0 callers <symbol>       Find callers of a function or method"
        echo "  $0 callees <symbol>       Find callees called by a function or method"
        echo "  $0 memories               List durable architectural memory entries"
        echo "  $0 raw <tool> '<args>'    Execute any CodeGraph MCP tool directly"
        ;;
esac
