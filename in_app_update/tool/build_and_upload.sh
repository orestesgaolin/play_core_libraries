#!/usr/bin/env bash
set -euo pipefail

COUNTER_FILE=./scripts/.next_build_number
mkdir -p "$(dirname "$COUNTER_FILE")"
current=$(cat "$COUNTER_FILE" 2>/dev/null || echo 77)  # starting point
next=$((current + 1))
echo "$next" > "$COUNTER_FILE"

build_number="$current"           # use current for this build
build_name="1.0.$current"

fvm flutter build apk --release --build-number "$build_number" --build-name "$build_name"
./tool/upload_internal_app_sharing.sh --key ./tool/service-account.json