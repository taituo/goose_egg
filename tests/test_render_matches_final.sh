#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
GOOSE_SCRIPT="${REPO_ROOT}/goose_egg.sh"
GOLDEN_SCRIPT="${REPO_ROOT}/golden_egg.sh"
OUTPUT_SCRIPT="$(mktemp "${REPO_ROOT}/goose_egg.sh.XXXXXX")"
EXTRACT_DIR="$(mktemp -d)"
GOLDEN_SHA="f38caf1fb629754f8f3c01e530dd95e7e761731c60cbf8177b2003e3f57677ec"

cleanup() {
  [[ -f "${OUTPUT_SCRIPT}" ]] && rm -f "${OUTPUT_SCRIPT}"
  [[ -d "${EXTRACT_DIR}" ]] && rm -rf "${EXTRACT_DIR}"
}
trap cleanup EXIT

if [[ ! -f "${GOOSE_SCRIPT}" ]]; then
  echo "goose_egg.sh not found at ${GOOSE_SCRIPT}" >&2
  exit 1
fi

if [[ ! -f "${GOLDEN_SCRIPT}" ]]; then
  echo "golden_egg.sh not found at ${GOLDEN_SCRIPT}" >&2
  exit 1
fi

python3 "${REPO_ROOT}/render.py" --output "${OUTPUT_SCRIPT}"

diff -u "${GOOSE_SCRIPT}" "${OUTPUT_SCRIPT}" >/dev/null && \
  echo "Rendered goose_egg.sh matches template output"

CALCULATED_SHA="$(sha256sum "${GOLDEN_SCRIPT}" | awk '{print $1}')"
if [[ "${CALCULATED_SHA}" != "${GOLDEN_SHA}" ]]; then
  echo "golden_egg.sh checksum drifted (expected ${GOLDEN_SHA}, got ${CALCULATED_SHA})" >&2
  exit 1
fi

"${OUTPUT_SCRIPT}" --verify-egg >/dev/null
"${OUTPUT_SCRIPT}" --extract-egg="${EXTRACT_DIR}" >/dev/null

if [[ ! -f "${EXTRACT_DIR}/egg/config/variables.json" ]]; then
  echo "Extraction did not recreate config/variables.json" >&2
  exit 1
fi

echo "Egg introspection commands succeeded"
