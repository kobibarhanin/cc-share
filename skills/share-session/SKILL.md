---
name: share-session
description: Generate a comprehensive summary of the current session and upload it to your team's shared location
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Grep, Glob
---

# Session Share

Generate a shareable summary of the current Claude Code session and upload it.

## Configuration

Config file: !`cat ~/.claude/cc_share_config.json 2>/dev/null || echo "NOT_CONFIGURED"`

## First-time setup

If the config output above says "NOT_CONFIGURED", you need to set up before proceeding:

1. Ask the user for their **S3 bucket path** (e.g., `s3://my-team-shares/cc-sessions`)
2. Ask for their **username** — propose their system username as default. Run `whoami` to get it.
3. Write the config to `~/.claude/cc_share_config.json`:

```json
{
  "backend": "s3",
  "s3_bucket": "<their bucket path>",
  "username": "<their username>"
}
```

4. Then continue with the summary generation below.

## Context

- Project directory: !`basename "$(pwd)"`
- Current branch: !`git --no-pager branch --show-current 2>/dev/null || echo "n/a"`
- Session ID: ${CLAUDE_SESSION_ID}

Note: Do NOT rely on these dynamic context values for the summary content. They are just hints. The summary should be generated from your conversation history — you were there for the whole session.

## Summary Generation

Generate a comprehensive markdown summary of everything accomplished in this conversation.

### Filename

The filename MUST be descriptive of the session's subject. Format:

`<short-descriptive-title>_<timestamp>.md`

Examples:
- `oauth2-google-sso-implementation_20260331T150000Z.md`
- `fix-redis-token-expiry-bug_20260331T120000Z.md`
- `research-team-sharing-plugin_20260331T170000Z.md`

Use lowercase, hyphens for spaces, keep it under 80 chars. The title should tell a teammate what the session was about without opening the file.

### Summary Structure

The summary has two parts: **required metadata** that's always present, and **conditional sections** that you include only when relevant to the session.

#### Required — always include:

```markdown
# <Title: what was accomplished>

**Author:** <username from config>
**Project:** <project name>
**Branch:** <git branch>
**Date:** <human-readable date and time>

## Overview

<2-3 sentence high-level description of what was done and why>

## What Was Done

<The core narrative of the session. Describe what happened, what was built/fixed/researched,
and the reasoning behind key choices. This is free-form — write it in whatever structure
best fits the session. For a coding session, walk through the implementation. For a research
session, present the findings. For debugging, tell the story of the investigation.>

## Next Steps

- [ ] <recommended follow-up action>
- [ ] <recommended follow-up action>
```

#### Conditional — include ONLY when relevant:

**Include "Key Code" when** the session produced important code that a teammate needs to understand — new APIs, complex algorithms, non-obvious patterns. Show the essential snippets with brief explanations, not entire files.

```markdown
## Key Code

<Brief context for why this code matters>

`path/to/file.py`
\```python
# The relevant snippet — not the whole file
def important_function():
    ...
\```

<Explain non-obvious aspects: why this approach, what the alternatives were>
```

**Include "Architecture / Design" when** the session involved system design, new patterns, data flow changes, or structural decisions. Use diagrams (ASCII or mermaid) when they clarify.

```markdown
## Architecture / Design

<Description of the design and rationale>

\```
┌──────────┐     ┌──────────┐     ┌──────────┐
│  Client   │────▶│  Auth MW  │────▶│  API     │
└──────────┘     └──────────┘     └──────────┘
                       │
                       ▼
                 ┌──────────┐
                 │  Redis    │
                 └──────────┘
\```
```

**Include "Failed Approaches" when** dead ends were hit that a teammate might repeat. Skip if everything worked on the first try.

```markdown
## Failed Approaches

- **<What was tried>:** <Why it didn't work. Be specific — save someone from repeating this.>
```

**Include "Open Questions" when** there are genuinely unresolved decisions or unknowns. Skip if everything is settled.

```markdown
## Open Questions

- <question and why it matters>
```

**Include "Files Changed" when** the session modified or created files. Skip for pure research/discussion sessions.

```markdown
## Files Changed

- `path/to/new_file.py` — <what and why>
- `path/to/modified_file.py` — <what changed>
```

**Include "Context for Continuation" when** there are non-obvious setup steps, gotchas, environment requirements, or dependencies a teammate needs to know. Skip if the next steps are self-explanatory.

```markdown
## Context for Continuation

<Environment setup, gotchas, credentials needed, related PRs, etc.>
```

### Guidelines

1. Be thorough — capture ALL work done in the session, not just the last task
2. Include reasoning behind decisions, not just outcomes
3. The "What Was Done" section is the heart — make it detailed and narrative
4. Code snippets should be the *essential* parts, not full file dumps. A teammate should understand the approach from the snippets alone
5. Do NOT include secrets, tokens, or credentials
6. Use your judgment on which conditional sections to include — a 10-minute bugfix doesn't need an architecture diagram. A system design session doesn't need a files-changed list

### Upload

1. Write the summary markdown to `/tmp/cc_share_summary.md`
2. Run the upload script:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/upload.sh "<descriptive-filename>.md"
```

Pass the descriptive filename as the first argument to the script.

3. Report the S3 path to the user so they can share it with teammates.
