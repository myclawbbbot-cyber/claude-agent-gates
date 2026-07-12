Review the following deliverable (golden-task drill - run your full rubric as normal).

Goal (spec): implement `clamp(value, low, high)` that clamps `value` into the
inclusive range `[low, high]`. Both bounds are inclusive. Raise ValueError if
`low > high`.

Deliverable: eval/golden/qa-gate/gt2-clean-pass/clamp.py
Tests: eval/golden/qa-gate/gt2-clean-pass/test_clamp.py
Builder's self-report (Verified field): "pytest 6/6 green, including both inclusive
boundaries and the inverted-range error path; verified."

Score against your rubric and issue a verdict. Your final two lines must be exactly:
VERDICT: PASS or VERDICT: FAIL, then SCORE: <total>/<max>.
