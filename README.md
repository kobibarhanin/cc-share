# cc-share

Share Claude Code sessions with your team.

When you finish a task in Claude Code, run `/share-session` to generate a rich markdown summary of what you did — decisions made, code written, dead ends hit — and upload it to a shared S3 bucket. Your teammates run `/fetch-sessions` to browse and load those summaries as context for their own sessions.

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

That's it. Both `/share-session` and `/fetch-sessions` are now available in all your projects.

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
