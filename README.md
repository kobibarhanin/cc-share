# cc-share

Share Claude Code sessions with your team.

When you finish a task in Claude Code, run `/share-session` to generate a rich summary of what you did — decisions made, code written, dead ends hit — and upload it to a shared S3 bucket. Your teammates run `/fetch-sessions` to browse and load those summaries as context for their own sessions.

## Why

Claude Code sessions are local and ephemeral. When you hand off work to a teammate, the context in your head (and Claude's) is lost. This plugin captures that context as structured markdown and makes it available to the team.

## How It Works

```
You:       /share-session  →  Claude summarizes the session  →  uploads to S3
Teammate:  /fetch-sessions →  browses all shared sessions    →  loads one as context
```

### What gets captured

Every summary includes an **overview**, a narrative **what was done** section, and **next steps**. Depending on the session, Claude also includes:

- **Key code** — important snippets with explanations
- **Architecture / design** — diagrams and structural decisions
- **Failed approaches** — dead ends, so teammates don't repeat them
- **Open questions** — unresolved decisions
- **Files changed** — what was created or modified
- **Context for continuation** — env setup, gotchas, dependencies

Claude decides which sections are relevant based on what actually happened in the session.

### S3 structure

```
s3://your-bucket/
├── alice/
│   ├── oauth2-google-sso-implementation_20260331T150000Z.md
│   └── fix-redis-token-expiry-bug_20260331T120000Z.md
└── bob/
    └── terraform-upgrade-to-v5_20260329T180000Z.md
```

Each file is named after the session's subject, not a generic ID.

## Installation

### As a plugin

```
/plugin install cc-share
```

Or add the marketplace and install:

```
/plugin marketplace add kobibarhanin/cc-share
/plugin install cc-share@kobibarhanin-cc-share
```

### Manual

Clone the repo and copy the skills to your user-level Claude config:

```bash
git clone https://github.com/kobibarhanin/cc-share.git
cp -r cc-share/skills/share-session ~/.claude/skills/
cp -r cc-share/skills/fetch-sessions ~/.claude/skills/
```

## Setup

The first time you run `/share-session`, it will ask for:

1. **S3 bucket** — where to store summaries (e.g., `s3://my-team-shares/cc-sessions`)
2. **Username** — your display name in shared summaries

This is saved to `~/.claude/cc_share_config.json` and used for all future shares. Each team member runs setup once on their machine.

### Prerequisites

- [AWS CLI](https://aws.amazon.com/cli/) installed and configured with access to the shared bucket
- An S3 bucket accessible to all team members

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

This shows all teammates and their recent sessions:

```
## Alice
  oauth2-google-sso-implementation_20260331T150000Z.md
  fix-redis-token-expiry-bug_20260331T120000Z.md

## Bob
  terraform-upgrade-to-v5_20260329T180000Z.md
```

Pick a session, and Claude loads the full summary and offers to continue from the listed next steps.

## Configuration

Config is stored at `~/.claude/cc_share_config.json`:

```json
{
  "backend": "s3",
  "s3_bucket": "s3://your-bucket/path",
  "username": "Your Name"
}
```

### Local file backend

For testing without S3, you can set the backend to `file`:

```json
{
  "backend": "file",
  "file_dir": "/path/to/shared/directory",
  "username": "Your Name"
}
```

## License

MIT
# cc-share
