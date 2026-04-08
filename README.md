# cc-share

[![Tests](https://github.com/kobibarhanin/cc-share/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/kobibarhanin/cc-share/actions/workflows/test.yml)

Share Claude Code sessions with your team.

When you finish a task in Claude Code, run `/share-session` to generate a rich markdown summary of what you did — decisions made, code written, dead ends hit — and upload it to a shared S3 bucket. Your teammates run `/fetch-sessions` to browse and load those summaries as context for their own sessions. Share direct links, update sessions collaboratively, and clean up with `/delete-session`.

## Prerequisites

- [Claude Code](https://claude.ai/code) installed
- [AWS CLI](https://aws.amazon.com/cli/) installed and configured
- An S3 bucket accessible to all team members

## Installation

```
/plugin marketplace add kobibarhanin/cc-share
/plugin install cc-share@kobibarhanin-cc-share
/reload-plugins
```

That's it. All four commands — `/share-session`, `/fetch-sessions`, `/update-session`, and `/delete-session` — are now available in all your projects.

## Team Setup

Every team member runs the installation above. The first time someone runs `/share-session`, they'll be prompted for:

1. **S3 bucket** — the shared bucket path (e.g., `s3://my-team-sessions`)
2. **Username** — their display name in shared summaries

This is saved to `~/.claude/cc_share_config.json` and reused for all future shares. Make sure everyone on the team points to the **same S3 bucket**.

## Usage

### Share a session

At any point during or at the end of a session:

```
/share-session
```

Claude will:
1. Review the full conversation history
2. Generate a structured markdown summary
3. Upload it to `s3://<bucket>/<your-username>/<descriptive-name>_<timestamp>.md`
4. Return a **share link** you can send to teammates

```
Uploaded to s3://my-team-sessions/Alice/fix-redis-bug_20260408T120000Z.md

Share link: Alice/fix-redis-bug_20260408T120000Z.md
```

### Fetch a teammate's session

```
/fetch-sessions
```

Shows all teammates and their recent sessions at a glance:

```
## Alice
  oauth2-google-sso-implementation_20260331T150000Z.md
  fix-redis-token-expiry-bug_20260331T120000Z.md

## Bob
  terraform-upgrade-to-v5_20260329T180000Z.md
```

Pick a session, and Claude loads the full summary and offers to continue from the listed next steps.

#### Direct link

If you have a share link, skip browsing and load the session directly:

```
/fetch-sessions Alice/fix-redis-bug_20260408T120000Z.md
```

### Update an existing session

Add follow-up findings, comments, or continuation work to a shared session without creating a new one:

```
/update-session Alice/fix-redis-bug_20260408T120000Z.md
```

Claude will:
1. Fetch the existing session
2. Generate an update from your current conversation
3. Append it with your name and timestamp — the original content stays untouched

Multiple team members can update the same session. Each update is clearly attributed:

```markdown
---

## Updates

### Update by Bob — April 9, 2026

Added unit tests for the fix. All passing.

### Update by Carol — April 10, 2026

Deployed to production, confirmed the issue is resolved.
```

### Delete a session

```
/delete-session Alice/fix-redis-bug_20260408T120000Z.md
```

Only the session **owner** can delete it. If you try to delete someone else's session, the command will refuse and tell you who the owner is.

## What Gets Captured

Every summary includes an **overview**, a narrative **what was done** section, and **next steps**. Depending on the session, Claude also includes:

- **Key code** — important snippets with explanations
- **Architecture / design** — diagrams and structural decisions
- **Failed approaches** — dead ends, so teammates don't repeat them
- **Open questions** — unresolved decisions
- **Files changed** — what was created or modified
- **Context for continuation** — env setup, gotchas, dependencies

Claude decides which sections are relevant based on what actually happened in the session.

## S3 Structure

```
s3://your-bucket/
├── Alice/
│   ├── oauth2-google-sso-implementation_20260331T150000Z.md
│   └── fix-redis-token-expiry-bug_20260331T120000Z.md
└── Bob/
    └── terraform-upgrade-to-v5_20260329T180000Z.md
```

Files are named after the session's subject so you know what they contain without opening them.

## Configuration

Config is stored at `~/.claude/cc_share_config.json`:

```json
{
  "backend": "s3",
  "s3_bucket": "s3://your-bucket",
  "username": "Your Name"
}
```

To change your settings, edit this file directly or delete it and run `/share-session` again.

### Local file backend (for testing)

To try cc-share without S3, set the backend to `file`:

```json
{
  "backend": "file",
  "file_dir": "/path/to/shared/directory",
  "username": "Your Name"
}
```

## License

MIT
