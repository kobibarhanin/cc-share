---
name: update-session
description: Add an update to an existing shared session — comments, follow-up findings, or continuation work
disable-model-invocation: true
allowed-tools: Bash, Read, Write
---

# Update Shared Session

Add an update to an existing shared session. The original content is preserved; your update is appended with clear attribution.

## Configuration

Config file: !`cat ~/.claude/cc_share_config.json 2>/dev/null || echo "NOT_CONFIGURED"`

If not configured, tell the user to run `/share-session` first (it handles setup) and stop.

## Requirements

`$ARGUMENTS` must contain a share link (e.g., `Kobi+B./grounding-strategy-investigation_20260408T120000Z.md`).

If `$ARGUMENTS` is empty, tell the user:
> Usage: `/update-session <share-link>`
>
> You can get a share link from `/share-session` or `/fetch-sessions`.

Then stop.

## Flow

### Step 1 — Fetch the existing session

Download the session using the share link:

```bash
bash !`echo "${CLAUDE_SKILL_DIR}/../fetch-sessions/scripts/fetch.sh"` "$ARGUMENTS"
```

Read the downloaded file from the path the script outputs. Present a brief summary of the session to the user (title, author, date, and a one-line overview — not the full content).

### Step 2 — Generate the update

Generate an update based on the current conversation. The update should capture what you and the user have been working on in this session that relates to the shared session.

The update is **free-form markdown** — it can be:
- Follow-up findings or investigation results
- Comments or feedback on the original session
- Continuation of the work described
- Status updates on the Next Steps
- Corrections or clarifications

Keep it focused and useful. Include code snippets only if they're essential.

### Step 3 — Write the updated file

Read the current username from config:

```bash
python3 -c "import json; print(json.load(open('$HOME/.claude/cc_share_config.json'))['username'])"
```

Write the complete updated file to `/tmp/cc_share_update.md`. The file must contain:

1. **The entire original content** — copied exactly as-is, byte-for-byte. Do NOT modify, reformat, or summarize any existing content.

2. **The new update appended at the end**, using this structure:

**If the file does NOT already have an `## Updates` section:**

```markdown
<entire original content here, unchanged>

---

## Updates

### Update by <your username> — <human-readable date>

<your update content>
```

**If the file ALREADY has an `## Updates` section** (from previous updates):

```markdown
<entire original content + existing updates, unchanged>

### Update by <your username> — <human-readable date>

<your update content>
```

In this case, just append the new `### Update by ...` subsection at the very end. Do NOT add another `## Updates` header or `---` separator.

### Step 4 — Upload the updated file

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/update.sh "$ARGUMENTS"
```

### Step 5 — Report to the user

Present:
- Confirmation that the session was updated
- The share link (from the `SHARE_LINK:` line in script output)
- Remind them the same link still works: `/fetch-sessions <link>`
