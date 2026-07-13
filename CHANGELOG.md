# Changelog

All notable changes to this project are documented here. This project adheres to
[Semantic Versioning](https://semver.org/).

## [0.1.1] - 2026-07-13

### Added

- **`docs/CONTEXT-COST.md`** - why the dominant cost of running these judges is
  usually your own always-on context, not the judge prompts. Documents the
  subagent bootstrap mechanism (subagents inherit the full memory hierarchy, per
  the official docs), the `paths:` frontmatter fix for path-scoped rules, the
  explicit-`tools:` and Explore/Plan levers, one measured before/after
  (~71k -> ~13k subagent bootstrap; n=1, illustrative, measure your own), and the
  known open bugs on path-scoped loading.
- README section pointing at it, for anyone who finds gating expensive.

## [0.1.0] - 2026-07-12

First public release.

### Added

- **`qa-gate` agent** - a burden-of-proof quality gate: default FAIL, 0-4 rubric
  per dimension, a hard pass threshold, mandatory bounce below it, a live-integration
  clause, and a machine-parsable `VERDICT` / `SCORE` output contract. Read-only by
  design; refuses to review its own output.
- **`critic` agent** - a standing red team / devil's advocate with a four-field
  critique contract and the verbatim-escalation rule for major disagreements.
- **`code-reviewer` and `fact-checker` agents** - neutral, adaptable example agents
  that demonstrate the pattern.
- **`scripts/review.sh` + `scripts/verdict.sh`** - run the gate against a diff, file,
  or directory and gate a shell/CI step on the verdict; fail-closed score cross-check;
  escalate after two consecutive FAILs.
- **`scripts/verdict_test.sh`** - a self-test battery for `verdict.sh` (fail-closed
  cases, the escalation streak, threshold validation) that spends no model calls.
- **`eval/agent_eval.sh`** - a lean regression harness that treats a judge's prompt as
  production code: golden tasks, `MUST` / `MUST_NOT` grep assertions, and a committed
  score history that blocks a ship when it drops.
- **Golden tasks** - a planted off-by-one bug (must FAIL), a genuinely clean deliverable
  (must PASS), and a fabricated statistic in a public draft (the critic must catch).
- **`docs/GOVERNANCE.md`** - the five load-bearing rules and the published findings
  behind them.
- **`examples/demo.md`** - a full `build -> gate -> bounce -> fix -> PASS` walkthrough.

[0.1.0]: https://github.com/myclawbbbot-cyber/claude-agent-gates/releases/tag/v0.1.0
