#!/usr/bin/env bash
# ==============================================================================
# Interactive Single-Pillar & Full-Suite CodeMender Runner (`test-pillar.sh`)
#
# Usage:
#   bash ./scripts/test-pillar.sh 1     # Test Pillar 1 (Direct cm find + report)
#   bash ./scripts/test-pillar.sh 2     # Test Pillar 2 (MCP Server JSON-RPC tools)
#   bash ./scripts/test-pillar.sh 3     # Test Pillar 3 (Skill workflow + PoC verify)
#   bash ./scripts/test-pillar.sh 4     # Test Pillar 4 (AGY Hook stdin JSON gate)
#   bash ./scripts/test-pillar.sh all   # Run all 4 pillars + export SARIF/MD/JSON reports
# ==============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_ROOT}/scripts/check-prerequisites.sh"
cd "${REPO_ROOT}"

PILLAR="${1:-}"

run_pillar_1() {
  echo "=================================================================="
  echo "TESTING PILLAR 1: Direct Developer Scan, Fix & Report (app.js)"
  echo "=================================================================="
  cm find examples/pillar-1-ide-guardrails/app.js --model gemini-3.7-flash -y --compact
  echo ""
  echo "--> Current Findings Table (cm report):"
  cm report
  echo ""
  echo "--> Generated Patches (cm report --patches):"
  cm report --patches
}

run_pillar_2() {
  echo "=================================================================="
  echo "TESTING PILLAR 2: CodeMender MCP Server Tools (JSON-RPC over stdio)"
  echo "=================================================================="
  echo "--> [Trigger 2A] Calling MCP tool 'scan_dependencies' on typosquatted package 'reqeusts@2.31.0'..."
  echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"scan_dependencies","arguments":{"system":"PYPI","package_name":"reqeusts","version":"2.31.0"}}}' \
    | python3 ./antigravity-setup/codemender_mcp_server.py
  echo ""
  echo "--> [Trigger 2B] Calling MCP tool 'cm_find' on 'examples/pillar-2-mcp-tools/app_vulnerable.py'..."
  echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"cm_find","arguments":{"target_path":"examples/pillar-2-mcp-tools/app_vulnerable.py"}}}' \
    | python3 ./antigravity-setup/codemender_mcp_server.py
}

run_pillar_3() {
  echo "=================================================================="
  echo "TESTING PILLAR 3: 4-Step Security Skill Workflow & Live PoC Exploit"
  echo "=================================================================="
  echo "--> [Step 1 & 2] Threat Model & Security Plan artifacts:"
  ls -la examples/pillar-3-agent-skills/1_THREAT_MODEL.md examples/pillar-3-agent-skills/2_SECURITY_PLAN.md
  echo ""
  echo "--> [Step 3] Running 'cm find' on server.vulnerable.js via Vertex AI..."
  cm find examples/pillar-3-agent-skills/server.vulnerable.js --model gemini-3.7-flash -y --compact
  echo ""
  echo "--> [Step 4] Running live PoC Exploit verification (3_poc_exploit.sh)..."
  bash ./examples/pillar-3-agent-skills/3_poc_exploit.sh
}

run_pillar_4() {
  echo "=================================================================="
  echo "TESTING PILLAR 4: Antigravity PreToolUse Hook (JSON stdin -> cm find)"
  echo "=================================================================="
  echo "--> Simulating Antigravity agent calling 'write_to_file' with unsafe eval()..."
  set +e
  echo '{"toolCall":{"name":"write_to_file","args":{"TargetFile":"calc.js","CodeContent":"const express = require(\"express\"); const app = express(); app.get(\"/calc\", (req, res) => { res.send(String(eval(req.query.formula))); });"}}}' \
    | bash ./examples/pillar-4-hooks-automation/post_edit_codemender_hook.sh
  EXIT_CODE=$?
  set -e
  echo ""
  echo "--> Hook exited with code ${EXIT_CODE} (Exit code 2 = DENY / BLOCKED unsafe agent edit!)"
}

case "${PILLAR}" in
  1) run_pillar_1 ;;
  2) run_pillar_2 ;;
  3) run_pillar_3 ;;
  4) run_pillar_4 ;;
  all)
    cm init --verify
    run_pillar_1
    run_pillar_2
    run_pillar_3
    run_pillar_4
    mkdir -p "${REPO_ROOT}/artifacts"
    cm report --format md > "${REPO_ROOT}/artifacts/codemender-report.md"
    cm report --format json > "${REPO_ROOT}/artifacts/codemender-report.json"
    cm report --format sarif > "${REPO_ROOT}/artifacts/codemender-report.sarif"
    echo "✅ All 4 pillars verified and reports exported to artifacts/!"
    ;;
  *)
    echo "Usage: bash ./scripts/test-pillar.sh <1|2|3|4|all>"
    exit 1
    ;;
esac
