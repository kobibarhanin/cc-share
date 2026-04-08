#!/usr/bin/env bash
#
# fetch.sh — Browse and fetch shared session summaries
#
# Usage:
#   fetch.sh                        — List all teammates and their recent sessions
#   fetch.sh <username> <filename>  — Download a specific session
#
# Reads config from ~/.claude/cc_share_config.json

set -euo pipefail

CONFIG_FILE="$HOME/.claude/cc_share_config.json"
DOWNLOAD_DIR="/tmp/cc_share_fetched"
mkdir -p "$DOWNLOAD_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: Config not found at $CONFIG_FILE"
  echo "Run /share-session to configure."
  exit 1
fi

BACKEND=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['backend'])")

# --- Detect share link (single arg containing /) ---
if [ $# -eq 1 ] && [[ "$1" == */* ]]; then
  ENCODED_USER="${1%%/*}"
  FILENAME="${1#*/}"
  TARGET_USER="${ENCODED_USER//+/ }"
else
  TARGET_USER="${1:-}"
  FILENAME="${2:-}"
fi

case "$BACKEND" in
  s3)
    S3_BUCKET=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['s3_bucket'])")

    if [ -z "$TARGET_USER" ]; then
      # List all teammates and their 10 most recent sessions
      aws s3 ls "${S3_BUCKET%/}/" 2>/dev/null | grep 'PRE' | sed 's/.*PRE //' | tr -d '/' | while IFS= read -r user; do
        echo "## $user"
        aws s3 ls "${S3_BUCKET%/}/${user}/" 2>/dev/null | sort -k1,2 -r | head -10 | while IFS= read -r line; do
          fname=$(echo "$line" | awk '{print $NF}')
          [ -n "$fname" ] && echo "  $fname"
        done
        echo ""
      done
    else
      # Download a specific session
      if [ -z "$FILENAME" ]; then
        echo "ERROR: Provide a filename to fetch."
        echo "Usage: /fetch-sessions <username> <filename>"
        exit 1
      fi
      S3_PATH="${S3_BUCKET%/}/${TARGET_USER}/${FILENAME}"
      LOCAL_PATH="${DOWNLOAD_DIR}/${FILENAME}"
      aws s3 cp "$S3_PATH" "$LOCAL_PATH" --quiet
      echo "$LOCAL_PATH"
    fi
    ;;

  file)
    FILE_DIR=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('file_dir', '$HOME/cc_shares'))")

    if [ -z "$TARGET_USER" ]; then
      # List all teammates and their 10 most recent sessions
      for d in "$FILE_DIR"/*/; do
        [ -d "$d" ] || continue
        user=$(basename "$d")
        echo "## $user"
        ls -t "$d"*.md 2>/dev/null | head -10 | while IFS= read -r f; do
          echo "  $(basename "$f")"
        done
        echo ""
      done
    else
      if [ -z "$FILENAME" ]; then
        echo "ERROR: Provide a filename to fetch."
        exit 1
      fi
      SOURCE="${FILE_DIR%/}/${TARGET_USER}/${FILENAME}"
      if [ ! -f "$SOURCE" ]; then
        echo "ERROR: File not found: $SOURCE"
        exit 1
      fi
      LOCAL_PATH="${DOWNLOAD_DIR}/${FILENAME}"
      cp "$SOURCE" "$LOCAL_PATH"
      echo "$LOCAL_PATH"
    fi
    ;;

  *)
    echo "ERROR: Unknown backend '$BACKEND'"
    exit 1
    ;;
esac
