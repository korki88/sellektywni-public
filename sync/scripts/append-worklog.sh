#!/usr/bin/env bash
set -euo pipefail
MSG="${1:-}"
if [[ -z "$MSG" ]]; then
  echo "Usage: $0 \"Message\"" >&2
  exit 1
fi
LOG="$(cd "$(dirname "$0")/.." && pwd)/WORKLOG.md"
UTC="$(date -u +"%Y-%m-%d %H:%M:%S")"
{
  echo ""
  echo "## ${UTC} UTC (auto)"
  echo ""
  echo "- ${MSG}"
  echo ""
} >> "$LOG"
echo "[sync/log] Appended to WORKLOG.md"
