# CodeMender + Antigravity Interactive Testing & Git Hooks Guide

This guide walks through:
1. **How each of the 4 Pillars integrates with CodeMender (`cm`)**
2. **How to test the Skill, MCP Server, and Agent Lifecycle Hook directly through the Coding Agent in Chat**
3. **How to test the Git Hooks (`pre-commit` & `pre-push`)**
4. **How to run single-pillar or full-suite CLI checks (`scripts/test-pillar.sh`)**

> **Strict Zero-Mock Policy**: Every tool, skill, agent hook, and Git hook in this repository invokes the real `cm` CLI and Google Cloud Vertex AI (`GCP_PROJECT_ID`). There are **no** offline regex fallbacks—if `cm` is missing, unauthenticated, or detects a vulnerability, execution fails with a non-zero exit code.

---

## 1. Prerequisites

Ensure the following tools are installed and authenticated on your machine (and on the host where your Coding Agent runs):

1. **CodeMender CLI (`cm`)**: Installed in `/usr/local/bin/cm` or `~/.local/bin/cm` (`cm --version`).
2. **Google Cloud SDK (`gcloud`)**: Authenticated with Application Default Credentials (ADC) and Vertex AI enabled:
   ```bash
   export GCP_PROJECT_ID="<YOUR_GCP_PROJECT_ID>"
   gcloud config set project "${GCP_PROJECT_ID}"
   gcloud services enable aiplatform.googleapis.com cloudresourcemanager.googleapis.com --project="${GCP_PROJECT_ID}"
   gcloud auth application-default login --project="${GCP_PROJECT_ID}"
   ```
3. **Install Antigravity Global Customizations (`~/.gemini/config/`)**:
   ```bash
   bash ./antigravity-setup/install_local_antigravity.sh
   ```
   *(Note: Project-level customizations in [`_agents/`](_agents/) are also discovered automatically when opening this repository in Antigravity.)*

---

## 2. How the 4 Pillars Differ

| Pillar | Integration Mechanism | Who Triggers `cm`? | Files Involved |
| :--- | :--- | :--- | :--- |
| **Pillar 1: IDE / Developer Guardrails** | Direct `cm` CLI (`cm find`, `cm verify`, `cm fix`, `cm report`) | **You (Developer)** in the terminal or IDE | [`examples/pillar-1-ide-guardrails/app.js`](examples/pillar-1-ide-guardrails/app.js), [`app.fixed.js`](examples/pillar-1-ide-guardrails/app.fixed.js), [`test.js`](examples/pillar-1-ide-guardrails/test.js) |
| **Pillar 2: MCP Server (`codemender-mcp`)** | Model Context Protocol (JSON-RPC over stdio) | **The Coding Agent** calling MCP tools (`scan_dependencies`, `cm_find`, `cm_verify`, `cm_fix`, `cm_report`) | [`antigravity-setup/codemender_mcp_server.py`](antigravity-setup/codemender_mcp_server.py), [`examples/pillar-2-mcp-tools/app_vulnerable.py`](examples/pillar-2-mcp-tools/app_vulnerable.py), [`requirements.txt`](examples/pillar-2-mcp-tools/requirements.txt) |
| **Pillar 3: Agent Skill (`SKILL.md`)** | Structured 4-Step Agent Prompt & Workflow | **The Coding Agent** following [`_agents/skills/codemender-security-workflow/SKILL.md`](_agents/skills/codemender-security-workflow/SKILL.md) | [`examples/pillar-3-agent-skills/server.vulnerable.js`](examples/pillar-3-agent-skills/server.vulnerable.js), `1_THREAT_MODEL.md`, `2_SECURITY_PLAN.md`, `3_poc_exploit.sh`, `4_SECURITY_AUDIT_REPORT.md` |
| **Pillar 4: Automated Hooks (Agent & Git)** | Event-driven `PreToolUse` Hook & Git `pre-commit`/`pre-push` Hooks | **Automatic Gatekeeper** (fires before file edits or before `git commit` / `git push`) | [`_agents/hooks.json`](_agents/hooks.json), [`examples/pillar-4-hooks-automation/post_edit_codemender_hook.sh`](examples/pillar-4-hooks-automation/post_edit_codemender_hook.sh), [`git-hooks/pre-commit`](git-hooks/pre-commit), [`git-hooks/pre-push`](git-hooks/pre-push) |

---

## 3. Testing via the Coding Agent (Antigravity Chat Prompts)

Open this repository in Antigravity and send these **3 prompts** in the **Agent Chat** to verify that the Coding Agent discovers and invokes the Skill, MCP Server, and `PreToolUse` Hook:

### Test A: Trigger Pillar 3 (Agent Skill `codemender-security-workflow`)
> **Prompt to send in Chat:**
> ```text
> Use the codemender-security-workflow skill to audit examples/pillar-3-agent-skills/server.vulnerable.js. Follow all 4 steps of the skill: read SKILL.md, verify the Threat Model and Security Plan, run live cm find/verify/fix, and generate the Security Audit Report.
> ```
**What to verify:**
- The agent reads [`_agents/skills/codemender-security-workflow/SKILL.md`](_agents/skills/codemender-security-workflow/SKILL.md) and executes the 4-step workflow (`1_THREAT_MODEL.md` $\rightarrow$ `2_SECURITY_PLAN.md` $\rightarrow$ `cm find` / `cm verify` / `cm fix` $\rightarrow$ `4_SECURITY_AUDIT_REPORT.md`).

### Test B: Trigger Pillar 2 (MCP Server `codemender-mcp`)
> **Prompt to send in Chat:**
> ```text
> Use the codemender-mcp server tools to:
> 1. Call scan_dependencies on PYPI packages "reqeusts" (version "2.31.0") and "pyyaml" (version "5.3.1") from examples/pillar-2-mcp-tools/requirements.txt.
> 2. Call cm_find on examples/pillar-2-mcp-tools/app_vulnerable.py.
> ```
**What to verify:**
- `scan_dependencies` queries Google's live `deps.dev` v3alpha API, flagging `reqeusts@2.31.0` as `HIGH_RISK_UNRESOLVED_OR_TYPOSQUAT` and `pyyaml@5.3.1` as `VULNERABLE` (`GHSA-8q59-q68h-6hv4`).
- `cm_find` runs `cm find examples/pillar-2-mcp-tools/app_vulnerable.py --model gemini-3.7-flash -y --compact` and identifies OS Command Injection (`CWE-78`).

### Test C: Trigger Pillar 4A (Agent `PreToolUse` Security Gate Hook)
> **Prompt to send in Chat:**
> ```text
> Run the CodeMender PreToolUse hook (examples/pillar-4-hooks-automation/post_edit_codemender_hook.sh) on examples/pillar-1-ide-guardrails/app.js vs examples/pillar-1-ide-guardrails/app.fixed.js and show me the exact JSON decision returned for each.
> ```
**What to verify:**
- On `app.js` (vulnerable SQL injection & XSS), the hook exits with code `2` and returns:
  `{"decision": "deny", "reason": "CodeMender CLI (cm find) blocked this edit because it introduces a security vulnerability..."}`
- On `app.fixed.js` (remediated parameterized queries), the hook exits with code `0` and returns:
  `{"decision": "allow", "reason": "CodeMender (cm find) verified 0 security vulnerabilities."}`

---

## 4. Testing the Git Hooks (`pre-commit` & `pre-push`)

The repository includes strict Git hooks in [`git-hooks/`](git-hooks/):
- **[`git-hooks/pre-commit`](git-hooks/pre-commit)**: Scans all staged source code files (`git diff --cached`) using `cm find --model gemini-3.7-flash -y --compact` and blocks `git commit` (`exit 1`) if a vulnerability is detected or if `cm` is unavailable.
- **[`git-hooks/pre-push`](git-hooks/pre-push)**: Checks `cm stats` before `git push`.

### Step 1: Install the Git Hooks
From the root of your Git repository:
```bash
git init -b main
bash ./scripts/install-git-hooks.sh
```

### Step 2: Verify `git commit` is BLOCKED on a Vulnerable File
Stage the intentionally vulnerable file (`examples/pillar-1-ide-guardrails/app.js`) and attempt to commit:
```bash
git add examples/pillar-1-ide-guardrails/app.js
git commit -m "Test committing vulnerable file"
```
**Expected Output (Commit Blocked):**
```text
🔍 [CodeMender Git pre-commit] Scanning staged files with CodeMender (gemini-3.7-flash)...
   → Auditing examples/pillar-1-ide-guardrails/app.js...
🚨 [CodeMender Git pre-commit] COMMIT BLOCKED: Vulnerability detected in 'examples/pillar-1-ide-guardrails/app.js'!
   Run 'cm verify <finding-id>' and 'cm fix <finding-id> -y' before committing.
```

### Step 3: Verify `git commit` SUCCEEDS on a Remediated File
Unstage the vulnerable file, stage the remediated file (`examples/pillar-1-ide-guardrails/app.fixed.js`), and commit:
```bash
git reset HEAD examples/pillar-1-ide-guardrails/app.js
git add examples/pillar-1-ide-guardrails/app.fixed.js
git commit -m "Add remediated app.fixed.js verified by CodeMender"
```
**Expected Output (Commit Allowed):**
```text
🔍 [CodeMender Git pre-commit] Scanning staged files with CodeMender (gemini-3.7-flash)...
   → Auditing examples/pillar-1-ide-guardrails/app.fixed.js...
✅ [CodeMender Git pre-commit] All staged files passed CodeMender security gate.
```

---

## 5. Testing Individual Pillars via the CLI (`scripts/test-pillar.sh`)

You can also test each pillar individually—or run the entire suite and export Markdown, JSON, and SARIF reports—using [`scripts/test-pillar.sh`](scripts/test-pillar.sh):

```bash
bash ./scripts/test-pillar.sh 1     # Pillar 1: Direct cm find + cm report + cm report --patches
bash ./scripts/test-pillar.sh 2     # Pillar 2: MCP Server stdio JSON-RPC tool calls
bash ./scripts/test-pillar.sh 3     # Pillar 3: 4-Step Skill artifacts + cm find + live PoC exploit
bash ./scripts/test-pillar.sh 4     # Pillar 4: Antigravity PreToolUse hook stdin gate
bash ./scripts/test-pillar.sh all   # Run all 4 pillars and export reports to ./artifacts/
```

> **Note on `cm report` flags**: Always invoke `cm report`, `cm report --patches`, and `cm report --artifacts` as separate commands (`cm report` returns early if `--artifacts` and `--patches` are combined in a single command).
