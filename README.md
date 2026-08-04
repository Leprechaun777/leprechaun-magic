# Leprechaun-Magic

A collection of Claude Code skills.

## Skills

### [start-up](skills/start-up/SKILL.md)

Beginning-of-session orientation. Invoke it at the start of a working session — with `/start-up` or by saying things like "good morning", "catch me up", or "where were we" — and it rebuilds context before you type a single command. It runs four steps:

1. **Reads CLAUDE.md** (current directory or nearest parent) for the project's purpose, stack, conventions, and anything flagged important.
2. **Loads persistent memory** — user preferences, past feedback, active goals, and deadlines from the memory directory.
3. **Enables remote triggers** so the session can receive remote wake-ups (skipped silently where unsupported).
4. **Checks git** — status, last 10 commits, and current branch.

It then delivers a single briefing under 150 words: project, branch, what the last session was working on, any uncommitted work in progress, and reminders worth flagging — so you can pick up exactly where you left off.

### [close-down](skills/close-down/SKILL.md)

End-of-session housekeeping, the bookend to start-up. Invoke it with `/close-down` or by saying "wrap up", "let's call it", or "we're done for today". It walks through seven steps:

1. **Updates CLAUDE.md** with durable knowledge from the session — new commands, decisions, gotchas — without touching existing content or adding ephemera.
2. **Syncs GitHub issues** against the CLAUDE.md backlog: opens issues for new backlog items, closes issues for items shipped this session.
3. **Updates the README changelog** with an entry for every version shipped since the last session.
4. **Commits and pushes** all work, staging files by name and never staging secrets.
5. **Builds the debug APK** (Android projects) and publishes it as a GitHub Release tagged with the version.
6. **Sideloads the APK to a phone** over wireless adb, falling back to USB, with pairing instructions if neither is connected.
7. **Prunes GitHub Actions artifacts** to stay under the free-plan storage quota.

Before using it, replace the `<owner>/<repo>` placeholders with your repository; steps 5–7 assume an Android/Gradle project and can be skipped for anything else.

### [delegate](skills/delegate/SKILL.md)

Parallel work dispatcher. Type `/delegate` followed by a list of work items (or say "fan these out", "one agent per item") and it hands each item to its own subagent on the model tier that fits the work:

- **opus** for architecture, subtle debugging, and anything where being wrong is expensive;
- **sonnet** for feature implementation, refactors, and tests;
- **haiku** for mechanical bulk edits and rote changes.

It scans the list for real dependencies and builds the minimum number of waves — independent items run in parallel, dependent items wait for their prerequisites. Before spending any tokens it prints a plan showing the model and agent type chosen per item. Items too vague to act on are listed back with questions instead of guessed at. When agents finish, it reports per item what changed, what succeeded, and what failed — including a consistency check across agents that touched the same area.

### [example-skill](skills/example-skill/SKILL.md)

A template, not a working skill. Copy the folder, rename it, and replace the frontmatter and body to start a new skill. It documents the two required frontmatter fields (`name` in kebab-case matching the folder, and a `description` specific enough to trigger at the right time).

## Structure

Each skill lives in its own folder under `skills/`, with a `SKILL.md` that defines it:

```
skills/
  <skill-name>/
    SKILL.md        # frontmatter (name, description) + instructions
    ...             # optional supporting files (scripts, references, templates)
```

## SKILL.md format

```markdown
---
name: my-skill
description: One-line summary of what the skill does and when to use it.
---

Instructions the agent follows when the skill is invoked.
```

## Using these skills

Copy a skill folder into a project's `.claude/skills/` directory (or `~/.claude/skills/` for global use), then invoke it with `/<skill-name>` in Claude Code.
