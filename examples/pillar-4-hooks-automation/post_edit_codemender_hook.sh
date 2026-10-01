#!/usr/bin/env bash
# ==============================================================================
# Antigravity Security Gate Hook (`post_edit_codemender_hook.sh`)
# Supports:
#   1. Antigravity Live Hook Contract (JSON on stdin -> protojson on stdout)
#      Valid fields: {"decision": "allow"|"deny", "reason": "..."}
#   2. Direct CLI file path argument: bash post_edit_codemender_hook.sh <file>
# Strictly requires `cm` CLI and Google Cloud authentication (`GCP_PROJECT_ID`).
# Zero offline mocks/fallbacks: fails if `cm` is missing or errors out.
# ==============================================================================
set -euo pipefail

export PATH="${HOME}/.local/bin:/usr/local/bin:/opt/homebrew/bin:${PATH}"

if [[ -z "${GCP_PROJECT_ID:-}" ]]; then
  GCP_PROJECT_ID="$(gcloud config get-value project 2>/dev/null || true)"
  export GCP_PROJECT_ID
fi

if ! command -v cm >/dev/null 2>&1; then
  echo '{"decision": "deny", "reason": "ERROR: CodeMender CLI (cm) is not installed in PATH."}'
  exit 1
fi

TMP_DIR=""
cleanup() {
  if [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
  fi
}
trap cleanup EXIT

TARGET_FILE="${1:-}"

# Mode A: Called automatically by Antigravity Hook Engine (JSON payload on stdin)
if [[ -z "${TARGET_FILE}" ]]; then
  STDIN_JSON="$(cat)"
  TMP_DIR="$(mktemp -d /tmp/cm_agy_hook_XXXXXX)"
  TARGET_FILE="$(
    printf '%s' "${STDIN_JSON}" | python3 -c '
import json, os, sys
data = json.load(sys.stdin)
args = data.get("toolCall", {}).get("args", {})
target = args.get("TargetFile", "")
ext = os.path.splitext(os.path.basename(target))[1].lower()
# Only gate source code files; allow docs/config edits without scanning markdown
code_exts = {".js", ".ts", ".jsx", ".tsx", ".py", ".go", ".java", ".rb", ".php", ".c", ".cc", ".cpp", ".rs"}
if ext not in code_exts:
    print("SKIP_NON_CODE")
    sys.exit(0)
# Allow intentional *.vulnerable.* training fixture files in examples/
if ".vulnerable." in os.path.basename(target) or "app_vulnerable." in os.path.basename(target):
    print("SKIP_INTENTIONAL_VULNERABLE_FIXTURE")
    sys.exit(0)
content = args.get("CodeContent") or args.get("ReplacementContent") or ""
out_path = os.path.join(sys.argv[1], "candidate" + ext)
with open(out_path, "w") as f:
    f.write(content)
print(out_path)
' "${TMP_DIR}"
  )"

  if [[ "${TARGET_FILE}" == "SKIP_NON_CODE" || "${TARGET_FILE}" == "SKIP_INTENTIONAL_VULNERABLE_FIXTURE" ]]; then
    echo '{"decision": "allow", "reason": "Skipped non-code or intentional training fixture file."}'
    exit 0
  fi
fi

if [[ ! -f "${TARGET_FILE}" ]]; then
  echo "{\"decision\": \"deny\", \"reason\": \"Target file ${TARGET_FILE} not found.\"}"
  exit 1
fi

# Invoke live CodeMender CLI (`cm find`) via Google Cloud Vertex AI
set +e
CM_OUTPUT="$(cm find "${TARGET_FILE}" --model gemini-3.7-flash --compact -y 2>&1)"
CM_EXIT=$?
set -e

if echo "${CM_OUTPUT}" | grep -qiE "Found [1-9][0-9]* (potential )?vulnerabilit|\[(CRITICAL|HIGH|MEDIUM)\]|Severity:[[:space:]]*(CRITICAL|HIGH|MEDIUM)|CWE-"; then
  python3 -c '
import json, sys
print(json.dumps({
    "decision": "deny",
    "reason": "CodeMender CLI (cm find) blocked this edit because it introduces a security vulnerability. Fix the vulnerability and retry.\n\n" + sys.argv[1]
}))
' "${CM_OUTPUT}"
  exit 2
fi

if [[ "${CM_EXIT}" -ne 0 ]]; then
  python3 -c '
import json, sys
print(json.dumps({
    "decision": "deny",
    "reason": "CodeMender CLI (cm find) failed to execute. Check GCP_PROJECT_ID and gcloud auth.\n\n" + sys.argv[1]
}))
' "${CM_OUTPUT}"
  exit 1
fi

echo '{"decision": "allow", "reason": "CodeMender (cm find) verified 0 security vulnerabilities."}'
exit 0
