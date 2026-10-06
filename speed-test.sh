#!/usr/bin/env bash

set -Eeuo pipefail

RATE_MBPS="${1:-100}"
DURATION_MINUTES="${2:-10}"

MAX_RATE_MBPS=1000
MAX_DURATION_MINUTES=120

# 50 MB per request
CHUNK_BYTES=50000000
TEST_URL="https://speed.cloudflare.com/__down?bytes=${CHUNK_BYTES}"

if ! [[ "$RATE_MBPS" =~ ^[0-9]+$ ]] || (( RATE_MBPS < 1 || RATE_MBPS > MAX_RATE_MBPS )); then
    echo "Error: Mbps must be between 1 and ${MAX_RATE_MBPS}."
    exit 1
fi

if ! [[ "$DURATION_MINUTES" =~ ^[0-9]+$ ]] || (( DURATION_MINUTES < 1 || DURATION_MINUTES > MAX_DURATION_MINUTES )); then
    echo "Error: Duration must be between 1 and ${MAX_DURATION_MINUTES} minutes."
    exit 1
fi

command -v curl >/dev/null 2>&1 || {
    echo "curl is not installed."
    exit 1
}

RATE_BYTES_PER_SECOND=$(( RATE_MBPS * 1000000 / 8 ))
DURATION_SECONDS=$(( DURATION_MINUTES * 60 ))

EXPECTED_BYTES=$(( RATE_BYTES_PER_SECOND * DURATION_SECONDS ))
EXPECTED_GB=$(awk "BEGIN { printf \"%.2f\", ${EXPECTED_BYTES}/1000000000 }")

START_TIME=$(date +%s)
END_TIME=$(( START_TIME + DURATION_SECONDS ))

echo
echo "=========================================="
echo "        VPS Bandwidth Test"
echo "=========================================="
echo "Speed        : ${RATE_MBPS} Mbps"
echo "Duration     : ${DURATION_MINUTES} minute(s)"
echo "Expected data: ~${EXPECTED_GB} GB"
echo "Chunk size   : 50 MB"
echo "Direction    : DOWNLOAD / INBOUND"
echo "=========================================="
echo
echo "Starting..."
echo "Press Ctrl+C to stop early."
echo

TOTAL_BYTES=0

cleanup() {
    echo
    echo "Stopping..."
    exit 0
}

trap cleanup INT TERM

while (( $(date +%s) < END_TIME )); do

    REMAINING=$(( END_TIME - $(date +%s) ))

    if (( REMAINING <= 0 )); then
        break
    fi

    set +e

    curl \
        --location \
        --silent \
        --show-error \
        --fail \
        --max-time "$REMAINING" \
        --limit-rate "$RATE_BYTES_PER_SECOND" \
        --output /dev/null \
        "$TEST_URL"

    CURL_EXIT=$?

    set -e

    if [[ "$CURL_EXIT" -eq 0 ]]; then
        TOTAL_BYTES=$(( TOTAL_BYTES + CHUNK_BYTES ))
    elif [[ "$CURL_EXIT" -eq 28 ]]; then
        break
    else
        echo "Download failed with curl exit code: $CURL_EXIT"
        sleep 2
    fi

done

ACTUAL_GB=$(awk "BEGIN { printf \"%.2f\", ${TOTAL_BYTES}/1000000000 }")

ELAPSED=$(( $(date +%s) - START_TIME ))

echo
echo "=========================================="
echo "Test finished"
echo "Elapsed         : ${ELAPSED} seconds"
echo "Downloaded ~    : ${ACTUAL_GB} GB"
echo "=========================================="