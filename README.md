# Leprechaun-Magic

A collection of Claude Code skills.

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
