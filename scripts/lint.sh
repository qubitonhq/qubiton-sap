#!/usr/bin/env bash
#
# Run abaplint locally with SAP standard-library stubs loaded.
#
# Why this script exists: abaplint by itself can't see SAP's standard
# library, so it flags every reference to cl_http_client, cx_root, LFA1,
# etc. as "not found". To get useful local validation, we point it at
# two open-source stub libraries that re-implement enough of the
# standard surface for static analysis.
#
# Coverage: fixes ~50% of abaplint noise on this connector. The rest
# (BAdI interfaces, DDIC tables, FI function modules) only resolve on
# a real SAP system. See docs/transaction-validation.md for the full
# verification workflow.
#
# Usage:
#   ./scripts/lint.sh           # full lint run
#   ./scripts/lint.sh --setup   # clone the dep stubs only
#   ./scripts/lint.sh --signal  # filter known noise; show only real issues
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPS_DIR="$REPO_ROOT/.deps"

setup_deps() {
  mkdir -p "$DEPS_DIR"

  if [ ! -d "$DEPS_DIR/open-abap-core" ]; then
    echo "→ Cloning open-abap/open-abap-core (stubs for cl_http_*, cx_*, cl_abap_*)..."
    git clone --depth 1 --quiet https://github.com/open-abap/open-abap-core.git "$DEPS_DIR/open-abap-core"
  fi

  if [ ! -d "$DEPS_DIR/abaplint-deps" ]; then
    echo "→ Cloning abaplint/deps (basic ABAP foundation classes)..."
    git clone --depth 1 --quiet https://github.com/abaplint/deps.git "$DEPS_DIR/abaplint-deps"
  fi

  echo "✓ Dependencies ready in .deps/"
}

run_lint() {
  cd "$REPO_ROOT"
  npx --yes @abaplint/cli@latest -f standard
}

run_lint_signal() {
  # Filter out abaplint noise that comes from missing SAP standard library
  # objects abaplint genuinely can't see (BAdI interfaces, DDIC tables,
  # SAP function modules, deep standard classes). What's left is the
  # signal: real bugs in our code.
  cd "$REPO_ROOT"
  npx --yes @abaplint/cli@latest -f standard 2>&1 | grep -v -E \
    'Method definition .*not found|Database table or view .*not found|"(im_|ch_|ex_|ev_|ec_|in_|et_|it_|is_|iv_|i_|e_)[a-z_0-9]+" not found|Method ".*" not found, methodCallChain|Class cl_.*not found|Class cx_.*not found|Unknown class .*|Super class ".*" not found|Not an object reference|Statement does not exist in ABAP|Unknown object type, currently not supported in abaplint|Method importing parameter "(TIMEOUT|MESSAGE)" does not exist|"is_but000" not found|"is_bp_data" not found|"iv_bpkind" not found'
}

case "${1:-lint}" in
  --setup|setup)
    setup_deps
    ;;
  --signal|signal)
    setup_deps
    run_lint_signal
    ;;
  --help|-h|help)
    grep '^#' "$0" | head -25
    ;;
  *)
    setup_deps
    run_lint
    ;;
esac
