# Token economy: instrument, then cut

`CONTEXT-COST.md` covers the first tax: the always-on context that rides into
every subagent bootstrap. This document covers what you hit after you fix
that - the structural costs of running a multi-agent setup over days and
weeks, and how to measure them from data you already have.

Everything below follows one iron rule: **instrument first**. Every number in
this document came out of session transcripts, not intuition. Optimizing token
spend without measurement reliably produces confident fixes to non-problems -
including, in one live case below, a "fix" to a leak that did not exist.

---

## 1. Your transcripts are already a ledger

Claude Code writes a JSONL transcript per session (and per subagent) under
`~/.claude/projects/`. Every API call in it carries a `usage` block: input
tokens, output tokens, cache reads, cache writes, and the model that served
it. That is an event-level billing ledger, sitting on your disk, for free.

A workable pipeline is small:

1. **Collector** - an incremental script that walks the transcript files
   (main sessions and `**/subagents/*.jsonl`), parses new lines only
   (byte-offset resume), and appends per-call rows to a SQLite database.
2. **Scorecard** - a report that compares the last N days against the N days
   before: totals, main-loop vs subagent split, output share by model
   family, heaviest sessions, heaviest subagent legs, bootstrap sizes of
   newly dispatched agents.
3. **Tripwires** - thresholds on the scorecard that print warnings and set a
   nonzero exit code, so a cron job can page you instead of you rereading
   dashboards.

Tripwire families that earned their keep in one measured setup:

| Tripwire | Fires when | What it catches |
| --- | --- | --- |
| Session per-call cache read | avg cache read per call in a window exceeds a ceiling (e.g. 250k) | a long-lived "mega session" taxing every call |
| Marathon subagent | one leg's window cache read exceeds a ceiling (e.g. 300M) | a leg that should have been split or moved to a script |
| Subagent bootstrap | first-call prefix of a new agent exceeds a ceiling (e.g. 25k) | always-on context regressions (see `CONTEXT-COST.md`) |
| Big payload lines | many transcript lines over ~400kB | screenshots / large tool results accumulating in context |
| Bucket share | cheap-model share of subagent output falls below a floor | mechanical work routed to the expensive model (but see the caveat below) |
| Per-tool error rate | a tool's error rate exceeds ~10% | every error is a full-context call that bought nothing |

## 2. A dashboard without a data cutoff will eventually lie to you

A live incident, verbatim from the setup that produced this document: the
scorecard read its SQLite database and reported the cheap-model share of
subagent output at 0-3%, three days running. The obvious conclusion - a
routing leak - was drafted, with a fix. It was wrong. The collector ran on a
daily schedule; the day's mechanical legs had been dispatched *after* the
last collection, and the database simply had not seen them. Re-collecting
put the true share at 38%. The routing was fine; the dashboard was stale.

Two mechanical fixes, both cheap:

- The report **runs the collector itself** before reading (incremental
  collection is idempotent and takes seconds), with an opt-out flag.
- The report header prints a **freshness line** - data cutoff timestamp and
  lag - with a warning marker when the lag exceeds a couple of hours.

The transferable rule: any report that does not state its data cutoff will
eventually be read as current when it is not, and someone will act on it.

A second caveat on the bucket-share tripwire specifically: a low cheap-model
share is only a leak if mechanical legs *existed* that day. A day of pure
judgment work (reviews, design decisions) correctly routes everything to the
strong model. Check what was dispatched before concluding anything.

## 3. The mega-session tax, and session rotation

The mechanism: every API call re-reads the entire conversation prefix. A
long-lived window therefore taxes *every subsequent call*, not just itself.
In one measured setup, a clean session cost ~120k cache-read tokens per call;
windows that had been alive for days cost 340-730k per call - a 3-6x
multiplier on everything done inside them. Two aggravators:

- **Compaction is lossy and expensive.** When the window fills, the harness
  summarizes it; the summary drops detail, and rebuilding the working context
  afterwards costs hundreds of thousands of write tokens per cycle.
- **Cache expiry punishes intermittent use.** Prompt cache TTL is finite
  (an hour-scale window). Returning to a fat session after an idle gap
  re-writes the full context. One measured window was returned to 17 times
  in a day; every return re-paid the whole prefix.

The fix is not discipline in the moment - it is **event-triggered rotation
criteria** that require zero monitoring (each signal is visible in the
conversation itself, so deciding costs nothing):

1. First compaction appears -> rotate as soon as the current atomic step
   completes. The first compaction is the last cheap warning, not the first.
2. The conversation is visibly huge (~100+ tool turns) -> rotate at the next
   natural stopping point, before compaction fires.
3. Returning to a fat window after a >1h gap -> do new work in a fresh
   window instead.
4. The session has crossed two midnights -> rotate (long windows also drift
   out of sync with reality; date-anchored mistakes were observed).
5. A milestone closes and the session is fat -> rotate at the natural break.

Rotation only works if the successor does not have to re-read the transcript:
write a **handover file** first (current state, next step, file map, red
lines, pending human decisions). And do not rotate thin sessions - a rotation
has a fixed cost (bootstrap + handover + re-reading), so rotating early loses
money. Symmetrically: do not *resume* a fat window to save a bootstrap; the
per-call multiplier eats the saving within a few calls.

## 4. Dispatch cost discipline

Rules for the orchestrator side, each anchored to a measured failure mode:

- **Full spec in the first message.** Goal, constraints, acceptance criteria,
  exact paths, known landmines - in one message. Drip-feeding a subagent pays
  the accumulated-context tax once per round trip.
- **Short legs.** A subagent re-pays its accumulated context on every call.
  The worst measured leg ran 2,600+ calls and 1.3B cache-read tokens - work
  that a script (or three shorter legs with intermediate files) would have
  done for a fraction. If a leg's loop is mechanical, move the loop into a
  script and let the agent call the script.
- **Read heavy payloads once.** A screenshot or a huge tool result stays in
  context forever after; every later call re-reads it. Look once, write down
  what you saw as text, and do not re-request it.
- **Intermediates go to disk, not the conversation.** Fan-out legs should
  write results to files and return paths plus a summary, not paste bulk
  content back into the orchestrator's window.
- **Tool errors are re-billed context.** An errored call costs the same
  context as a useful one. One measured day showed a 25% error rate on SQL
  calls - an agent discovering a schema by trial and error. Reading the
  schema once first (or caching it to a file) would have cut a third of that
  tool's spend. Watch per-tool error rates; they are efficiency bugs, not
  just reliability bugs.

## 5. What this buys, honestly

In the setup these numbers come from, the combined program - scoping rules
(`CONTEXT-COST.md`), rotating sessions, splitting marathon legs, routing
mechanical work to a cheap bucket (`SUBAGENT-ARCHITECTURE.md`), and keeping
payloads out of context - cut subagent bootstrap by ~75-80% and removed
multi-hundred-million-token days of pure prefix re-reading. All of it is
n=1 and workload-dependent. The only claim this document actually makes is
the method: **instrument, read the scorecard, fix the biggest verified line,
re-measure.** Skipping the last step is how the 0%-share fix above almost
shipped.
