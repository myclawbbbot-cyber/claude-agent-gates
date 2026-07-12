# claude-agent-gates

**A governance layer for multi-agent Claude Code - not another agent collection.**

<!-- badges: add once CI is wired -->
<!-- ![CI](https://img.shields.io/github/actions/workflow/status/myclawbbbot-cyber/claude-agent-gates/ci.yml) -->
<!-- ![License: MIT](https://img.shields.io/badge/license-MIT-green) -->

> Agents that grade their own work drift. This kit ships a burden-of-proof
> quality gate, a red-team escalation contract, and a regression harness for the
> judges themselves.

Most agent kits give you *more builders*. The failure mode of a builder-heavy
setup is not "not enough agents" - it is that the same model writes the work,
reviews the work, and declares it done. Self-graded work drifts: the reviewer
finds reasons the output is fine, edge cases go untested, and a green self-report
hides a real defect. This kit is the layer that stops that.

Three pillars:

1. **A burden-of-proof quality gate** (`qa-gate`) - default FAIL, points earned
   only with evidence the judge reproduced itself, a hard pass threshold, and a
   mandatory bounce below it. It has no write access; it judges, it never fixes.
2. **A red-team escalation contract** (`critic`) - a standing devil's advocate
   whose *major* disagreements cannot be quietly overruled: they escalate to a
   human, verbatim.
3. **A regression harness for the judges themselves** (`eval/`) - because a judge
   is a prompt, and a prompt is production code. Golden tasks, grep assertions,
   a score history that blocks a ship when it drops.

## Honest positioning

This is a governance / strictness layer. It composes with the tools below rather
than replacing them.

| If you want... | Use | This kit instead gives you |
| --- | --- | --- |
| A big library of ready-made builder agents | an agent collection (e.g. `wshobson/agents`) - they are good at that | the gate that judges whatever those agents produce |
| A full-featured evaluation / red-teaming framework | `promptfoo` - heavier, richer, the right tool for serious eval | a lean, zero-dependency regression harness aimed specifically at your *judge* prompts |
| More agents doing more work | - | fewer agents, held to a harder standard |

If you already have builder agents you like, keep them. Point this gate at their
output.

## What's in the box

```
.claude/agents/
  qa-gate.md        # the burden-of-proof quality gate (read-only judge)
  critic.md         # the standing red team, with the verbatim-escalation contract
  code-reviewer.md  # a neutral example agent to adapt
  fact-checker.md   # a neutral example agent to adapt
docs/GOVERNANCE.md  # the five load-bearing rules + the literature behind them
scripts/
  review.sh         # run the gate against a diff/dir/file, exit on the verdict
  verdict.sh        # parse a review, exit 0/1 (fail-closed), escalate after 2 FAILs
  verdict_test.sh   # self-test battery for verdict.sh
eval/
  agent_eval.sh     # the regression harness for judgment agents
  golden/           # neutral golden tasks (planted bug, clean pass, fabricated stat)
examples/demo.md    # a full build -> gate -> bounce -> fix -> PASS walkthrough
```

## 60-second quickstart

Requires the [Claude Code CLI](https://docs.claude.com/en/docs/claude-code) on your
`PATH`.

> **The gate reproduces tests via Bash.** To hold the burden of proof on the
> deliverable, the judge runs the target's tests itself (it has the `Bash` tool).
> That means it executes code from whatever you point it at - so only point it at
> code you would be willing to run locally. This is true by default, not only under
> `GATES_YOLO`.

```bash
# 1. Clone it. The judges live in .claude/agents/, so Claude Code picks them up
#    automatically when you run inside the repo.
git clone https://github.com/myclawbbbot-cyber/claude-agent-gates
cd claude-agent-gates

# 2. Run the gate against something. Here, one of the golden fixtures with a
#    planted off-by-one bug and a self-report that claims all tests are green:
scripts/review.sh eval/golden/qa-gate/gt1-planted-bug \
  "implement page_count; the final partial page must be counted"

#    -> the gate reproduces the spec, constructs the case the shipped tests miss,
#       prints a scorecard, and exits 1 with VERDICT: FAIL.

# 3. Run the same gate against a genuinely clean deliverable:
scripts/review.sh eval/golden/qa-gate/gt2-clean-pass \
  "implement clamp into an inclusive range"
#    -> VERDICT: PASS, exit 0.
```

That is the whole loop: `review.sh` returns a shell exit code, so you can gate a
commit or a CI step on it:

```bash
scripts/review.sh ./src "the goal this change must satisfy" || exit 1
```

To keep the *judges* honest as you edit their prompts, run the regression harness:

```bash
bash eval/agent_eval.sh qa-gate    # runs every golden task, greps the assertions,
bash eval/agent_eval.sh critic     # appends a score line to eval/baselines/<agent>.tsv
```

Run it before you edit a judge to capture a baseline, and after to compare. A drop
in the total blocks the change - see `docs/GOVERNANCE.md`.

Assertions live in each task's `assert.txt` as `MUST:<regex>` / `MUST_NOT:<regex>`.
An assertion that mentions `VERDICT:` is matched against the review's extracted
final verdict token (the last `VERDICT: PASS|FAIL`, parsed the same way
`verdict.sh` does), not the raw transcript - so a judge that quotes the assertion
text in its own prose cannot cause a false match. All other patterns match the
whole transcript.

The gate's own parsing logic is tested too, without spending any model calls:

```bash
bash scripts/verdict_test.sh   # asserts verdict.sh's fail-closed + escalation behavior
```

## A note on where the teeth are

The two pillars are not equally enforced, and it is worth being clear about that.
The **gate** has mechanical teeth: `verdict.sh` is a script that fails closed and
returns a real exit code your CI obeys. The **critic's verbatim-escalation contract**
is a *prompt-level* agreement - it lives in the agent's instructions and in
`docs/GOVERNANCE.md`, and nothing in this kit forces an orchestrator to honor it. It
is a discipline you adopt, not a gate a script enforces. Treat it as such.

## How Claude Code finds the agents

The judges are stored under `.claude/agents/` at the repo root. Claude Code
discovers project-scoped agents from the `.claude/agents/` directory of the project
you are working in, so **cloning the repo and running the scripts from inside it is
all you need** - no install step, no copying files into your home directory. The
scripts run `claude` with the repo root as the working directory for exactly this
reason.

If you want these agents available in *every* project, copy them into your user
agents directory (`~/.claude/agents/`) as well.

## Headless / CI usage

By default the scripts run the judge with an allowlist of only the read/verify
tools it needs (`--allowedTools "Bash Read Grep Glob"`), so a headless run never
turns off permission checks wholesale - it grants the judge exactly the tools it
uses to reproduce and verify.

If you need to run fully unattended and want to skip permission prompting entirely,
set `GATES_YOLO=1`, which adds `--permission-mode bypassPermissions`. This runs the
agent with permission checks off - **use it only in an environment you trust, and at
your own risk.** It is never the default.

Other knobs (all optional):

- `GATES_REVIEW_AGENT` - which agent `review.sh` uses (default `qa-gate`; point it
  at a stricter or a different-model gate for a cross-family second opinion).
- `GATES_CLAUDE_BIN` - path to the `claude` binary if it is not on `PATH`.
- `GATES_STATE_DIR` - where the FAIL-streak and last review are stored (default
  `.gates/`); give each deliverable its own dir for per-deliverable streak tracking.

## License

MIT - see [LICENSE](LICENSE).
