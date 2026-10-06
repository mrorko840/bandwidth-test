#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# VPS Bandwidth Speed Test
#
# Usage:
#   ./speed-test.sh <Mbps> <Minutes>
#
# Examples:
#   ./speed-test.sh 50 10
#   ./speed-test.sh 100 30
#   ./speed-test.sh 500 5
# ============================================================

RATE_MBPS="${1:-50}"
DURATION_MINUTES="${2:-10}"

# Safety limits
MAX_RATE_MBPS=500
MAX_DURATION_MINUTES=60

TEST_URL="https://speed.cloudflare.com/__down?bytes=1000000000000"

# ------------------------------------------------------------
# Validation
# ------------------------------------------------------------

if ! [[ "$RATE_MBPS" =~ ^[0-9]+$ ]]; then
    echo "Error: Mbps must be a positive integer."
    exit 1
fi

if ! [[ "$DURATION_MINUTES" =~ ^[0-9]+$ ]]; then
    echo "Error: Duration must be a positive integer."
    exit 1
fi

if (( RATE_MBPS < 1 || RATE_MBPS > MAX_RATE_MBPS )); then
    echo "Error: Mbps must be between 1 and ${MAX_RATE_MBPS}."
    exit 1
fi

if (( DURATION_MINUTES < 1 || DURATION_MINUTES > MAX_DURATION_MINUTES )); then
    echo "Error: Duration must be between 1 and ${MAX_DURATION_MINUTES} minutes."
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "curl is not installed."
    echo "Install it with:"
    echo "sudo apt update && sudo apt install curl -y"
    exit 1
fi

if ! command -v timeout >/dev/null 2>&1; then
    echo "timeout command is not installed."
    echo "Install coreutils with:"
    echo "sudo apt update && sudo apt install coreutils -y"
    exit 1
fi

# ------------------------------------------------------------
# Conversion
#
# Mbps -> bytes/sec
#
# 100 Mbps
# = 100,000,000 bits/sec
# = 12,500,000 bytes/sec
# ------------------------------------------------------------

RATE_BYTES_PER_SECOND=$(( RATE_MBPS * 1000000 / 8 ))
DURATION_SECONDS=$(( DURATION_MINUTES * 60 ))

EXPECTED_BYTES=$(( RATE_BYTES_PER_SECOND * DURATION_SECONDS ))
EXPECTED_GB=$(awk "BEGIN { printf \"%.2f\", ${EXPECTED_BYTES}/1000000000 }")

echo ""
echo "=========================================="
echo "        VPS Bandwidth Test"
echo "=========================================="
echo "Speed        : ${RATE_MBPS} Mbps"
echo "Duration     : ${DURATION_MINUTES} minute(s)"
echo "Rate         : ${RATE_BYTES_PER_SECOND} bytes/sec"
echo "Expected data: ~${EXPECTED_GB} GB"
echo "Direction    : DOWNLOAD / INBOUND"
echo "=========================================="
echo ""
echo "Starting..."
echo "Press Ctrl+C to stop early."
echo ""

START_TIME=$(date +%s)

set +e

timeout \
    --signal=INT \
    --kill-after=5 \
    "${DURATION_SECONDS}s" \
    curl \
        --location \
        --silent \
        --show-error \
        --fail \
        --output /dev/null \
        --limit-rate "${RATE_BYTES_PER_SECOND}" \
        "$TEST_URL"

CURL_EXIT=$?

set -e

END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))

echo ""
echo "=========================================="
echo "Test finished"
echo "Elapsed: ${ELAPSED} seconds"
echo "=========================================="

# timeout normally returns 124 when the requested duration expires.
if [[ "$CURL_EXIT" -ne 0 && "$CURL_EXIT" -ne 124 && "$CURL_EXIT" -ne 130 ]]; then
    echo "curl exited with code: ${CURL_EXIT}"
    exit "$CURL_EXIT"
fi

exit 0