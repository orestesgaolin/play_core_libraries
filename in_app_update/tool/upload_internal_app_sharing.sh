#!/usr/bin/env bash
set -euo pipefail

# Uploads an already-built APK to Google Play Internal App Sharing.
# Requires: gcloud (authenticated with a service account that has Android Publisher role), curl, optionally jq.
# Default APK path assumes a Flutter release build at build/app/outputs/flutter-apk/app-release.apk.

PACKAGE_NAME="com.example.app"  # Replace with your app's package name
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
KEY_FILE="${GOOGLE_APPLICATION_CREDENTIALS:-}"  # Service account JSON; override with --key
SCOPES="https://www.googleapis.com/auth/androidpublisher"

usage() {
  cat <<'USAGE'
Usage: ./upload_internal_app_sharing.sh [--apk PATH] [--package NAME] [--key FILE]

Options:
  --apk PATH       Path to the APK to upload (default: build/app/outputs/flutter-apk/app-release.apk)
  --package NAME   Application ID / package name (default: com.exa)
  --key FILE       Path to service account JSON key (default: $GOOGLE_APPLICATION_CREDENTIALS)

Example:
  ./upload_internal_app_sharing.sh \
    --apk build/app/outputs/flutter-apk/app-release.apk \
    --key /path/to/service-account.json
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apk)
      APK_PATH="$2"; shift 2 ;;
    --package)
      PACKAGE_NAME="$2"; shift 2 ;;
    --key)
      KEY_FILE="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ -z "$KEY_FILE" ]]; then
  echo "Missing service account key file. Provide via --key or GOOGLE_APPLICATION_CREDENTIALS." >&2
  exit 1
fi

if [[ ! -f "$APK_PATH" ]]; then
  echo "APK not found at $APK_PATH" >&2
  exit 1
fi

for cmd in gcloud curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing dependency: $cmd" >&2
    exit 1
  fi
done

echo "Activating service account..."
gcloud auth activate-service-account --key-file "$KEY_FILE" --quiet >/dev/null
ACCESS_TOKEN=$(gcloud auth print-access-token --scopes "$SCOPES")

UPLOAD_URL="https://www.googleapis.com/upload/androidpublisher/v3/applications/internalappsharing/${PACKAGE_NAME}/artifacts/apk?uploadType=media"
TMP_RESPONSE=$(mktemp)
trap 'rm -f "$TMP_RESPONSE"' EXIT

echo "Uploading $APK_PATH to Internal App Sharing for $PACKAGE_NAME..."

HTTP_CODE=$(curl -sS -o "$TMP_RESPONSE" -w "%{http_code}" \
  -X POST \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @"${APK_PATH}" \
  "$UPLOAD_URL")

if [[ "$HTTP_CODE" -ge 400 ]]; then
  echo "Upload failed with HTTP $HTTP_CODE:" >&2
  cat "$TMP_RESPONSE" >&2
  exit 1
fi

if command -v jq >/dev/null 2>&1; then
  echo "Upload response (parsed):"
  if ! jq '{downloadUrl, certificateFingerprint}' "$TMP_RESPONSE"; then
    echo "Failed to parse JSON, raw response:" >&2
    cat "$TMP_RESPONSE"
  fi
else
  echo "Upload response (raw):"
  cat "$TMP_RESPONSE"
fi

