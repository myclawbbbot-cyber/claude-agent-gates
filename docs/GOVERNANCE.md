# Governance

Design rationale behind the kit. The agents and scripts are the mechanism;
this document is the reasoning. Five rules, each tied to the piece that
enforces it (or honestly marked prompt-level where nothing does).

---

## 1. Separation of duties

The agent that judges never wrote the work, and has no write access. It issues a
verdict; it does not fix. The builder fixes; the gate judges. An agent that grades
its own output will find reasons its output is fine - the whole point of the gate
is to break that loop.

Concretely: the `qa-gate` agent ships with `tools: Read, Bash, Grep, Glob` - no
`Write`, no `Edit`. It can reproduce and verify, but it cannot change what it is
reviewing, and it must refuse to review anything it authored.

---

## 2. Scored gate with a hard threshold, and a mandatory bounce

The gate scores each deliverable against a rubric - each applicable dimension 0-4,
default FAIL, points earned only with evidence the judge reproduced itself. A score
below the threshold is a **mandatory bounce back to the builder**. There is no
"close enough".

The threshold (see `.claude/agents/qa-gate.md` for the operative copy):

- no dimension below 3;
- `correctness = 4` (and `verification = 4` for any system; for money / security /
  destructive work those must be 4 too - a critical dimension below 4 is an
  automatic FAIL regardless of total);
- total >= 90% of the applicable max;
- at least one real break-attempt was logged and none surfaced an unhandled failure.

A score the judge cannot back with evidence it personally reproduced is capped at 1;
an unconfirmed `verification` is a hard 0. The builder's "Verified" claim is an
unproven claim until the judge re-runs it.

**Two consecutive bounces on the same deliverable escalate to a human owner** rather
than looping forever. `scripts/verdict.sh` implements this: it counts consecutive
FAILs and prints an `ESCALATE` notice at two.

### Live-integration clause

For anything touching access control, multi-component integration, or cross-artifact
coupling, offline unit tests passing does **not** earn `verification = 4`. Those tests
exercise one component in isolation and miss the coupling gaps that only appear once
the pieces run together. Verification here requires (a) a live end-to-end check that
drives the actual integrated flow, and (b) deterministic coupling assertions for any
"register in N places" change (a new file that must also join a deploy list, a new
field that must also join a migration). Make the omission auto-fail; do not rely on
memory.

---

## 3. The handoff contract

Every stage returns in four fields, so the next stage chains off structure rather
than vibes:

- **Deliverable** - what was produced (files as `path:line`, key decisions, how to run it).
- **Verified** - exactly how it was confirmed to work: commands run + observed output. Anything not verified is stated plainly here. This is the field the gate audits.
- **Risks** - edge cases, assumptions, anything fragile or untested.
- **Next** - what is left, or "ready for the gate".

If a stage returns a malformed contract (a missing field, an answer that does not
match the task, self-contradiction), the orchestrator retries once with a specific
description of what was wrong - not a blind re-send - then falls back or escalates.

---

## 4. Right-size the pipeline

More stages is not more quality. In one measured run (n=1, a single well-defined
single-file task -- illustrative, not a benchmark), a full multi-stage pipeline
cost roughly five times the tokens of a two-step `build -> gate` for the same
deliverable quality. The value did not live in the stage count - it lived in the
gate, which caught a real edge-case defect that the builder's own tests missed.
Measure your own ratio before trusting ours; the point is where the value
concentrates, not the multiplier.

The rule that falls out of that:

- **Well-defined, single-file, no real decomposition needed** -> `build -> gate (-> bounce -> gate)`. Skip the planning stage. **Never skip the gate.**
- **Multi-file, cross-system, ambiguous goal, or needs research** -> a full pipeline earns its cost; up-front decomposition has ROI there.
- **Unsure** -> two-step; you can always add planning later.

You can economize on structure. You cannot economize on the gate.

---

## 5. Escalate real disagreement to a human - verbatim

The kit adds a standing red team (`critic`) above the gate: the gate asks "is this
deliverable built correctly?", the critic asks "is this direction / decision good at
all?". The critic marks each critique `Major` or `Minor`.

The final say on a `Major` disagreement does **not** rest with the orchestrator. On
concede, the decision goes to the human owner; on rebut, it is a mandatory escalation
and **the critic's original wording reaches the human verbatim - the orchestrator does
not rewrite or soften it**. The orchestrator settles only `Minor` points on its own.

Why the veto on major disagreements does not stay with the orchestrator - this is the
load-bearing part, and it rests on published findings, not preference:

- **A model correcting its own reasoning is unreliable without an external signal.**
  Left to self-correct with no outside anchor, models can make their answers *worse*,
  not better (Huang et al., *Large Language Models Cannot Self-Correct Reasoning Yet*,
  ICLR 2024). At the decomposition / direction layer there is no test to reproduce, so
  a single orchestrator that both proposes and judges has no external anchor.
- **A model judging output shares a self-preference bias.** An LLM acting as judge
  tends to favor outputs from its own family / style (Zheng et al., *Judging
  LLM-as-a-Judge with MT-Bench and Chatbot Arena*, NeurIPS 2023). One model family
  judging its own family shares the blind spot; a cross-family second opinion is what
  breaks it (see below).
- **Assigned dissent only changes decisions when it carries real consequences.** A
  devil's advocate that can be quietly overruled becomes theater; dissent improves
  decisions only when it can actually alter the outcome (Nemeth et al., *European
  Journal of Social Psychology*, 2001).
- **Independent assurance must report to the top, not to the audited.** An assurance
  function that reports to the party it audits is not independent (IIA, *Three Lines
  Model*, 2020).

The orchestrator is simultaneously the author, the audited, and the judge - so the
final call on a major disagreement must leave its hands and reach the human, who is
the only real external signal in the loop.

### Cross-family second opinion on high-stakes work

For deliverables that touch money, security, irreversibility, or core direction, take
at least one second opinion from a **different model family** than the one that built
and gated the work. A judge chain that is one model family end to end shares a
structural self-preference bias and consensus blind spots; a genuinely different
family is what surfaces what the first family cannot see. Low-stakes work does not
need it - reserve it for where a miss is expensive.

You can wire this in by pointing `GATES_REVIEW_AGENT` at a second gate configured to
run a different model, or by running the same golden set through a second judge and
comparing.

---

## References

- Huang, J. et al. (2024). *Large Language Models Cannot Self-Correct Reasoning Yet.* ICLR 2024.
- Zheng, L. et al. (2023). *Judging LLM-as-a-Judge with MT-Bench and Chatbot Arena.* NeurIPS 2023.
- Nemeth, C. et al. (2001). *Improving decision making by means of dissent.* European Journal of Social Psychology.
- Institute of Internal Auditors (2020). *The IIA's Three Lines Model.*
