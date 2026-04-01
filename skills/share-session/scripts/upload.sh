#!/usr/bin/env bash
#
# upload.sh — Upload a Claude Code session summary using saved config
#
# Usage: upload.sh <filename>
#
# Reads config from ~/.claude/cc_share_config.json
# Uploads /tmp/cc_share_summary.md to s3://<bucket>/<username>/<filename>

set -euo pipefail

CONFIG_FILE="$HOME/.claude/cc_share_config.json"
SUMMARY_FILE="/tmp/cc_share_summary.md"
FILENAME="${1:-}"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: Config not found at $CONFIG_FILE"
  echo "Run /share-session to configure."
  exit 1
fi

if [ ! -f "$SUMMARY_FILE" ]; then
  echo "ERROR: Summary file not found at $SUMMARY_FILE"
  exit 1
fi

if [ -z "$FILENAME" ]; then
  echo "ERROR: Filename argument required"
  exit 1
fi

# --- Read config ---

BACKEND=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['backend'])")
USERNAME=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['username'])")

# --- Upload ---

case "$BACKEND" in
  s3)
    S3_BUCKET=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['s3_bucket'])")

    if ! command -v aws &>/dev/null; then
      echo "ERROR: aws CLI not found. Install it with: brew install awscli"
      exit 1
    fi

    S3_PATH="${S3_BUCKET%/}/${USERNAME}/${FILENAME}"
    aws s3 cp "$SUMMARY_FILE" "$S3_PATH" --content-type "text/markdown" --quiet
    echo "SUCCESS: Uploaded to $S3_PATH"
    ;;

  file)
    FILE_DIR=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('file_dir', '$HOME/cc_shares'))")
    DEST_DIR="${FILE_DIR%/}/${USERNAME}"
    mkdir -p "$DEST_DIR"
    OUTPUT_PATH="$DEST_DIR/$FILENAME"
    cp "$SUMMARY_FILE" "$OUTPUT_PATH"
    echo "SUCCESS: Saved to $OUTPUT_PATH"
    ;;

  *)
    echo "ERROR: Unknown backend '$BACKEND' in config"
    exit 1
    ;;
esac

rm -f "$SUMMARY_FILE"
