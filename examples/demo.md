# Worked example: build -> gate -> bounce -> fix -> PASS

This walks the full loop on a small, real change: a `page_count` function. It shows
the gate doing the one thing self-graded work cannot - bouncing a green self-report.

You can follow along against the golden fixture at
`eval/golden/qa-gate/gt1-planted-bug/`, which is exactly the "before" state below.

---

## 1. Build

The goal: `page_count(total_items, per_page)` returns how many pages are needed,
**counting the final partial page** (10 items at 3 per page -> 4 pages), and raising
`ValueError` on a non-positive `per_page`.

The builder ships:

```python
def page_count(total_items: int, per_page: int) -> int:
    if per_page <= 0:
        raise ValueError("per_page must be positive")
    return total_items // per_page
```

...with tests, and this handoff:

> **Deliverable** - `pager.py`, `test_pager.py`.
> **Verified** - "pytest 4/4 green, including the boundary cases; verified."
> **Risks** - none noted.
> **Next** - ready for the gate.

The tests really are green. They cover `9/3 -> 3`, `6/3 -> 2`, `0 items`, and the
`ValueError` path. Every one passes.

## 2. Gate

```bash
scripts/review.sh eval/golden/qa-gate/gt1-planted-bug \
  "implement page_count; the final partial page must be counted"
```

The gate does not trust "4/4 green". It reads the spec, notices the tests only cover
exact multiples, and constructs the case they miss: `page_count(10, 3)`. Integer
division returns `3`; the spec requires `4`. The partial page is silently dropped -
a classic off-by-one from using floor division where the goal needs a ceiling.

Its scorecard, abbreviated (this is a real, lightly trimmed run; the exact
sub-scores vary from run to run, but the FAIL verdict and the off-by-one finding
are the stable part):

```
correctness   0  - page_count(10, 3) returns 3, spec's own example requires 4
completeness  1  - the "final partial page" clause of the goal is silently absent
robustness    1  - guard on per_page works; every remainder case is wrong
clarity       3  - readable, but the docstring's example contradicts the code
verification  1  - tests run green (I reran: 4/4) but encode only exact multiples;
                   the "boundary cases covered" self-report did not hold up

VERDICT: FAIL
SCORE: 6/20
```

`verdict.sh` sees `VERDICT: FAIL` and exits `1`. In CI, the step fails here.

## 3. Bounce

Because `correctness` is not `4` and the total is below threshold, this is a
mandatory bounce, not a discussion. The gate's `Next` field is specific:

> Fix `page_count` to count the final partial page (ceiling division, e.g.
> `-(-total_items // per_page)` or `math.ceil`). Add a test for a non-multiple such
> as `page_count(10, 3) == 4` so the regression is captured.

## 4. Fix

The builder applies exactly that:

```python
import math

def page_count(total_items: int, per_page: int) -> int:
    if per_page <= 0:
        raise ValueError("per_page must be positive")
    return math.ceil(total_items / per_page)
```

...and adds `test_partial_page(): assert page_count(10, 3) == 4`.

## 5. Gate again -> PASS

Re-run the same command. The gate reproduces the tests (now 5/5, including the
remainder case), re-runs its own `10/3` and `1/3` break-attempts, and finds no
unhandled failure:

```
correctness   4  - matches the spec on multiples, non-multiples, and the error path
completeness  4  - the partial-page clause is implemented
robustness    4  - remainder and boundary cases covered, error path raises
clarity       4  - clear intent via math.ceil
verification  4  - independently reproduced; the regression test locks in the fix

VERDICT: PASS
SCORE: 20/20
```

`verdict.sh` exits `0`. The change ships.

---

The point: the defect was invisible to the builder's own green tests, and would
have shipped under a self-review. An independent gate with the burden of proof on
the deliverable - reproducing the spec rather than trusting the self-report - is
what caught it. That is the whole idea of the kit.
