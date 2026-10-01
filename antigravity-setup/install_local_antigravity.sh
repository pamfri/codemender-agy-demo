#!/usr/bin/env bash
# ==============================================================================
# Installer for CodeMender MCP Server, Skill & Hooks in Local Antigravity
# Installs into ~/.gemini/config/ (Antigravity Global Discovery Root)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

AGY_CONFIG_DIR="${HOME}/.gemini/config"
HOOKS_DIR="${AGY_CONFIG_DIR}/hooks"
SKILLS_DIR="${AGY_CONFIG_DIR}/skills/codemender-security-workflow"
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "🔍 [DRY RUN] Previewing CodeMender Local Antigravity installation..."
fi

RESOLVED_PROJECT_ID="${GCP_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || echo "<YOUR_GCP_PROJECT_ID>")}"

echo "=================================================================="
echo "Installing CodeMender MCP Server, Skill & Hooks into Antigravity:"
echo "  Target Directory: ${AGY_CONFIG_DIR}"
echo "  GCP Project ID:   ${RESOLVED_PROJECT_ID}"
echo "=================================================================="

if [[ "${DRY_RUN}" == "true" ]]; then
  echo "  [Pillar 2 - MCP]   Would install -> ${AGY_CONFIG_DIR}/codemender_mcp_server.py"
  echo "  [Pillar 2 - MCP]   Would install -> ${AGY_CONFIG_DIR}/mcp_config.json"
  echo "  [Pillar 3 - Skill] Would install -> ${SKILLS_DIR}/SKILL.md"
  echo "  [Pillar 4 - Hook]  Would install -> ${HOOKS_DIR}/post_edit_codemender_hook.sh"
  echo "  [Pillar 4 - Hook]  Would install -> ${AGY_CONFIG_DIR}/hooks.json"
  echo "✅ Dry run complete. Run without --dry-run to apply."
  exit 0
fi

mkdir -p "${HOOKS_DIR}" "${SKILLS_DIR}"

cp "${SCRIPT_DIR}/codemender_mcp_server.py" "${AGY_CONFIG_DIR}/codemender_mcp_server.py"
chmod +x "${AGY_CONFIG_DIR}/codemender_mcp_server.py"

cat <<EOF > "${AGY_CONFIG_DIR}/mcp_config.json"
{
  "mcpServers": {
    "codemender-mcp": {
      "command": "python3",
      "args": [
        "${AGY_CONFIG_DIR}/codemender_mcp_server.py"
      ],
      "env": {
        "PATH": "${HOME}/.local/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin",
        "GCP_PROJECT_ID": "${RESOLVED_PROJECT_ID}"
      }
    }
  }
}
EOF

cp "${REPO_ROOT}/_agents/skills/codemender-security-workflow/SKILL.md" "${SKILLS_DIR}/SKILL.md"
cp "${REPO_ROOT}/examples/pillar-4-hooks-automation/post_edit_codemender_hook.sh" \
   "${HOOKS_DIR}/post_edit_codemender_hook.sh"
chmod +x "${HOOKS_DIR}/post_edit_codemender_hook.sh"
cp "${REPO_ROOT}/_agents/hooks.json" "${AGY_CONFIG_DIR}/hooks.json"

echo "  ✔ [Pillar 2 - MCP Server] Installed: ${AGY_CONFIG_DIR}/mcp_config.json"
echo "  ✔ [Pillar 3 - AGY Skill]  Installed: ${SKILLS_DIR}/SKILL.md"
echo "  ✔ [Pillar 4 - AGY Hook]   Installed: ${HOOKS_DIR}/post_edit_codemender_hook.sh"
echo "  ✔ [Pillar 4 - AGY Hook]   Installed: ${AGY_CONFIG_DIR}/hooks.json"
echo "=================================================================="
echo "✅ CodeMender Local Antigravity Setup Complete!"
echo "=================================================================="
