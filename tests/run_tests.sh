#!/usr/bin/env bash
#
# run_tests.sh — Test suite for cc-share plugin
#
# Uses the file backend with a temp directory to run fully local.
# Overrides HOME so no real config is touched.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

UPLOAD_SH="$PROJECT_DIR/skills/share-session/scripts/upload.sh"
FETCH_SH="$PROJECT_DIR/skills/fetch-sessions/scripts/fetch.sh"
UPDATE_SH="$PROJECT_DIR/skills/update-session/scripts/update.sh"
DELETE_SH="$PROJECT_DIR/skills/delete-session/scripts/delete.sh"

# --- Test harness ---

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_NAMES=()

pass() {
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: $1"
}

fail() {
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_NAMES+=("$1")
  echo "  FAIL: $1"
  if [ -n "${2:-}" ]; then
    echo "        $2"
  fi
}

assert_eq() {
  local test_name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    pass "$test_name"
  else
    fail "$test_name" "expected='$expected' actual='$actual'"
  fi
}

assert_contains() {
  local test_name="$1" haystack="$2" needle="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    pass "$test_name"
  else
    fail "$test_name" "output does not contain '$needle'"
  fi
}

assert_not_contains() {
  local test_name="$1" haystack="$2" needle="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    fail "$test_name" "output should not contain '$needle'"
  else
    pass "$test_name"
  fi
}

assert_file_exists() {
  local test_name="$1" file_path="$2"
  if [ -f "$file_path" ]; then
    pass "$test_name"
  else
    fail "$test_name" "file does not exist: $file_path"
  fi
}

assert_file_not_exists() {
  local test_name="$1" file_path="$2"
  if [ ! -f "$file_path" ]; then
    pass "$test_name"
  else
    fail "$test_name" "file should not exist: $file_path"
  fi
}

assert_exit_code() {
  local test_name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    pass "$test_name"
  else
    fail "$test_name" "expected exit code $expected, got $actual"
  fi
}

# --- Setup / teardown ---

TEST_HOME=""
FILE_DIR=""

setup() {
  TEST_HOME=$(mktemp -d)
  FILE_DIR=$(mktemp -d)
  export HOME="$TEST_HOME"

  mkdir -p "$TEST_HOME/.claude"
  cat > "$TEST_HOME/.claude/cc_share_config.json" << EOF
{
  "backend": "file",
  "file_dir": "$FILE_DIR",
  "username": "Test User"
}
EOF

  # Clean any leftover temp files from previous runs
  rm -f /tmp/cc_share_summary.md /tmp/cc_share_update.md
  rm -rf /tmp/cc_share_fetched
}

teardown() {
  rm -rf "$TEST_HOME" "$FILE_DIR"
  rm -f /tmp/cc_share_summary.md /tmp/cc_share_update.md
  rm -rf /tmp/cc_share_fetched
}

# Helper: create a summary file ready for upload
create_summary() {
  local content="${1:-Test session content}"
  echo "$content" > /tmp/cc_share_summary.md
}

# Helper: create an update file ready for upload
create_update() {
  local content="$1"
  echo "$content" > /tmp/cc_share_update.md
}

# ============================================================================
# UPLOAD TESTS
# ============================================================================

test_upload_basic() {
  echo ""
  echo "=== Upload: basic upload ==="
  setup

  create_summary "# My Session"
  local output
  output=$(bash "$UPLOAD_SH" "test-session_20260408T120000Z.md")

  assert_contains "outputs SUCCESS" "$output" "SUCCESS:"
  assert_contains "outputs SHARE_LINK" "$output" "SHARE_LINK:"
  assert_file_exists "file created in storage" "$FILE_DIR/Test User/test-session_20260408T120000Z.md"

  local stored_content
  stored_content=$(cat "$FILE_DIR/Test User/test-session_20260408T120000Z.md")
  assert_eq "stored content matches" "# My Session" "$stored_content"

  # Summary file should be cleaned up
  assert_file_not_exists "summary file cleaned up" "/tmp/cc_share_summary.md"

  teardown
}

test_upload_share_link_format() {
  echo ""
  echo "=== Upload: share link format ==="
  setup

  create_summary "content"
  local output
  output=$(bash "$UPLOAD_SH" "my-session_20260408T120000Z.md")

  local link
  link=$(echo "$output" | grep "SHARE_LINK:" | sed 's/SHARE_LINK: //')
  assert_eq "link encodes spaces as +" "Test+User/my-session_20260408T120000Z.md" "$link"

  teardown
}

test_upload_no_config() {
  echo ""
  echo "=== Upload: missing config ==="
  setup
  rm "$TEST_HOME/.claude/cc_share_config.json"

  create_summary "content"
  local output exit_code=0
  output=$(bash "$UPLOAD_SH" "test.md" 2>&1) || exit_code=$?

  assert_exit_code "exits with error" "1" "$exit_code"
  assert_contains "reports config missing" "$output" "ERROR:"

  teardown
}

test_upload_no_summary_file() {
  echo ""
  echo "=== Upload: missing summary file ==="
  setup
  # Don't create summary file

  local output exit_code=0
  output=$(bash "$UPLOAD_SH" "test.md" 2>&1) || exit_code=$?

  assert_exit_code "exits with error" "1" "$exit_code"
  assert_contains "reports file missing" "$output" "ERROR:"

  teardown
}

test_upload_no_filename() {
  echo ""
  echo "=== Upload: missing filename arg ==="
  setup
  create_summary "content"

  local output exit_code=0
  output=$(bash "$UPLOAD_SH" 2>&1) || exit_code=$?

  assert_exit_code "exits with error" "1" "$exit_code"
  assert_contains "reports filename required" "$output" "ERROR:"

  teardown
}

test_upload_username_no_spaces() {
  echo ""
  echo "=== Upload: username without spaces ==="
  setup
  # Override config with no-space username
  cat > "$TEST_HOME/.claude/cc_share_config.json" << EOF
{
  "backend": "file",
  "file_dir": "$FILE_DIR",
  "username": "alice"
}
EOF

  create_summary "content"
  local output
  output=$(bash "$UPLOAD_SH" "test_20260408T120000Z.md")

  local link
  link=$(echo "$output" | grep "SHARE_LINK:" | sed 's/SHARE_LINK: //')
  assert_eq "link has no encoding needed" "alice/test_20260408T120000Z.md" "$link"
  assert_file_exists "file in correct dir" "$FILE_DIR/alice/test_20260408T120000Z.md"

  teardown
}

# ============================================================================
# FETCH TESTS
# ============================================================================

test_fetch_list_sessions() {
  echo ""
  echo "=== Fetch: list all sessions ==="
  setup

  # Seed two users with sessions
  mkdir -p "$FILE_DIR/Alice" "$FILE_DIR/Bob"
  echo "s1" > "$FILE_DIR/Alice/session-one_20260401T120000Z.md"
  echo "s2" > "$FILE_DIR/Alice/session-two_20260402T120000Z.md"
  echo "s3" > "$FILE_DIR/Bob/session-three_20260403T120000Z.md"

  local output
  output=$(bash "$FETCH_SH")

  assert_contains "lists Alice" "$output" "## Alice"
  assert_contains "lists Bob" "$output" "## Bob"
  assert_contains "lists Alice session 1" "$output" "session-one_20260401T120000Z.md"
  assert_contains "lists Alice session 2" "$output" "session-two_20260402T120000Z.md"
  assert_contains "lists Bob session" "$output" "session-three_20260403T120000Z.md"

  teardown
}

test_fetch_by_username_and_filename() {
  echo ""
  echo "=== Fetch: download by username + filename ==="
  setup

  mkdir -p "$FILE_DIR/Test User"
  echo "# Hello World" > "$FILE_DIR/Test User/my-session_20260408T120000Z.md"

  local output
  output=$(bash "$FETCH_SH" "Test User" "my-session_20260408T120000Z.md")

  assert_file_exists "downloaded file" "$output"
  local content
  content=$(cat "$output")
  assert_eq "content matches" "# Hello World" "$content"

  teardown
}

test_fetch_by_share_link() {
  echo ""
  echo "=== Fetch: download by share link ==="
  setup

  mkdir -p "$FILE_DIR/Test User"
  echo "# Linked Session" > "$FILE_DIR/Test User/my-session_20260408T120000Z.md"

  local output
  output=$(bash "$FETCH_SH" "Test+User/my-session_20260408T120000Z.md")

  assert_file_exists "downloaded file" "$output"
  local content
  content=$(cat "$output")
  assert_eq "content matches" "# Linked Session" "$content"

  teardown
}

test_fetch_link_no_spaces_in_username() {
  echo ""
  echo "=== Fetch: share link without spaces ==="
  setup

  mkdir -p "$FILE_DIR/alice"
  echo "alice content" > "$FILE_DIR/alice/test_20260408T120000Z.md"

  local output
  output=$(bash "$FETCH_SH" "alice/test_20260408T120000Z.md")

  assert_file_exists "downloaded file" "$output"
  local content
  content=$(cat "$output")
  assert_eq "content matches" "alice content" "$content"

  teardown
}

test_fetch_missing_filename_arg() {
  echo ""
  echo "=== Fetch: username without filename ==="
  setup

  local output exit_code=0
  output=$(bash "$FETCH_SH" "SomeUser" 2>&1) || exit_code=$?

  assert_exit_code "exits with error" "1" "$exit_code"
  assert_contains "reports filename needed" "$output" "ERROR:"

  teardown
}

test_fetch_nonexistent_file() {
  echo ""
  echo "=== Fetch: file does not exist ==="
  setup

  mkdir -p "$FILE_DIR/Test User"

  local output exit_code=0
  output=$(bash "$FETCH_SH" "Test User" "nonexistent.md" 2>&1) || exit_code=$?

  assert_exit_code "exits with error" "1" "$exit_code"
  assert_contains "reports not found" "$output" "ERROR:"

  teardown
}

# ============================================================================
# UPDATE TESTS
# ============================================================================

test_update_basic() {
  echo ""
  echo "=== Update: basic update ==="
  setup

  # Create original session
  mkdir -p "$FILE_DIR/Test User"
  echo "# Original Content" > "$FILE_DIR/Test User/my-session_20260408T120000Z.md"

  create_update "# Original Content

---

## Updates

### Update by Alice — April 9, 2026

Follow-up findings here."

  local output
  output=$(bash "$UPDATE_SH" "Test+User/my-session_20260408T120000Z.md")

  assert_contains "outputs SUCCESS" "$output" "SUCCESS:"
  assert_contains "outputs SHARE_LINK" "$output" "SHARE_LINK:"

  local stored
  stored=$(cat "$FILE_DIR/Test User/my-session_20260408T120000Z.md")
  assert_contains "preserves original" "$stored" "# Original Content"
  assert_contains "has update section" "$stored" "## Updates"
  assert_contains "has attribution" "$stored" "Update by Alice"

  # Update file should be cleaned up
  assert_file_not_exists "update file cleaned up" "/tmp/cc_share_update.md"

  teardown
}

test_update_preserves_share_link() {
  echo ""
  echo "=== Update: returns same share link ==="
  setup

  mkdir -p "$FILE_DIR/Test User"
  echo "original" > "$FILE_DIR/Test User/sess_20260408T120000Z.md"

  create_update "updated content"

  local output
  output=$(bash "$UPDATE_SH" "Test+User/sess_20260408T120000Z.md")

  local link
  link=$(echo "$output" | grep "SHARE_LINK:" | sed 's/SHARE_LINK: //')
  assert_eq "link unchanged" "Test+User/sess_20260408T120000Z.md" "$link"

  teardown
}

test_update_no_update_file() {
  echo ""
  echo "=== Update: missing update file ==="
  setup

  local output exit_code=0
  output=$(bash "$UPDATE_SH" "Test+User/test.md" 2>&1) || exit_code=$?

  assert_exit_code "exits with error" "1" "$exit_code"
  assert_contains "reports file missing" "$output" "ERROR:"

  teardown
}

test_update_no_share_link() {
  echo ""
  echo "=== Update: missing share link arg ==="
  setup
  create_update "content"

  local output exit_code=0
  output=$(bash "$UPDATE_SH" 2>&1) || exit_code=$?

  assert_exit_code "exits with error" "1" "$exit_code"
  assert_contains "reports link required" "$output" "ERROR:"

  teardown
}

test_update_nonexistent_original() {
  echo ""
  echo "=== Update: original file does not exist ==="
  setup
  mkdir -p "$FILE_DIR/Test User"
  create_update "new content"

  local output exit_code=0
  output=$(bash "$UPDATE_SH" "Test+User/nonexistent.md" 2>&1) || exit_code=$?

  assert_exit_code "exits with error" "1" "$exit_code"
  assert_contains "reports not found" "$output" "ERROR:"

  teardown
}

# ============================================================================
# DELETE TESTS
# ============================================================================

test_delete_own_session() {
  echo ""
  echo "=== Delete: owner can delete ==="
  setup

  mkdir -p "$FILE_DIR/Test User"
  echo "to be deleted" > "$FILE_DIR/Test User/my-session_20260408T120000Z.md"

  local output
  output=$(bash "$DELETE_SH" "Test+User/my-session_20260408T120000Z.md")

  assert_contains "outputs SUCCESS" "$output" "SUCCESS:"
  assert_file_not_exists "file deleted" "$FILE_DIR/Test User/my-session_20260408T120000Z.md"

  teardown
}

test_delete_other_user_denied() {
  echo ""
  echo "=== Delete: non-owner is denied ==="
  setup

  mkdir -p "$FILE_DIR/Other Person"
  echo "not yours" > "$FILE_DIR/Other Person/their-session_20260408T120000Z.md"

  local output exit_code=0
  output=$(bash "$DELETE_SH" "Other+Person/their-session_20260408T120000Z.md" 2>&1) || exit_code=$?

  assert_exit_code "exits with error" "1" "$exit_code"
  assert_contains "outputs DENIED" "$output" "DENIED:"
  assert_contains "shows owner name" "$output" "Other Person"
  assert_contains "shows current user" "$output" "Test User"
  assert_file_exists "file not deleted" "$FILE_DIR/Other Person/their-session_20260408T120000Z.md"

  teardown
}

test_delete_nonexistent_file() {
  echo ""
  echo "=== Delete: file does not exist ==="
  setup
  mkdir -p "$FILE_DIR/Test User"

  local output exit_code=0
  output=$(bash "$DELETE_SH" "Test+User/nonexistent.md" 2>&1) || exit_code=$?

  assert_exit_code "exits with error" "1" "$exit_code"
  assert_contains "reports not found" "$output" "ERROR:"

  teardown
}

test_delete_no_share_link() {
  echo ""
  echo "=== Delete: missing share link arg ==="
  setup

  local output exit_code=0
  output=$(bash "$DELETE_SH" 2>&1) || exit_code=$?

  assert_exit_code "exits with error" "1" "$exit_code"
  assert_contains "reports link required" "$output" "ERROR:"

  teardown
}

# ============================================================================
# END-TO-END TESTS
# ============================================================================

test_e2e_upload_fetch_update_delete() {
  echo ""
  echo "=== E2E: full lifecycle ==="
  setup

  # 1. Upload
  create_summary "# E2E Session

Original content here."
  local upload_output
  upload_output=$(bash "$UPLOAD_SH" "e2e-test_20260408T120000Z.md")
  assert_contains "e2e: upload succeeds" "$upload_output" "SUCCESS:"

  local link
  link=$(echo "$upload_output" | grep "SHARE_LINK:" | sed 's/SHARE_LINK: //')

  # 2. Fetch via share link
  local fetch_path
  fetch_path=$(bash "$FETCH_SH" "$link")
  local fetched_content
  fetched_content=$(cat "$fetch_path")
  assert_contains "e2e: fetch returns original" "$fetched_content" "Original content here."

  # 3. Update
  create_update "# E2E Session

Original content here.

---

## Updates

### Update by Test User — April 9, 2026

Added follow-up notes."

  local update_output
  update_output=$(bash "$UPDATE_SH" "$link")
  assert_contains "e2e: update succeeds" "$update_output" "SUCCESS:"

  # 4. Fetch again — should have update
  fetch_path=$(bash "$FETCH_SH" "$link")
  fetched_content=$(cat "$fetch_path")
  assert_contains "e2e: original preserved after update" "$fetched_content" "Original content here."
  assert_contains "e2e: update visible" "$fetched_content" "Added follow-up notes."

  # 5. Delete
  local delete_output
  delete_output=$(bash "$DELETE_SH" "$link")
  assert_contains "e2e: delete succeeds" "$delete_output" "SUCCESS:"
  assert_file_not_exists "e2e: file gone after delete" "$FILE_DIR/Test User/e2e-test_20260408T120000Z.md"

  teardown
}

test_e2e_multi_user() {
  echo ""
  echo "=== E2E: multi-user collaboration ==="
  setup

  # User A uploads
  create_summary "# Shared Session

By User A."
  bash "$UPLOAD_SH" "collab_20260408T120000Z.md" > /dev/null

  # User B fetches via link
  local fetch_path
  fetch_path=$(bash "$FETCH_SH" "Test+User/collab_20260408T120000Z.md")
  local content
  content=$(cat "$fetch_path")
  assert_contains "multi-user: B sees A's content" "$content" "By User A."

  # User B updates (update.sh doesn't check ownership)
  create_update "# Shared Session

By User A.

---

## Updates

### Update by User B — April 9, 2026

B's contribution."

  local update_output
  update_output=$(bash "$UPDATE_SH" "Test+User/collab_20260408T120000Z.md")
  assert_contains "multi-user: update succeeds" "$update_output" "SUCCESS:"

  # User B tries to delete — denied (different user in link)
  # Reconfigure as User B
  cat > "$TEST_HOME/.claude/cc_share_config.json" << EOF
{
  "backend": "file",
  "file_dir": "$FILE_DIR",
  "username": "User B"
}
EOF

  local delete_output exit_code=0
  delete_output=$(bash "$DELETE_SH" "Test+User/collab_20260408T120000Z.md" 2>&1) || exit_code=$?
  assert_exit_code "multi-user: B cannot delete A's session" "1" "$exit_code"
  assert_contains "multi-user: delete denied" "$delete_output" "DENIED:"

  teardown
}

# ============================================================================
# RUN ALL TESTS
# ============================================================================

echo "cc-share test suite"
echo "==================="

# Upload
test_upload_basic
test_upload_share_link_format
test_upload_no_config
test_upload_no_summary_file
test_upload_no_filename
test_upload_username_no_spaces

# Fetch
test_fetch_list_sessions
test_fetch_by_username_and_filename
test_fetch_by_share_link
test_fetch_link_no_spaces_in_username
test_fetch_missing_filename_arg
test_fetch_nonexistent_file

# Update
test_update_basic
test_update_preserves_share_link
test_update_no_update_file
test_update_no_share_link
test_update_nonexistent_original

# Delete
test_delete_own_session
test_delete_other_user_denied
test_delete_nonexistent_file
test_delete_no_share_link

# E2E
test_e2e_upload_fetch_update_delete
test_e2e_multi_user

# --- Summary ---
echo ""
echo "==================="
echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed (out of $TESTS_RUN)"

if [ ${#FAILED_NAMES[@]} -gt 0 ]; then
  echo ""
  echo "Failed tests:"
  for name in "${FAILED_NAMES[@]}"; do
    echo "  - $name"
  done
fi

echo "==================="

if [ "$TESTS_FAILED" -gt 0 ]; then
  exit 1
fi
