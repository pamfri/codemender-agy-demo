"""Pillar 2 Example: Vulnerable Network Diagnostic Utility (app_vulnerable.py).

Flagged by CodeMender MCP tool `cm_find`.
"""

import subprocess


def ping_host_vulnerable(host: str) -> str:
  """❌ VULNERABILITY 1 (CWE-78: OS Command Injection)."""
  cmd = f"echo Pinging {host}"
  completed = subprocess.run(
      cmd, shell=True, capture_output=True, text=True, check=False
  )
  return completed.stdout.strip()


def fetch_webhook_vulnerable(target_url: str) -> str:
  """❌ VULNERABILITY 2 (CWE-918: Server-Side Request Forgery / SSRF)."""
  if target_url.startswith("http://169.254.169.254"):
    return "SECRET_CLOUD_METADATA_TOKEN_LEAKED"
  return f"Fetched from {target_url}"
