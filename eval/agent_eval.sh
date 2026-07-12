#!/usr/bin/env bash
# agent_eval.sh <agent> - a lean regression harness for judgment agents.
#
# Treat an agent's prompt as production code. For each golden task under
# eval/golden/<agent>/<task>/ this runs `claude -p --agent <agent>` on task.md,
# applies the grep assertions in assert.txt, writes the output + per-task score
# to eval/runs/<ts>-<agent>/, and appends a score line to
# eval/baselines/<agent>.tsv (commit that file - it is your score history).
#
# Discipline: run this BEFORE you edit a judgment agent to capture a baseline,
# and AFTER to compare. A drop in the total blocks the change - an eval that
# never gates a ship is decoration. For changes to the judgment core (the
# rubric, the pass threshold, severity logic), run twice and require the
# verdict-level assertions to hit both times (pass^2), since a single lucky
# run can mask a regression.
#
# Usage:   bash eval/agent_eval.sh qa-gate
#          bash eval/agent_eval.sh critic
#
# assert.txt line format:  MUST:<extended-regex>   |   MUST_NOT:<extended-regex>
# A pattern that mentions "VERDICT:" is matched against the review's extracted
# final verdict token (last `VERDICT: PASS|FAIL`, as verdict.sh parses it), not
# the raw transcript - so a judge quoting the assertion text cannot false-match.
#
# Permissions: by default the judge runs with an allowlist of only the
# read/verify tools it needs, so a headless run never bypasses permission
# checks wholesale. For non-interactive convenience you may opt in to a blanket
# bypass with GATES_YOLO=1 - you accept the risk of running an agent unattended
# with checks off.
set -uo pipefail

AGENT="${1:?usage: agent_eval.sh <agent>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EVAL_DIR="$SCRIPT_DIR"
GOLD="$EVAL_DIR/golden/$AGENT"
TS="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$EVAL_DIR/runs/$TS-$AGENT"
BASE="$EVAL_DIR/baselines/$AGENT.tsv"
CLAUDE_BIN="${GATES_CLAUDE_BIN:-$(command -v claude || true)}"

[ -n "$CLAUDE_BIN" ] || { echo "claude CLI not found on PATH (set GATES_CLAUDE_BIN)"; exit 1; }
[ -d "$GOLD" ] || { echo "no golden tasks at $GOLD"; exit 1; }
mkdir -p "$RUN_DIR" "$EVAL_DIR/baselines"

# --allowedTools is a variadic option; feed the task on stdin rather than as a
# trailing argument, otherwise it would swallow the prompt.
CLAUDE_ARGS=(-p --agent "$AGENT" --allowedTools "Bash Read Grep Glob WebSearch WebFetch")
[ "${GATES_YOLO:-0}" = "1" ] && CLAUDE_ARGS+=(--permission-mode bypassPermissions)

# Evaluate one assertion pattern. An assertion whose pattern mentions "VERDICT:"
# is a decision-level assertion: it is matched against the review's extracted
# final verdict token (the last `VERDICT: PASS|FAIL`, exactly as verdict.sh
# parses it), NOT the raw transcript. This stops a false match when the judge
# quotes the assertion text in its prose. All other patterns match the whole
# transcript. Sets global $vtok per task before use.
assertion_matches() {  # <pattern> -> 0 if the pattern is found in the chosen corpus
  case "$1" in
    *VERDICT:*) printf '%s\n' "$vtok" | grep -qE "$1" ;;
    *)          grep -qE "$1" "$out" ;;
  esac
}

total_pass=0; total_asserts=0; summary=""
for tdir in "$GOLD"/*/; do
  task="$(basename "$tdir")"
  [ -f "$tdir/task.md" ] || continue
  out="$RUN_DIR/$task.out"
  ( cd "$REPO_ROOT" && "$CLAUDE_BIN" "${CLAUDE_ARGS[@]}" ) \
    <"$tdir/task.md" >"$out" 2>"$RUN_DIR/$task.err"
  rc=$?
  vtok="$(grep -Eo 'VERDICT:[[:space:]]*(PASS|FAIL)' "$out" | tail -1)"
  t_pass=0; t_total=0; fails=""
  while IFS= read -r line; do
    case "$line" in
      MUST:*)     t_total=$((t_total+1)); pat="${line#MUST:}"
                  if assertion_matches "$pat"; then t_pass=$((t_pass+1)); else fails+=" [miss:$pat]"; fi ;;
      MUST_NOT:*) t_total=$((t_total+1)); pat="${line#MUST_NOT:}"
                  if assertion_matches "$pat"; then fails+=" [hit-forbidden:$pat]"; else t_pass=$((t_pass+1)); fi ;;
    esac
  done < "$tdir/assert.txt"
  total_pass=$((total_pass+t_pass)); total_asserts=$((total_asserts+t_total))
  summary+="$task: $t_pass/$t_total rc=$rc$fails"$'\n'
done

score="$total_pass/$total_asserts"
printf '%s\n' "$summary"
echo "TOTAL $AGENT: $score"
# Record a repo-relative run path in the committed score history (no absolute
# local paths leak into git).
printf '%s\t%s\t%s\n' "$TS" "$score" "eval/runs/$TS-$AGENT" >> "$BASE"
echo "history: $BASE"
tail -3 "$BASE"
