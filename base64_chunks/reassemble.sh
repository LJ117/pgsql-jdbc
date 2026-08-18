#!/bin/bash
set -euo pipefail

CHUNK_DIR="$(cd "$(dirname "$0")" && pwd)"
PREFIX="postgresql-42.2.22.zip.b64.part."
OUT_B64="${CHUNK_DIR}/../postgresql-42.2.22.zip.base64.joined.txt"
OUT_ZIP="${CHUNK_DIR}/../postgresql-42.2.22.joined.zip"
EXPECTED_MD5="2c6e88806e44c131630df2bb7faef9a3"

echo "=== Reassembling base64 chunks ==="
echo "Chunks dir: ${CHUNK_DIR}"

PARTS=("${CHUNK_DIR}/${PREFIX}"*)
if [ ${#PARTS[@]} -eq 0 ]; then
  echo "ERROR: No chunk files found with prefix ${PREFIX}"
  exit 1
fi

echo "Found ${#PARTS[@]} chunks:"
for p in "${PARTS[@]}"; do
  echo "  $(basename "$p")  ($(wc -c < "$p") bytes)"
done

echo ""
echo "1) Concatenating chunks -> ${OUT_B64}"
: > "${OUT_B64}"
for i in $(seq -f "%03g" 0 $(( ${#PARTS[@]} - 1 ))); do
  F="${CHUNK_DIR}/${PREFIX}${i}"
  if [ ! -f "$F" ]; then
    echo "ERROR: Missing chunk ${F}"
    exit 1
  fi
  cat "$F" >> "${OUT_B64}"
done
echo "   Joined size: $(wc -c < "${OUT_B64}") bytes"

echo ""
echo "2) Decoding base64 -> ${OUT_ZIP}"
if command -v base64 >/dev/null 2>&1; then
  UNAME_S="$(uname -s)"
  if [ "${UNAME_S}" = "Darwin" ]; then
    base64 -D -i "${OUT_B64}" -o "${OUT_ZIP}"
  else
    base64 -d "${OUT_B64}" > "${OUT_ZIP}"
  fi
elif command -v python3 >/dev/null 2>&1; then
  python3 -c "
import base64, sys
with open('${OUT_B64}', 'rb') as f:
    data = f.read()
with open('${OUT_ZIP}', 'wb') as f:
    f.write(base64.b64decode(data))
"
else
  echo "ERROR: Neither base64 nor python3 found. Cannot decode."
  exit 1
fi
echo "   Zip size: $(wc -c < "${OUT_ZIP}") bytes"

echo ""
echo "3) Verifying MD5 checksum..."
ACTUAL_MD5="$(md5sum "${OUT_ZIP}" 2>/dev/null | awk '{print $1}' || md5 -q "${OUT_ZIP}" 2>/dev/null)"
echo "   Expected: ${EXPECTED_MD5}"
echo "   Actual:   ${ACTUAL_MD5}"
if [ "${ACTUAL_MD5}" = "${EXPECTED_MD5}" ]; then
  echo "   MD5 OK!"
  echo ""
  echo "SUCCESS: Output at ${OUT_ZIP}"
else
  echo "   MD5 MISMATCH!"
  exit 1
fi
