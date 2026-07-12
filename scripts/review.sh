#!/usr/bin/env bash
# review.sh <target> ["goal / spec text"]
#
# Runs the quality gate (the qa-gate agent by default) against a target - a
# directory, a file, or a saved diff - plus the goal it was meant to satisfy.
# Captures the scorecard to .gates/last-review.txt and exits with the verdict's
# status (0 = PASS, 1 = FAIL) by delegating to verdict.sh, so CI can gate on it:
#
#     scripts/review.sh ./src "implement page_count per the spec" || exit 1
#
# Override the judge with GATES_REVIEW_AGENT=<agent-name> (e.g. a stricter or a
# cross-family gate). By default the judge runs with an allowlist of only the
# read/verify tools it needs; opt in to a blanket bypass with GATES_YOLO=1 (you
# accept the risk of running unattended with permission checks off).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET="${1:?usage: review.sh <target-path-or-diff> [\"goal text\"]}"
GOAL="${2:-}"
AGENT="${GATES_REVIEW_AGENT:-qa-gate}"
STATE_DIR="${GATES_STATE_DIR:-$REPO_ROOT/.gates}"
CLAUDE_BIN="${GATES_CLAUDE_BIN:-$(command -v claude || true)}"
OUT="$STATE_DIR/last-review.txt"

[ -n "$CLAUDE_BIN" ] || { echo "claude CLI not found on PATH (set GATES_CLAUDE_BIN)"; exit 2; }
[ -e "$TARGET" ] || { echo "target not found: $TARGET"; exit 2; }
mkdir -p "$STATE_DIR"

PROMPT="$(cat <<EOF
Review the deliverable at: $TARGET
Goal it must satisfy: ${GOAL:-(no explicit goal supplied - infer it from the target and judge against it)}

Run your full rubric. Verify independently - do not trust any self-report.
Your final two lines must be exactly:
VERDICT: PASS or VERDICT: FAIL, then SCORE: <total>/<max>.
EOF
)"

# The prompt is fed on stdin, not as a trailing argument: --allowedTools is a
# variadic option and would otherwise swallow a trailing positional prompt.
CLAUDE_ARGS=(-p --agent "$AGENT" --allowedTools "Bash Read Grep Glob")
[ "${GATES_YOLO:-0}" = "1" ] && CLAUDE_ARGS+=(--permission-mode bypassPermissions)

printf '%s' "$PROMPT" | ( cd "$REPO_ROOT" && "$CLAUDE_BIN" "${CLAUDE_ARGS[@]}" ) | tee "$OUT"

exec "$SCRIPT_DIR/verdict.sh" "$OUT"
