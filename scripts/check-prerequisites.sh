#!/usr/bin/env bash
# ==============================================================================
# Strict Pre-Flight Verification for Google Cloud & CodeMender CLI (`cm`)
# ==============================================================================
set -euo pipefail
export PATH="${HOME}/.local/bin:/usr/local/bin:/opt/homebrew/bin:${PATH}"

if ! command -v cm >/dev/null 2>&1; then
  echo "❌ ERROR: CodeMender CLI ('cm') is not installed or not found in PATH." >&2
  exit 1
fi

if ! command -v gcloud >/dev/null 2>&1; then
  echo "❌ ERROR: Google Cloud SDK ('gcloud') is not installed or not found in PATH." >&2
  exit 1
fi

RESOLVED_PROJECT_ID="${GCP_PROJECT_ID:-${GOOGLE_CLOUD_PROJECT:-}}"
if [[ -z "${RESOLVED_PROJECT_ID}" ]]; then
  RESOLVED_PROJECT_ID="$(gcloud config get-value project 2>/dev/null || true)"
fi

if [[ -z "${RESOLVED_PROJECT_ID}" || "${RESOLVED_PROJECT_ID}" == "(unset)" ]]; then
  echo "❌ ERROR: No Google Cloud Project ID configured. Set export GCP_PROJECT_ID=\"your-project-id\"" >&2
  exit 1
fi

export GCP_PROJECT_ID="${RESOLVED_PROJECT_ID}"
export GOOGLE_CLOUD_PROJECT="${RESOLVED_PROJECT_ID}"
export GCLOUD_PROJECT="${RESOLVED_PROJECT_ID}"

if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
  echo "❌ ERROR: Google Cloud ADC not active. Run: gcloud auth application-default login --project=\"${GCP_PROJECT_ID}\"" >&2
  exit 1
fi

echo "✔ Pre-flight check passed: cm=$(command -v cm) | GCP_PROJECT_ID=${GCP_PROJECT_ID}"
