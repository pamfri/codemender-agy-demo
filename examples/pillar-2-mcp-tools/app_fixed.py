"""Pillar 2 Example: Remediated Network Diagnostic Utility (app_fixed.py)."""

import re
import subprocess
from urllib.parse import urlparse

_SAFE_HOSTNAME_RE = re.compile(r"^[a-zA-Z0-9.-]{1,253}$")
_ALLOWED_WEBHOOK_DOMAINS = frozenset({"api.example.com", "hooks.example.org"})


def ping_host_fixed(host: str) -> str:
  if not _SAFE_HOSTNAME_RE.match(host):
    raise ValueError(f"Invalid hostname rejected by security filter: {host!r}")
  completed = subprocess.run(
      ["echo", "Pinging", host],
      shell=False,
      capture_output=True,
      text=True,
      check=True,
  )
  return completed.stdout.strip()


def fetch_webhook_fixed(target_url: str) -> str:
  parsed = urlparse(target_url)
  if parsed.scheme != "https":
    raise ValueError("SSRF Protection: Only https:// URLs are permitted.")
  if parsed.hostname not in _ALLOWED_WEBHOOK_DOMAINS:
    raise ValueError(
        f"SSRF Protection: Hostname {parsed.hostname!r} is not in allowlist."
    )
  return f"Fetched safely from https://{parsed.hostname}{parsed.path}"
