---
name: delete-session
description: Delete a shared session you own
disable-model-invocation: true
allowed-tools: Bash
---

# Delete Shared Session

Delete a shared session. Only the session owner can delete it.

## Configuration

Config file: !`cat ~/.claude/cc_share_config.json 2>/dev/null || echo "NOT_CONFIGURED"`

If not configured, tell the user to run `/share-session` first (it handles setup) and stop.

## Requirements

`$ARGUMENTS` must contain a share link (e.g., `Kobi+B./grounding-strategy-investigation_20260408T120000Z.md`).

If `$ARGUMENTS` is empty, tell the user:
> Usage: `/delete-session <share-link>`
>
> You can get a share link from `/share-session` or `/fetch-sessions`.

Then stop.

## Flow

### Step 1 — Confirm with the user

Before deleting, tell the user which session will be deleted (decode the filename from the link into a readable form) and ask for explicit confirmation. Do NOT proceed without a "yes".

### Step 2 — Delete

Run:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/delete.sh "$ARGUMENTS"
```

### Step 3 — Report result

- If the output starts with `SUCCESS:` — confirm deletion to the user.
- If the output starts with `DENIED:` — explain that only the session owner can delete it, and show who the owner is.
- If the output starts with `ERROR:` — report the error.
