# CodeMender + Antigravity Reference Repository (`v0.7.0`)

Welcome to the **CodeMender + Antigravity Reference Repository**. This repository provides a hands-on reference architecture for **CodeMender** across its **4 Core Antigravity Pillars**, ready-to-use **MCP Server, Agent Skill, Agent Lifecycle Hook, and Git Hook** configurations, a step-by-step **[`TUTORIAL.md`](TUTORIAL.md)**, and a **GitHub Actions CI/CD pipeline with Keyless Workload Identity Federation (WIF)**.

> **Strict Zero-Mock Policy**: Every tool, skill, agent hook, and Git hook in this repository executes strictly through the real **`cm` CLI** and **Google Cloud Vertex AI** (`GCP_PROJECT_ID`). There are **no** offline regex fallbacks—if `cm` is missing, unauthenticated, or detects a vulnerability, the workflow fails with a non-zero exit code.

---

## 1. Introduction to CodeMender

**CodeMender** is an autonomous AI code security agent developed by **Google DeepMind** on the **Gemini Enterprise Agent Platform**. Unlike traditional Static Application Security Testing (SAST) tools that rely on high-noise pattern matching, CodeMender operates on a **proof-driven execution model**:

1. **Find (`cm find`)**: Performs LLM-guided static and cross-file taint analysis via Google Cloud Vertex AI (`gemini-3.7-flash`).
2. **Verify (`cm verify`)**: Eliminates false positives by building your application inside an **isolated local process sandbox** and generating + executing a live **Proof-of-Concept (PoC) exploit script**.
3. **Fix (`cm fix`)**: Generates an idiomatic security patch, applies it inside the sandbox, runs your test suite to verify **zero regressions**, and **re-runs the PoC exploit** to prove the vulnerability is neutralized.
4. **Report (`cm report`)**: Exports findings, generated patches (`--patches`), captured artifacts (`--artifacts`), and machine-readable reports (`--format md|json|sarif|html`).

---

## 2. Repository Structure & The 4 Core Pillars

See **[`TUTORIAL.md`](TUTORIAL.md)** for interactive instructions on how to test each pillar **directly through the Coding Agent in Chat**, via **Git Hooks (`pre-commit` / `pre-push`)**, or via the **CLI**.

| Path | Core Pillar / Component | Description |
| :--- | :--- | :--- |
| [`examples/pillar-1-ide-guardrails/`](examples/pillar-1-ide-guardrails/) | **Pillar 1: Direct IDE / Developer Guardrails** | Node.js/Express SQL Injection (`CWE-89`) & Reflected XSS (`CWE-79`) example (`app.js` $\rightarrow$ `app.fixed.js`) with regression test suite (`test.js`). |
| [`examples/pillar-2-mcp-tools/`](examples/pillar-2-mcp-tools/) | **Pillar 2: Autonomous Agent Tooling (MCP Server)** | Python Command Injection (`CWE-78`) & SSRF (`CWE-918`) example (`app_vulnerable.py` $\rightarrow$ `app_fixed.py`) and `requirements.txt` audited via [`codemender_mcp_server.py`](antigravity-setup/codemender_mcp_server.py). |
| [`examples/pillar-3-agent-skills/`](examples/pillar-3-agent-skills/) | **Pillar 3: Security-First Agent Skills (`SKILL.md`)** | Path Traversal (`CWE-22`) example (`server.vulnerable.js` $\rightarrow$ `server.fixed.js`) and artifacts produced by the 4-Step Skill ([`_agents/skills/codemender-security-workflow/SKILL.md`](_agents/skills/codemender-security-workflow/SKILL.md)): `1_THREAT_MODEL.md`, `2_SECURITY_PLAN.md`, `3_poc_exploit.sh`, and `4_SECURITY_AUDIT_REPORT.md`. |
| [`examples/pillar-4-hooks-automation/`](examples/pillar-4-hooks-automation/) | **Pillar 4: Self-Healing `PreToolUse` Agent Hook** | Automated Antigravity hook ([`post_edit_codemender_hook.sh`](examples/pillar-4-hooks-automation/post_edit_codemender_hook.sh)) registered in [`_agents/hooks.json`](_agents/hooks.json) that intercepts `write_to_file` / `replace_file_content` and blocks vulnerable edits via `cm find`. |
| [`_agents/`](_agents/) | **Workspace Agent Customizations** | Project-level [`skills/codemender-security-workflow/SKILL.md`](_agents/skills/codemender-security-workflow/SKILL.md) and [`hooks.json`](_agents/hooks.json) auto-discovered by Antigravity when opening this repository. |
| [`antigravity-setup/`](antigravity-setup/) | **Global Antigravity Setup (`~/.gemini/config/`)** | Stdio MCP server ([`codemender_mcp_server.py`](antigravity-setup/codemender_mcp_server.py)), [`mcp_config.json`](antigravity-setup/mcp_config.json) template, and global installer ([`install_local_antigravity.sh`](antigravity-setup/install_local_antigravity.sh)). |
| [`git-hooks/`](git-hooks/) | **Git `pre-commit` & `pre-push` Security Gates** | Strict Git hooks ([`pre-commit`](git-hooks/pre-commit) and [`pre-push`](git-hooks/pre-push)) that scan staged files with `cm find` and block vulnerable commits. Installed via [`scripts/install-git-hooks.sh`](scripts/install-git-hooks.sh). |
| [`scripts/`](scripts/) | **CLI Verification & Setup Scripts** | [`check-prerequisites.sh`](scripts/check-prerequisites.sh) (verifies `cm` + GCP auth), [`install-git-hooks.sh`](scripts/install-git-hooks.sh) (installs `.git/hooks/`), and [`test-pillar.sh`](scripts/test-pillar.sh) (`1|2|3|4|all`). |
| [`.github/workflows/codemender-security.yml`](.github/workflows/codemender-security.yml) | **GitHub Actions + Keyless WIF CI/CD** | Production GitHub Actions workflow using **Workload Identity Federation (WIF)** to run `cm find`, `cm verify --all`, and upload SARIF results to GitHub Security. |

---

## 3. Quick Start

```bash
# 1. Configure your Google Cloud Project ID & authenticate Application Default Credentials (ADC):
export GCP_PROJECT_ID="<YOUR_GCP_PROJECT_ID>"
gcloud config set project "${GCP_PROJECT_ID}"
gcloud services enable aiplatform.googleapis.com cloudresourcemanager.googleapis.com --project="${GCP_PROJECT_ID}"
gcloud auth application-default login --project="${GCP_PROJECT_ID}"

# 2. Install the CodeMender MCP Server, Skill, and Agent Hook into ~/.gemini/config/:
bash ./antigravity-setup/install_local_antigravity.sh

# 3. Install the CodeMender Git Hooks (pre-commit & pre-push) into .git/hooks/:
bash ./scripts/install-git-hooks.sh

# 4. Run an interactive test of any pillar (1, 2, 3, 4, or all):
bash ./scripts/test-pillar.sh 1
bash ./scripts/test-pillar.sh all
```

For full walkthroughs of **testing via the Coding Agent in Chat** and **testing Git Hooks (`git commit` / `git push`)**, see **[`TUTORIAL.md`](TUTORIAL.md)**.
