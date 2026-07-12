#!/usr/bin/env bash
# verdict_test.sh - self-test battery for verdict.sh.
#
# Crafts synthetic judge outputs and asserts verdict.sh's exit code and key
# messages for each case: a clean PASS, a FAIL, the consecutive-FAIL streak that
# escalates, a PASS that resets the streak, the fail-closed cases (a PASS with a
# failing or missing SCORE, malformed output), last-VERDICT-token-wins parsing,
# an exactly-at-threshold PASS, and a missing file.
#
# Exits 0 if every case passes, 1 otherwise. Run: bash scripts/verdict_test.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERDICT="$SCRIPT_DIR/verdict.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
# run <name> <expected-exit> <state-subdir> <needle|-|!needle> <fixture-file> [env]
#   needle   : output MUST match this extended-regex
#   !needle  : output MUST NOT match this extended-regex
#   -        : no output assertion, exit code only
#   env      : optional single VAR=value to set for this run (e.g. GATES_MIN_PCT=50)
run() {
  local name="$1" want="$2" sd="$3" needle="$4" file="$5" env6="${6:-}" out rc ok=1
  if [ -n "$env6" ]; then
    out="$(env "$env6" GATES_STATE_DIR="$TMP/$sd" bash "$VERDICT" "$file" 2>&1)"; rc=$?
  else
    out="$(GATES_STATE_DIR="$TMP/$sd" bash "$VERDICT" "$file" 2>&1)"; rc=$?
  fi
  [ "$rc" = "$want" ] || ok=0
  case "$needle" in
    -)    : ;;
    '!'*) printf '%s' "$out" | grep -qE "${needle#!}" && ok=0 ;;
    *)    printf '%s' "$out" | grep -qE "$needle" || ok=0 ;;
  esac
  if [ "$ok" = 1 ]; then pass=$((pass+1)); printf 'ok   %-30s (exit %s)\n' "$name" "$rc"
  else fail=$((fail+1)); printf 'FAIL %-30s (exit %s, want %s)\n     output: %s\n' "$name" "$rc" "$want" "$out"; fi
}

printf 'scorecard...\nVERDICT: PASS\nSCORE: 20/20\n'                 > "$TMP/pass.txt"
printf 'scorecard...\nVERDICT: FAIL\nSCORE: 6/20\n'                  > "$TMP/fail.txt"
printf 'VERDICT: PASS\nSCORE: 18/20\n'                               > "$TMP/pass_90.txt"
printf 'VERDICT: PASS\nSCORE: 2/20\n'                                > "$TMP/pass_low.txt"
printf 'VERDICT: PASS\n(no score line here)\n'                       > "$TMP/pass_noscore.txt"
printf 'the judge crashed; no verdict here\n'                        > "$TMP/malformed.txt"
printf 'early VERDICT: PASS ... but the real VERDICT: FAIL\nSCORE: 10/20\n' > "$TMP/last_wins.txt"
printf 'VERDICT: PASS\nSCORE: 12/20\n'                               > "$TMP/pass_60.txt"

# Streak cases share one state dir (s1) to exercise the counter.
run "FAIL #1 (streak 1)"          1 s1 -                          "$TMP/fail.txt"
run "FAIL #2 -> ESCALATE"         1 s1 'ESCALATE'                 "$TMP/fail.txt"
run "PASS resets streak"          0 s1 'VERDICT: PASS'            "$TMP/pass.txt"
run "FAIL after reset (no esc)"   1 s1 '!ESCALATE'                "$TMP/fail.txt"
# Independent cases, each in a fresh state dir.
run "clean PASS"                  0 s2 'VERDICT: PASS'            "$TMP/pass.txt"
run "PASS exactly at 90%"         0 s3 'VERDICT: PASS'            "$TMP/pass_90.txt"
run "PASS + low score -> FAIL"    1 s4 'below the 90% threshold'  "$TMP/pass_low.txt"
run "PASS + no score -> FAIL"     1 s5 'no parsable SCORE'        "$TMP/pass_noscore.txt"
run "malformed -> FAIL"           1 s6 'fail-closed'              "$TMP/malformed.txt"
run "last VERDICT token wins"     1 s7 'VERDICT: FAIL'            "$TMP/last_wins.txt"
run "missing file -> exit 2"      2 s8 'no review output'         "$TMP/does_not_exist.txt"
run "GATES_MIN_PCT=abc -> exit 2" 2 s9 'GATES_MIN_PCT'            "$TMP/pass.txt"    "GATES_MIN_PCT=abc"
run "GATES_MIN_PCT=50 accepts 60%" 0 s10 'VERDICT: PASS'         "$TMP/pass_60.txt" "GATES_MIN_PCT=50"

echo
echo "verdict_test: $pass passed, $fail failed"
[ "$fail" = 0 ]
