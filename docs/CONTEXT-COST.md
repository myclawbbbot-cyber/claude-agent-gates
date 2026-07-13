# Context cost: the tax you pay on every gate

Read this before you complain that gating is expensive. The dominant cost of
running these judges is almost certainly **not** the judge prompts. It is the
context your own setup injects into every subagent you dispatch.

---

## The mechanism (documented)

Every non-fork subagent starts with a fresh context that includes **the full
memory hierarchy the main conversation loads** - your `~/.claude/CLAUDE.md`,
project rules, `CLAUDE.local.md`, and managed policy files - plus the agent's
own prompt, the delegation message, and a git-status snapshot.

Source: Claude Code docs, [Subagents - "What loads at startup"](https://code.claude.com/docs/en/sub-agents.md).
(`Explore` and `Plan` are the documented exceptions: they skip CLAUDE.md and
git status.)

The consequence, for this kit specifically:

- **Every gate run** (`scripts/review.sh`) dispatches a subagent -> pays the tax once.
- **Every golden task** (`eval/agent_eval.sh`) dispatches a subagent -> pays the tax
  once *per task*. A 5-task eval pays it 5 times.

So if your always-on context is large, the harness looks expensive - and the
judge prompts (roughly 1,100-1,500 tokens each) are a rounding error next to it.

---

## The fix (documented feature)

Rules can be **path-scoped**: give a rule YAML frontmatter with a `paths:` key
and it loads only when Claude is working with matching files, instead of
unconditionally.

```yaml
---
paths:
  - "src/api/**/*.ts"
  - "**/*.sql"
---

# Rule body: only enters context when a matching file is touched.
```

Rules **without** a `paths:` field are loaded unconditionally - i.e. they are
always-on, and they ride along into every subagent bootstrap.

Source: Claude Code docs, [Memory - "Path-specific rules"](https://code.claude.com/docs/en/memory.md).

Two more levers worth knowing:

| Lever | What it saves |
| --- | --- |
| Declare `tools:` explicitly on an agent | The agent stops inheriting every tool schema (notably MCP servers). All four judges in this repo declare a narrow `tools:` list for exactly this reason. |
| `Explore` / `Plan` subagents | Documented to skip CLAUDE.md + git status entirely - the cheapest way to do read-only research. |

---

## What it was worth in one real setup

A single measured environment, before and after adding `paths:` frontmatter to
18 previously-unscoped user-level rules. Numbers are the first-context size of
freshly dispatched subagents, read from session transcripts:

| | Subagent bootstrap |
| --- | --- |
| Before scoping | ~58,000 - 71,000 tokens |
| After scoping | ~12,000 - 25,000 tokens |

That is roughly a 70-80% cut in what every subagent pays to start.

**Read that as illustrative, not as a benchmark.** It is n=1, in one setup, with
one particular pile of rules. Your ratio depends entirely on how much always-on
context you had to begin with. The honest instruction is the same one this repo
gives everywhere else: **measure your own** before you believe anyone's number,
including this one.

How to measure: dispatch a subagent, then read the first `input_tokens` +
`cache_read` of its transcript under `~/.claude/projects/**/subagents/`. Compare
before and after you scope your rules.

---

## Caveat: known bugs

Path-scoped loading is documented, but there are open bug reports that it does
not always behave as specified - including user-level rules being ignored,
rules loading globally despite frontmatter, and scoping not triggering on
write operations:

- [#22170 - `paths` in user-level rules ignored](https://github.com/anthropics/claude-code/issues/22170)
- [#16299 - path-scoped rules load globally despite frontmatter](https://github.com/anthropics/claude-code/issues/16299)
- [#23478 - path-scoped rules not loaded on write](https://github.com/anthropics/claude-code/issues/23478)

In the measured setup above the feature *did* work (the numbers are real,
post-fix, on a current version). But that is precisely why the instruction is
"measure, don't assume": a fix you did not verify is not a fix. If your
bootstrap does not drop after you scope your rules, you have hit one of these
bugs, and the honest move is to say so rather than to claim the saving.
