# Subagent architecture: roles, model tiers, and the dispatch contract

This kit ships judges. This document describes the shop around them: how to
structure a standing set of subagents so that judgment stays independent,
mechanical work stays cheap, and the orchestrator stays small. It is one
architecture that works, measured in one real setup - adapt the roster, keep
the separations.

## The shape: a small orchestrator over specialist roles

The main conversation loop acts as the **orchestrator**: it talks to the
human, decomposes work, dispatches legs, reads results, and makes the calls
that need whole-picture judgment. Everything else is a role with a narrow
charter and - critically - a narrow `tools:` list:

| Role | Charter | Writes? | Typical tier |
| --- | --- | --- | --- |
| orchestrator (main loop) | decompose, dispatch, synthesize, face the human | yes | flagship |
| engineer | build: code, tests, migrations, investigation-to-build | yes | strong |
| qa-gate | burden-of-proof judge of deliverables (this kit) | **no** | strong |
| critic | standing red team on direction and design (this kit) | **no** | strong |
| researcher | multi-source facts with verification, web + data | no | strong |
| pm | decompose goals, sequence milestones, track | docs only | strong |
| wordsmith | polish user-facing prose after facts are fixed | docs only | mid |
| bulk-worker | mechanical fan-out legs to a fixed spec | yes | **cheap, pinned** |
| quick-lookup | single-fact reads: one file, one grep, one URL | no | smallest |

Three structural rules carry most of the value:

- **Judges never write.** `qa-gate` and `critic` have no edit tools by
  design; a judge that can fix the work it judges will start doing so, and
  self-graded work drifts (see `GOVERNANCE.md` section 1).
- **The builder's green is not evidence.** A builder's own test suite can
  encode the builder's own misunderstanding as a passing assertion - the
  planted-bug golden task in `eval/` exists precisely because a green
  self-report hid a real defect. The gate constructs its own should-fail
  cases instead of rerunning the builder's.
- **Value concentrates in the gate, not in headcount.** When a task is
  well-defined, engineer -> qa-gate is the whole pipeline. Skip the roles
  that add ceremony; never skip the gate (`GOVERNANCE.md` section 4).

## Model tiers and bucket economics

Pin the model per role with `model:` frontmatter in the agent file - the same
mechanism this repo's agents use for `tools:`. Two reasons, one obvious and
one not:

1. **Fit.** Judgment roles earn the strong model; a fixed-spec batch leg does
   not get better with a bigger model, only more expensive.
2. **Buckets.** On subscription plans, usage quotas are per-model-tier
   buckets, typically use-it-or-lose-it per cycle. Routing a mechanical leg
   to the flagship wastes twice: it burns the scarce bucket *and* leaves the
   cheap bucket idle. In the measured setup, moving batch legs (file
   conversion, fixture generation, multi-source fetches, template drafts) to
   a pinned cheap-model `bulk-worker` moved ~40% of subagent output tokens
   off the main bucket on fan-out-heavy days.

Two verification habits, both cheap and both earned by incidents:

- **Verify the pin from transcripts, not from config.** The `model` field on
  each API call in the subagent's transcript is ground truth; a config that
  *says* `model: sonnet` proves nothing about what actually served the call.
- **Judge routing by what the work was, not by the share alone.** A
  low cheap-model share on a judgment-heavy day is correct routing, not a
  leak (`TOKEN-ECONOMY.md` section 2 documents a false alarm in full).

## The dispatch contract

The orchestrator's half of the bargain:

- **One complete first message.** Goal, constraints, acceptance criteria,
  exact paths, known landmines - a subagent cannot ask a good follow-up
  question against a vague brief, and every clarifying round trip re-pays the
  leg's accumulated context (`TOKEN-ECONOMY.md` section 4).
- **Name the red lines.** If a script is destructive, if a directory is
  production, if data is live - say so in the dispatch, not after. In the
  measured setup, the incidents that reached live systems all trace to a
  landmine the dispatcher knew about and did not write down.
- **Short legs, intermediates to disk.** Split marathon work; have legs
  return paths and summaries, not bulk content.

The subagent's half is a fixed **four-field handoff**: what was done; how it
was verified (commands run, outputs observed - not "verified" as a word);
what failed or was skipped, item by item; what remains. The bulk lane adds
one absolute: **report the misses.** "Processed 47 of 50, 3 failed: ..." is a
usable result; a clean-looking 47 with silent truncation is the one
unforgivable bulk failure, because nothing downstream will ever look for it.

## Independence add-ons for high-stakes work

For deliverables where a wrong PASS is expensive, two upgrades from the
measured setup, both also noted in `GOVERNANCE.md`:

- **Cross-family second opinion.** A same-family judge shares blind spots
  with the builder. A different-model-family gate pass over the same
  deliverable has repeatedly caught what the first gate scored as clean.
- **Independent re-verification of self-reported gates.** When a builder
  reports "gate passed" on its own run, re-dispatch the gate independently
  before believing it. The gate being real is the point; a gate run by the
  party being gated is a self-report with extra steps.

## Shipped example

`.claude/agents/bulk-worker.md` in this repo is the cheap-lane agent from the
table above, pinned to a mid/cheap tier with `model:`, with the four-field
handoff and the report-the-misses rule in its charter. Adapt the tool list
and tier to your stack; keep the charter boundary ("no judgment calls in the
bulk lane") intact.
