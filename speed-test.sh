#!/usr/bin/env bash
set -Eeuo pipefail

RATE_MBPS="${1:-100}"
DURATION_MINUTES="${2:-10}"

RATE_BPS=$(( RATE_MBPS * 1000000 / 8 ))
DURATION_SECONDS=$(( DURATION_MINUTES * 60 ))
END_TIME=$(( $(date +%s) + DURATION_SECONDS ))

# Smaller chunks + fallback sources
URLS=(
  "https://speed.cloudflare.com/__down?bytes=10000000"
  "https://speedtest.tele2.net/10MB.zip"
  "https://ash-speed.hetzner.com/10MB.bin"
)

echo "=========================================="
echo "VPS Bandwidth Test"
echo "=========================================="
echo "Speed    : ${RATE_MBPS} Mbps"
echo "Duration : ${DURATION_MINUTES} minute(s)"
echo "Direction: DOWNLOAD / INBOUND"
echo "=========================================="

trap 'echo; echo "Stopped."; exit 0' INT TERM

CURRENT=0
FAILS=0

while (( $(date +%s) < END_TIME )); do
    URL="${URLS[$CURRENT]}"

    echo "Using: $URL"

    set +e
    HTTP_CODE=$(curl \
        -L \
        --silent \
        --show-error \
        --output /dev/null \
        --limit-rate "$RATE_BPS" \
        --max-time 60 \
        --write-out "%{http_code}" \
        "$URL"
    )
    CURL_CODE=$?
    set -e

    if [[ "$CURL_CODE" -eq 0 && "$HTTP_CODE" =~ ^2 ]]; then
        FAILS=0
    else
        echo "Failed: curl=$CURL_CODE http=$HTTP_CODE"

        FAILS=$((FAILS + 1))
        CURRENT=$(( (CURRENT + 1) % ${#URLS[@]} ))

        echo "Switching source..."
        sleep 5
    fi

    sleep 1
done

echo
echo "=========================================="
echo "Bandwidth test finished."
echo "=========================================="