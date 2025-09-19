#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
FINAL_SCRIPT="${REPO_ROOT}/final_goose_egg.sh"
OUTPUT_SCRIPT="$(mktemp "${REPO_ROOT}/goose_egg.sh.XXXXXX")"

declare -i CLEANED=0
cleanup() {
  if [[ -f "${OUTPUT_SCRIPT}" ]]; then
    rm -f "${OUTPUT_SCRIPT}"
  fi
}
trap cleanup EXIT

if [[ ! -f "${FINAL_SCRIPT}" ]]; then
  echo "final_goose_egg.sh not found at ${FINAL_SCRIPT}" >&2
  exit 1
fi

python3 "${REPO_ROOT}/render.py" --output "${OUTPUT_SCRIPT}"

diff -u "${FINAL_SCRIPT}" "${OUTPUT_SCRIPT}" >/dev/null && \
  echo "Rendered goose_egg.sh matches final_goose_egg.sh"
