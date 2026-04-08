#!/usr/bin/env bash
#
# delete.sh — Delete a shared session you own
#
# Usage: delete.sh <share-link>
#
# Decodes the share link, verifies the current user is the owner,
# and deletes the session from storage.

set -euo pipefail

CONFIG_FILE="$HOME/.claude/cc_share_config.json"
SHARE_LINK="${1:-}"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: Config not found at $CONFIG_FILE"
  echo "Run /share-session to configure."
  exit 1
fi

if [ -z "$SHARE_LINK" ]; then
  echo "ERROR: Share link argument required"
  echo "Usage: delete.sh <share-link>"
  exit 1
fi

# --- Decode share link ---
ENCODED_USER="${SHARE_LINK%%/*}"
FILENAME="${SHARE_LINK#*/}"
TARGET_USER="${ENCODED_USER//+/ }"

# --- Read config ---
BACKEND=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['backend'])")
CURRENT_USER=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['username'])")

# --- Ownership check ---
if [ "$CURRENT_USER" != "$TARGET_USER" ]; then
  echo "DENIED: This session belongs to '${TARGET_USER}'. Only the owner can delete it. You are '${CURRENT_USER}'."
  exit 1
fi

# --- Delete ---

case "$BACKEND" in
  s3)
    S3_BUCKET=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['s3_bucket'])")
    S3_PATH="${S3_BUCKET%/}/${TARGET_USER}/${FILENAME}"
    aws s3 rm "$S3_PATH" --quiet
    echo "SUCCESS: Deleted $S3_PATH"
    ;;

  file)
    FILE_DIR=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('file_dir', '$HOME/cc_shares'))")
    FILE_PATH="${FILE_DIR%/}/${TARGET_USER}/${FILENAME}"
    if [ ! -f "$FILE_PATH" ]; then
      echo "ERROR: File not found: $FILE_PATH"
      exit 1
    fi
    rm "$FILE_PATH"
    echo "SUCCESS: Deleted $FILE_PATH"
    ;;

  *)
    echo "ERROR: Unknown backend '$BACKEND'"
    exit 1
    ;;
esac
