#!/usr/bin/env bash
# ==============================================================================
# Install CodeMender Git Hooks (pre-commit & pre-push) into .git/hooks/
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ ! -d "${REPO_ROOT}/.git" ]]; then
  echo "❌ ERROR: No .git directory found in ${REPO_ROOT}." >&2
  echo "   Run 'git init' first in your standalone Git repository before installing Git hooks." >&2
  exit 1
fi

mkdir -p "${REPO_ROOT}/.git/hooks"

cp "${REPO_ROOT}/git-hooks/pre-commit" "${REPO_ROOT}/.git/hooks/pre-commit"
cp "${REPO_ROOT}/git-hooks/pre-push" "${REPO_ROOT}/.git/hooks/pre-push"
chmod +x "${REPO_ROOT}/.git/hooks/pre-commit" "${REPO_ROOT}/.git/hooks/pre-push"

echo "✅ Installed CodeMender Git hooks:"
echo "   • ${REPO_ROOT}/.git/hooks/pre-commit"
echo "   • ${REPO_ROOT}/.git/hooks/pre-push"
