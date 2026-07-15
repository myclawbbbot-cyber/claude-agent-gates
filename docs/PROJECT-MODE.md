# Three-gate project mode: strategy -> plan -> execute

The gate in this kit judges *deliverables*. This document is about the layer
above it: how to stop a capable agent from building the wrong thing fast.
The failure mode it targets is specific - an agent (or an eager human) takes a
one-line idea, silently fills in every open decision, and starts building.
The work is often good. The direction is often wrong. And a wrong direction
discovered after the build costs more than every bug the gate will ever catch.

The mechanism is three documents per project, each ending in a **human gate**:

```
plans/<project>/
  strategy.md    # WHAT and WHY  -> gate 1: direction approved
  plan.md        # HOW, in steps -> gate 2: plan + pre-approvals approved
  execution.md   # progress log  -> gate 3: explicit "go", then build
```

A numbered registry (one line per project in a `plans/INDEX.md`) keeps the
portfolio visible - which projects exist, where they live, what state they
are in.

## When to invoke it (and when not to)

Run three-gate mode when the work is **substantial, hard to reverse, or
crosses sessions**: it spends money, touches external users or shared
infrastructure, spans more than a handful of steps, or will outlive the
conversation that started it. For a small reversible task, the two-step from
`GOVERNANCE.md` section 4 (build -> gate) is enough; wrapping a one-hour fix
in three gated documents is ceremony, not governance.

## Gate 1 - strategy: red-team the direction, restate the acceptance

`strategy.md` states the problem, the chosen direction (with the forks that
were explicitly rejected), and the **acceptance anchors** - the observable
outcomes that will count as success.

Two rules make this gate real rather than decorative:

- **An independent red team reviews the direction before the human sees it.**
  Same contract as the `critic` agent in this kit: findings ranked, major
  findings escalated verbatim. Direction-level critiques ("this solves the
  wrong problem", "the acceptance test is circular", "an existing tool does
  this") are exactly what a builder-mindset review misses.
- **The human restates the acceptance anchors in their own words.** Not
  "ok", not "approved" - a restatement. A one-word approval happily coexists
  with a fundamental misunderstanding; a restatement surfaces it now, when
  it is cheap. In one measured setup this rule caught a semantic mismatch
  (two parties holding different definitions of the same constraint) that
  would otherwise have invalidated a finished deliverable.

## Gate 2 - plan: milestones, and pre-approvals up front

`plan.md` decomposes the direction into milestones with verifiable exit
criteria, and - the part that pays rent - a **pre-approval checklist**: every
destructive operation, externally visible action, or spend the execution
phase will need, listed now and approved in one batch.

Pre-approvals matter for autonomous execution: an agent that must stop
mid-build to ask "may I run the migration?" either stalls the project or -
worse - decides not to ask. Enumerating the dangerous operations at plan time
converts them from judgment calls into checked boxes.

The plan also gets a critic pass before the human gate. Plan-level findings
run to unrealistic sequencing, missing fallbacks with no drop-dead date,
milestones whose "done" cannot be verified, and hidden dependencies on
decisions nobody has made yet.

## Gate 3 - execution: an explicit go, and a handover header

The rule that gets violated most: **refining the plan is not authorization to
execute.** Neither is an approved strategy. The build starts on an explicit
"go" against the plan the human last saw - nothing weaker. If the human's
wording is ambiguous ("looks good", "makes sense"), ask; do not treat
politeness as a green light. The same applies within execution: approval to
*produce* a deliverable is not approval to *deploy* it over the live one.

`execution.md` is append-only during the build: what was done, what was
verified (with the actual command or test output), what bounced at the gate
and why. Its header carries a **handover block** kept permanently current -
task state, next step, file map, red lines, decisions pending the human - so
any fresh session can take over from the file alone, without re-reading a
transcript. (Why fresh sessions matter at all is a cost argument; see
`TOKEN-ECONOMY.md` section 3.)

## Two anti-patterns this structure exists to block

**Retroactive completeness.** A strategy document written after the direction
was already chosen looks exactly as thorough as one that gated a real
decision - and proves nothing. The gates only de-risk anything when they run
*prospectively*, on decisions whose outcome is genuinely open. If you
back-fill the documents for a project already underway, mark them as
back-filled; do not let a tidy paper trail impersonate a tested one.

**Building mechanism for imagined needs.** Before adding a new gate, rule, or
automation to your own process, demand the same evidence you would demand of
a deliverable: has the failure it prevents actually happened? What runs it -
a hook, a cron job, a checklist that something enforces - or only the good
intentions of your future self? A mechanism with no execution anchor is
context tax plus self-deception; prefer writing down a one-line observation
and building the gate the first time the failure actually occurs.

## Composition with the rest of the kit

The three gates sit *above* the quality gate, not instead of it: every
milestone's deliverable still goes through `qa-gate` (build -> judge ->
bounce -> fix), and judge prompts stay under the eval harness. Project mode
decides whether you are building the right thing; the gate decides whether
you built the thing right.
