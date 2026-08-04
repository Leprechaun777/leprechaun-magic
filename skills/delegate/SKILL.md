---
name: delegate
description: >
  Shortcut placed before a list of work items. Each item is evaluated for the
  right model tier (opus / sonnet / haiku), then handed to its own subagent
  running on that model. Independent items are spawned in parallel; items with
  real dependencies are run in ordered waves. Use when the user types
  "/delegate" followed by a list, or says "delegate these", "fan these out",
  "one agent per item", "spread these across subagents".
---

# delegate

The user has handed you a list. **One subagent per item, each on the model that fits
that item's work.** Independent items go out in parallel; dependent items go in later
waves.

Invoking this skill **is** the user's explicit request to spawn subagents — the usual
"don't spawn agents unless asked" rule is satisfied. Do not ask again for permission
to delegate.

## Step 1 — Extract the items

The list may follow the shortcut inline, appear in the same message, or be the message
right after. Accept any of: numbered list, `-`/`*` bullets, one item per line, or a
comma-separated run when the items are obviously distinct.

Default is **1 item = 1 subagent**. Do not silently merge, split, reorder, or drop
items. Two exceptions, and both get stated out loud in the plan:

- Two items are the same edit to the same file → merge into one agent (parallel edits
  to one file corrupt each other).
- One item is really N independent tasks in a trenchcoat → split, and say so.

If an item is too vague to act on (no file, no verb, no acceptance condition), do not
guess. Delegate everything else and list the unclear ones back at the end.

## Step 2 — Assign a model per item

**If the project's CLAUDE.md has a model-assignment table, that table wins.** Read it
and follow it. Otherwise use this rubric:

| Item looks like | Model | Why |
|---|---|---|
| Architecture, design, subtle debugging, concurrency/ordering correctness, algorithm or data-model reasoning, anything where being wrong is expensive and not obvious | `opus` | Hardest reasoning; correctness matters most |
| Feature implementation, refactors, multi-file edits, writing tests, API/schema work with a known shape | `sonnet` | Strong code quality at lower cost |
| Mechanical bulk edits, rote find-replace, fixture wiring, string extraction, formatting, log/output triage, file inventory | `haiku` | Needs throughput, not depth |

Rules:

- **Pass `model` explicitly on every spawn.** Never let an agent inherit the session
  model by omission — the assignment is the whole point of this skill.
- When torn between two tiers, take the cheaper one. Escalate by re-running that one
  item on the higher tier if the result comes back wrong.
- Judge the item's *work*, not its word count. "Fix the off-by-one in the retry guard"
  is short and is `opus`. "Rename this symbol across 40 files" is long and is `haiku`.
- Pick `subagent_type` too: `Explore` for read-only search/locate items, `Plan` for
  design-only items, `general-purpose` (or the project's own agent types) for anything
  that writes.

## Step 3 — Order into waves

Scan the whole list for dependencies before spawning anything. Item B depends on item A
when:

- B consumes A's output ("using the parser from item 1…", "then wire it up").
- B edits a file A creates or restructures.
- A and B write the same file, and both are non-trivial.
- The user wrote sequencing language: "then", "after that", "once X is done".

Everything else is independent. Build the **minimum** number of waves — do not serialize
out of caution. A five-item list with one dependency is two waves, not five.

If two same-wave items both write to the repo but to different files, prefer
`isolation: "worktree"` on each so they can't collide. Skip worktrees for read-only
items (they cost setup time and disk) and skip them outside a git repo.

Concurrency caps out around 10–16 concurrent agents; a wave larger than that still
completes, it just queues. Don't hand-batch it.

## Step 4 — Show the plan, then spawn

Print a compact plan first — one line per item — so the user can see the model choices
before the tokens are spent:

```
Wave 1 (parallel)
  1. <item>              → sonnet / general-purpose
  2. <item>              → haiku  / general-purpose
  3. <item>              → opus   / Plan
Wave 2 (after 1)
  4. <item>              → sonnet / general-purpose
```

Then spawn. **Issue every Agent call for a wave in a single message** so they actually
run concurrently — separate messages serialize them.

- Set `run_in_background: false` for a wave that a later wave depends on, so you have
  the results before continuing.
- The final wave (or a single-wave list) can run in the background; you'll be notified
  as each finishes.
- Never fabricate or predict a pending agent's result. If the user asks before the
  notification lands, say it's still running.

Each agent starts **cold** — it has none of this conversation. Every prompt must stand
alone: the concrete task, the file paths, the relevant constraint or gotcha from
CLAUDE.md, and what "done" means. A one-line prompt copied from the user's bullet is
almost never enough.

## Step 5 — Report

Agent final reports are not shown to the user — relay what matters yourself.

One short block per item: what it changed (files), whether it succeeded, and anything
the user has to decide. Report failures plainly with the actual error; do not describe
a partially-done item as done. If an item was skipped as too vague, list it here with
the question you need answered.

If several agents touched the same area, say whether their changes are consistent —
that check is yours, not theirs.

## Notes

- Delegation is the deliverable here; don't quietly do half the list inline because it
  "seemed faster."
- Cost scales with list length. If a list is very long (say 20+) and the items are
  clearly one-liners, say so and offer to run them inline instead — but only offer,
  don't decide.
- To continue an agent that already has context, use `SendMessage` with its id rather
  than spawning a fresh one.
