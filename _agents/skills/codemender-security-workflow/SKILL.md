---
name: codemender-security-workflow
description: Enforces the 4-step CodeMender security lifecycle in Antigravity (Threat Model -> Security Plan -> Live PoC Verification via cm -> Security Audit Report). Use when auditing, fixing, or writing security-sensitive code.
---

# CodeMender 4-Step Security Skill for Antigravity (AGY)

When this skill is triggered in Antigravity / Jetski, you MUST follow these 4 sequential steps and invoke the `cm` CLI (or CodeMender MCP tools) at each verification stage:

## Step 1: Threat Modeling (`1_THREAT_MODEL.md`)
Before writing or modifying code, identify all untrusted entry points, trust boundaries, and sensitive sinks (SQL, HTML, OS commands, file paths) and write `1_THREAT_MODEL.md`.

## Step 2: Security Implementation Plan (`2_SECURITY_PLAN.md`)
Create `2_SECURITY_PLAN.md` specifying the exact remediation pattern (e.g., parameterized queries, canonical path resolution) and the verification criteria.

## Step 3: Live Scan, PoC Verification & Fix via `cm`
Run CodeMender on the target file using the user's Google Cloud Project ID:
```bash
cm find <target_file> --model gemini-3.7-flash -y --compact
cm verify <finding_id> -y
cm fix <finding_id> -y
```

## Step 4: Security Audit Report (`4_SECURITY_AUDIT_REPORT.md`)
Generate `4_SECURITY_AUDIT_REPORT.md` summarizing the root cause, the verified PoC result, the applied diff, and any residual risks.
