#!/usr/bin/env bash
#
# update.sh — Upload an updated session back to its original location
#
# Usage: update.sh <share-link>
#
# Reads the updated file from /tmp/cc_share_update.md
# Decodes the share link to get the original username/filename
# Uploads to the same path, overwriting the original

set -euo pipefail

CONFIG_FILE="$HOME/.claude/cc_share_config.json"
UPDATE_FILE="/tmp/cc_share_update.md"
SHARE_LINK="${1:-}"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: Config not found at $CONFIG_FILE"
  echo "Run /share-session to configure."
  exit 1
fi

if [ ! -f "$UPDATE_FILE" ]; then
  echo "ERROR: Update file not found at $UPDATE_FILE"
  exit 1
fi

if [ -z "$SHARE_LINK" ]; then
  echo "ERROR: Share link argument required"
  echo "Usage: update.sh <share-link>"
  exit 1
fi

# --- Decode share link ---
ENCODED_USER="${SHARE_LINK%%/*}"
FILENAME="${SHARE_LINK#*/}"
TARGET_USER="${ENCODED_USER//+/ }"

# --- Read config ---
BACKEND=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['backend'])")

# --- Upload to original location ---

case "$BACKEND" in
  s3)
    S3_BUCKET=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['s3_bucket'])")

    if ! command -v aws &>/dev/null; then
      echo "ERROR: aws CLI not found. Install it with: brew install awscli"
      exit 1
    fi

    S3_PATH="${S3_BUCKET%/}/${TARGET_USER}/${FILENAME}"
    aws s3 cp "$UPDATE_FILE" "$S3_PATH" --content-type "text/markdown" --quiet
    echo "SUCCESS: Updated $S3_PATH"
    echo "SHARE_LINK: $SHARE_LINK"
    ;;

  file)
    FILE_DIR=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('file_dir', '$HOME/cc_shares'))")
    OUTPUT_PATH="${FILE_DIR%/}/${TARGET_USER}/${FILENAME}"

    if [ ! -f "$OUTPUT_PATH" ]; then
      echo "ERROR: Original file not found: $OUTPUT_PATH"
      exit 1
    fi

    cp "$UPDATE_FILE" "$OUTPUT_PATH"
    echo "SUCCESS: Updated $OUTPUT_PATH"
    echo "SHARE_LINK: $SHARE_LINK"
    ;;

  *)
    echo "ERROR: Unknown backend '$BACKEND' in config"
    exit 1
    ;;
esac

rm -f "$UPDATE_FILE"
