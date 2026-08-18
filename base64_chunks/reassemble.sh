#!/bin/bash
set -euo pipefail

CHUNK_DIR="$(cd "$(dirname "$0")" && pwd)"
PREFIX="postgresql-42.2.22.zip.b64.part."
OUT_B64="${CHUNK_DIR}/../postgresql-42.2.22.zip.base64.joined.txt"
OUT_ZIP="${CHUNK_DIR}/../postgresql-42.2.22.joined.zip"
EXPECTED_MD5="2c6e88806e44c131630df2bb7faef9a3"
TOTAL_CHUNKS=0

echo "=== Reassembling multiline base64 chunks ==="
echo "Chunks dir: ${CHUNK_DIR}"

PARTS=("${CHUNK_DIR}/${PREFIX}"*)
if [ ${#PARTS[@]} -eq 0 ]; then
  echo "ERROR: No chunk files found with prefix ${PREFIX}"
  exit 1
fi
TOTAL_CHUNKS=${#PARTS[@]}
echo "Found ${TOTAL_CHUNKS} chunks (part.000 ~ part.$(printf '%03d' $(( TOTAL_CHUNKS - 1 )) ))"
echo "Preview: $(ls -lh "${PARTS[0]}" | awk '{print $5}') ~ $(ls -lh "${PARTS[$((TOTAL_CHUNKS-1))]}" | awk '{print $5}') / chunk"

echo ""
echo "1) Concatenating ${TOTAL_CHUNKS} chunks -> ${OUT_B64}"
: > "${OUT_B64}"
for i in $(seq -f "%03g" 0 $(( TOTAL_CHUNKS - 1 ))); do
  F="${CHUNK_DIR}/${PREFIX}${i}"
  if [ ! -f "$F" ]; then
    echo "ERROR: Missing chunk ${F}"
    exit 1
  fi
  cat "$F" >> "${OUT_B64}"
done
B64_LINES=$(wc -l < "${OUT_B64}" | tr -d ' ')
B64_BYTES=$(wc -c < "${OUT_B64}" | tr -d ' ')
echo "   Joined: ${B64_LINES} lines, ${B64_BYTES} bytes"

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
import base64
with open('${OUT_B64}', 'rb') as f:
    data = f.read()
with open('${OUT_ZIP}', 'wb') as f:
    f.write(base64.b64decode(data))
"
else
  echo "ERROR: Neither base64 nor python3 found. Cannot decode."
  exit 1
fi
ZIP_BYTES=$(wc -c < "${OUT_ZIP}" | tr -d ' ')
echo "   Zip size: ${ZIP_BYTES} bytes"

echo ""
echo "3) Verifying MD5 checksum..."
if command -v md5sum >/dev/null 2>&1; then
  ACTUAL_MD5="$(md5sum "${OUT_ZIP}" | awk '{print $1}')"
elif command -v md5 >/dev/null 2>&1; then
  ACTUAL_MD5="$(md5 -q "${OUT_ZIP}")"
elif command -v python3 >/dev/null 2>&1; then
  ACTUAL_MD5="$(python3 -c "import hashlib; print(hashlib.md5(open('${OUT_ZIP}','rb').read()).hexdigest())")"
else
  echo "ERROR: No md5sum / md5 / python3 tool for checksum."
  exit 1
fi
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
