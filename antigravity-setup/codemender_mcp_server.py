#!/usr/bin/env python3
"""CodeMender Stdio MCP Server for Antigravity (`codemender_mcp_server.py`)."""

import json
import os
import shutil
import subprocess
import sys
import urllib.request


def _check_cm() -> str:
  search_path = (
      f"{os.path.expanduser('~/.local/bin')}:/usr/local/bin:/opt/homebrew/bin:"
      + os.environ.get("PATH", "")
  )
  cm_path = shutil.which("cm", path=search_path)
  if not cm_path:
    raise RuntimeError(
        "CodeMender CLI ('cm') is not installed in PATH. Install it first."
    )
  return cm_path


def _run_cm(args: list[str]) -> str:
  cm_path = _check_cm()
  env = os.environ.copy()
  env["PATH"] = (
      f"{os.path.expanduser('~/.local/bin')}:/usr/local/bin:/opt/homebrew/bin:"
      + env.get("PATH", "")
  )
  if not env.get("GCP_PROJECT_ID") and env.get("GOOGLE_CLOUD_PROJECT"):
    env["GCP_PROJECT_ID"] = env["GOOGLE_CLOUD_PROJECT"]
  proc = subprocess.run(
      [cm_path] + args,
      capture_output=True,
      text=True,
      env=env,
      check=False,
  )
  output = (proc.stdout + "\n" + proc.stderr).strip()
  if proc.returncode != 0 and not output:
    raise RuntimeError(f"cm exited with code {proc.returncode}")
  return output


TOOLS = [
    {
        "name": "cm_find",
        "description": "Scan a file or directory for vulnerabilities via `cm find`.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "target_path": {"type": "string"},
                "context": {"type": "string"},
            },
            "required": ["target_path"],
        },
    },
    {
        "name": "cm_verify",
        "description": "Verify a finding with a live PoC exploit via `cm verify <finding_id>`.",
        "inputSchema": {
            "type": "object",
            "properties": {"finding_id": {"type": "string"}},
            "required": ["finding_id"],
        },
    },
    {
        "name": "cm_fix",
        "description": "Generate and validate a security patch via `cm fix <finding_id>`.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "finding_id": {"type": "string"},
                "context": {"type": "string"},
            },
            "required": ["finding_id"],
        },
    },
    {
        "name": "cm_report",
        "description": "Retrieve the CodeMender security report (`cm report`).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "format": {
                    "type": "string",
                    "enum": ["table", "patches", "artifacts", "md", "json", "sarif"],
                    "default": "md",
                }
            },
        },
    },
    {
        "name": "scan_dependencies",
        "description": "Audit open-source packages against Google `deps.dev` v3alpha API.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "system": {"type": "string", "enum": ["NPM", "PYPI", "GO", "MAVEN"]},
                "package_name": {"type": "string"},
                "version": {"type": "string"},
            },
            "required": ["system", "package_name", "version"],
        },
    },
]


def _handle_call_tool(name: str, arguments: dict) -> str:
  if name == "cm_find":
    cmd = ["find", arguments["target_path"], "--model", "gemini-3.7-flash", "-y", "--compact"]
    if arguments.get("context"):
      cmd.extend(["-c", arguments["context"]])
    return _run_cm(cmd)

  if name == "cm_verify":
    return _run_cm(["verify", arguments["finding_id"], "-y"])

  if name == "cm_fix":
    cmd = ["fix", arguments["finding_id"], "-y"]
    if arguments.get("context"):
      cmd.extend(["-c", arguments["context"]])
    return _run_cm(cmd)

  if name == "cm_report":
    fmt = arguments.get("format", "md")
    if fmt == "table":
      return _run_cm(["report"])
    if fmt == "patches":
      return _run_cm(["report", "--patches"])
    if fmt == "artifacts":
      return _run_cm(["report", "--artifacts"])
    return _run_cm(["report", "--format", fmt])

  if name == "scan_dependencies":
    sys_name = arguments["system"].lower()
    pkg = arguments["package_name"]
    ver = arguments["version"]
    url = f"https://api.deps.dev/v3alpha/systems/{sys_name}/packages/{pkg}/versions/{ver}"
    try:
      with urllib.request.urlopen(url, timeout=10) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        advisories = data.get("advisoryKeys", [])
        return json.dumps(
            {
                "package": f"{pkg}@{ver}",
                "status": "VULNERABLE" if advisories else "SAFE",
                "advisories": advisories,
                "source": "deps.dev v3alpha",
            },
            indent=2,
        )
    except Exception as exc:
      return json.dumps(
          {
              "package": f"{pkg}@{ver}",
              "status": "HIGH_RISK_UNRESOLVED_OR_TYPOSQUAT",
              "error": str(exc),
              "message": f"Package '{pkg}@{ver}' not found on deps.dev ({sys_name}). Check for typosquatting!",
          },
          indent=2,
      )

  raise ValueError(f"Unknown tool: {name}")


def main() -> None:
  for line in sys.stdin:
    line = line.strip()
    if not line:
      continue
    try:
      req = json.loads(line)
    except json.JSONDecodeError:
      continue

    req_id = req.get("id")
    method = req.get("method")

    if method == "initialize":
      resp = {
          "jsonrpc": "2.0",
          "id": req_id,
          "result": {
              "protocolVersion": "2024-11-05",
              "capabilities": {"tools": {}},
              "serverInfo": {"name": "codemender-mcp", "version": "0.7.0"},
          },
      }
      sys.stdout.write(json.dumps(resp) + "\n")
      sys.stdout.flush()
    elif method == "tools/list":
      resp = {"jsonrpc": "2.0", "id": req_id, "result": {"tools": TOOLS}}
      sys.stdout.write(json.dumps(resp) + "\n")
      sys.stdout.flush()
    elif method == "tools/call":
      params = req.get("params", {})
      try:
        output = _handle_call_tool(
            params.get("name", ""), params.get("arguments", {})
        )
        resp = {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {"content": [{"type": "text", "text": output}], "isError": False},
        }
      except Exception as exc:
        resp = {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {"content": [{"type": "text", "text": f"ERROR: {exc}"}], "isError": True},
        }
      sys.stdout.write(json.dumps(resp) + "\n")
      sys.stdout.flush()


if __name__ == "__main__":
  main()
