#!/usr/bin/env bash
# verdict.sh [review-output-file]
#
# Parses a captured judge review, prints its VERDICT and SCORE, and exits:
#   0  -> PASS
#   1  -> FAIL
#   2  -> malformed / missing review file
# Fail-closed: a missing/unparsable VERDICT is treated as FAIL, and a claimed
# PASS is only trusted if its printed SCORE parses and meets the threshold
# (default 90%, override with GATES_MIN_PCT) - so "VERDICT: PASS" paired with a
# failing SCORE still exits FAIL.
#
# It also tracks a consecutive-FAIL streak in .gates/fail-streak and, after two
# FAILs in a row, prints an ESCALATE notice - per the governance contract, two
# consecutive bounces should go to a human owner rather than looping forever.
#
# The streak is a single global counter by default. For per-deliverable
# tracking, point each deliverable at its own state dir via GATES_STATE_DIR.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_DIR="${GATES_STATE_DIR:-$REPO_ROOT/.gates}"
FILE="${1:-$STATE_DIR/last-review.txt}"
STREAK="$STATE_DIR/fail-streak"
mkdir -p "$STATE_DIR"

# Validate the pass threshold up front so a bad env value fails loudly with a
# clear message rather than a cryptic arithmetic error deeper in the script.
min_pct="${GATES_MIN_PCT:-90}"
case "$min_pct" in ''|*[!0-9]*) echo "GATES_MIN_PCT must be an integer 1-100 (got: '$min_pct')" >&2; exit 2 ;; esac
{ [ "$min_pct" -ge 1 ] && [ "$min_pct" -le 100 ]; } || { echo "GATES_MIN_PCT must be an integer 1-100 (got: $min_pct)" >&2; exit 2; }

[ -f "$FILE" ] || { echo "no review output at $FILE"; exit 2; }

# Take the last VERDICT / SCORE token anywhere in the file (last token wins,
# regardless of position on the line; tolerant of any spacing after the colon).
verdict="$(grep -Eo 'VERDICT:[[:space:]]*(PASS|FAIL)' "$FILE" | tail -1 | grep -Eo 'PASS|FAIL')"
score="$(grep -Eo 'SCORE:[[:space:]]*[0-9]+/[0-9]+' "$FILE" | tail -1)"
frac="$(printf '%s' "$score" | grep -Eo '[0-9]+/[0-9]+' | tail -1)"

if [ -z "$verdict" ]; then
  echo "no parsable VERDICT line in $FILE - treating as FAIL (fail-closed)"
  verdict="FAIL"
fi

# Cross-check a claimed PASS against its own score. The rubric's threshold is a
# gate, not a suggestion: if the printed SCORE does not parse or does not meet
# min_pct, the PASS is not trusted and is flipped to FAIL (fail-closed).
if [ "$verdict" = "PASS" ]; then
  if [ -z "$frac" ]; then
    echo "PASS claimed but no parsable SCORE - fail-closed to FAIL"
    verdict="FAIL"
  else
    snum=$((10#${frac%/*})); sden=$((10#${frac#*/}))
    if [ "$sden" -le 0 ] || [ $(( snum * 100 )) -lt $(( sden * 10#$min_pct )) ]; then
      echo "PASS claimed but SCORE $frac is below the ${min_pct}% threshold - fail-closed to FAIL"
      verdict="FAIL"
    fi
  fi
fi

echo "VERDICT: $verdict${score:+  ($score)}"

if [ "$verdict" = "PASS" ]; then
  : > "$STREAK"   # reset the streak on a pass
  exit 0
fi

# FAIL path - increment the consecutive-FAIL streak.
n=0; [ -f "$STREAK" ] && n="$(cat "$STREAK" 2>/dev/null || echo 0)"
case "$n" in ''|*[!0-9]*) n=0 ;; esac
n=$((n+1)); echo "$n" > "$STREAK"

if [ "$n" -ge 2 ]; then
  echo "ESCALATE: $n consecutive FAILs on this gate - hand to a human owner (see docs/GOVERNANCE.md, escalation contract)."
fi
exit 1
