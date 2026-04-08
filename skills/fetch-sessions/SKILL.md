---
name: fetch-sessions
description: Browse and fetch shared session summaries from teammates
disable-model-invocation: true
allowed-tools: Bash, Read
---

# Fetch Shared Session

Browse your team's shared sessions and load one for context.

## Configuration

Config file: !`cat ~/.claude/cc_share_config.json 2>/dev/null || echo "NOT_CONFIGURED"`

If not configured, tell the user to run `/share-session` first (it handles setup) and stop.

## Flow

### Direct link mode

If `$ARGUMENTS` is non-empty, the user provided a direct share link (e.g., `/fetch-sessions Kobi+B./fix-redis-bug_20260408T120000Z.md`).

Run the fetch script with the link as a single argument:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/fetch.sh "$ARGUMENTS"
```

This downloads the session directly. Read the downloaded markdown file from the path the script outputs. Present the full summary to the user.

Then ask which aspect they'd like to continue working on, offering the **Next Steps** from the summary as options.

**Skip Step 1 and Step 2 below** — they are only for the browsing flow when no arguments are provided.

---

### Browse mode (no arguments)

### Step 1 — Show all sessions upfront

Run the fetch script with no arguments:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/fetch.sh
```

This returns all teammates and their 10 most recent sessions. Present the full list to the user exactly as returned — each teammate as a heading with their sessions listed below.

Then ask: **"Which session would you like to load?"**

### Step 2 — Load the selected session

Once the user picks a session, run:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/fetch.sh "<username>" "<filename>"
```

IMPORTANT: The username may contain spaces (e.g., "Kobi B."). Always quote it.

Read the downloaded markdown file from the path the script outputs. Present the full summary to the user.

Then ask which aspect they'd like to continue working on, offering the **Next Steps** from the summary as options.
