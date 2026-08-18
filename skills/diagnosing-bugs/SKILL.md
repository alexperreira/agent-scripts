---
name: diagnosing-bugs
description: >
  Disciplined six-phase diagnosis loop for hard bugs, intermittent flakes, and performance
  regressions — build a feedback loop that goes red on this bug, minimise, hypothesise,
  instrument, fix, regression-test. Use this skill whenever Alex says "diagnose this", "debug
  this", "why is this happening", "this works locally but not in prod", "this is flaky", "this
  got slow", or pastes a stack trace, error message, or failing output. Also trigger proactively
  the moment a bug resists a first-pass fix, or when the agent catches itself reading code to
  build a theory before it has a command that reproduces the failure — that is the exact failure
  mode this skill exists to prevent. For a bug that is one obvious typo, skip this and just fix
  it; this is for the ones that fight back.
---

# Diagnosing Bugs

A discipline for hard bugs. The phases are gated: skip one only with an explicit, stated reason.

The core claim: **if you have a tight pass/fail signal that goes red on this specific bug, you
will find the cause.** Bisection, hypothesis testing, and instrumentation all just consume that
signal. Without it, no amount of reading code will save you — it will only produce confident,
wrong theories.

---

## Redact first

This skill has you show commands, outputs, and captured artifacts. **Redact every secret before
showing anything** — write `<REDACTED>` in its place.

- Build loops against environment variables so credentials stay in the environment rather than
  in the command you paste back.
- Captured artifacts (HAR files, request dumps, logs) carry auth headers and tokens. Quote only
  the lines that carry the signal.
- If the redacted output is genuinely not enough to diagnose the bug, say so and ask Alex rather
  than pasting the unredacted version.

---

## Phase 1 — Build a feedback loop

**This phase is the skill.** Everything after it is mechanical.

Spend disproportionate effort here. Be aggressive, be creative, and refuse to give up. The
temptation to skip ahead to "I bet it's the cache" is the thing that costs hours.

### Ways to construct one — try roughly in this order

1. **Failing test** at whatever seam reaches the bug — unit, integration, e2e.
2. **curl / HTTP script** against a running dev server.
3. **CLI invocation** with a fixture input, diffing stdout against a known-good snapshot.
4. **Headless browser script** (Playwright / Puppeteer) driving the UI, asserting on DOM,
   console, or network.
5. **Replay a captured trace.** Save a real request, payload, or event log to disk and replay it
   through the code path in isolation.
6. **Throwaway harness.** A minimal subset of the system — one service, mocked dependencies —
   that hits the bug code path in a single function call.
7. **Property / fuzz loop.** For "sometimes wrong output": run 1,000 random inputs and look for
   the failure mode.
8. **Bisection harness.** If the bug appeared between two known-good states (commit, dataset,
   dependency version), automate "boot at state X, check, repeat" so `git bisect run` can drive it.
9. **Differential loop.** Same input through old vs. new version, or two configs, diffing outputs.
10. **Human-in-the-loop script.** Last resort, when a human genuinely must click. Drive *them*
    with `scripts/hitl-loop.template.sh` so the loop stays structured and its output feeds back
    to the agent.

### Tighten the loop

Treat the loop as a product. Once you have *a* loop, make it better:

- **Faster** — cache setup, skip unrelated init, narrow the test scope.
- **Sharper** — assert on the specific symptom, not "didn't crash".
- **More deterministic** — pin time, seed RNG, isolate the filesystem, freeze the network.

A 30-second flaky loop is barely better than no loop. A 2-second deterministic one is a
superpower.

### Non-deterministic bugs

The goal is not a clean repro but a **higher reproduction rate**. Loop the trigger 100×,
parallelise, add stress, narrow timing windows, inject sleeps. A 50%-flake bug is debuggable;
a 1% one is not — keep raising the rate until it is.

### When you genuinely cannot build a loop

Stop and say so explicitly. List what was tried. Then ask Alex for one of:

- access to an environment where it reproduces,
- a redacted captured artifact (HAR, log dump, core dump, screen recording with timestamps),
- permission to add temporary production instrumentation.

**Do not proceed to hypothesise without a loop.**

### Completion criterion — a tight loop that goes red

Phase 1 is done when you can name **one command** — a script path, a test invocation, a curl —
that you have **already run at least once** (show the invocation and its redacted output), and
that is:

- [ ] **Red-capable** — it drives the actual bug code path and asserts the **user's exact
      symptom**, so it goes red on this bug and green once fixed. Not "runs without erroring".
- [ ] **Deterministic** — same verdict every run. For flaky bugs, a pinned and high reproduction
      rate.
- [ ] **Fast** — seconds, not minutes.
- [ ] **Agent-runnable** — runnable unattended; a human in the loop only via the HITL template.

> If you catch yourself reading code to build a theory before this command exists — **stop.**
> Jumping straight to a hypothesis is the exact failure this skill prevents. No red-capable
> command, no Phase 2.

---

## Phase 2 — Reproduce and minimise

Run the loop. Watch it go red.

Confirm all three:

- [ ] The loop produces the failure mode **Alex described** — not a different failure that
      happens to live nearby. Wrong bug means wrong fix.
- [ ] The failure reproduces across multiple runs (or at a high enough rate, for flaky bugs).
- [ ] The exact symptom is captured — error message, wrong output, timing number — so later
      phases can verify the fix actually addresses it.

### Minimise

Once it is red, shrink the repro to the **smallest scenario that still goes red**. Cut inputs,
callers, config, data, and steps **one at a time**, re-running the loop after each cut. Keep only
what is load-bearing.

Why bother: a minimal repro shrinks the hypothesis space in Phase 3, and becomes the clean
regression test in Phase 5.

Done when **every remaining element is load-bearing** — removing any one of them turns the loop
green.

Do not proceed until you have reproduced **and** minimised.

---

## Phase 3 — Hypothesise

Generate **3–5 ranked hypotheses before testing any of them.** Generating one at a time anchors
you on the first plausible idea, which is how debugging sessions lose an afternoon.

Each hypothesis must be **falsifiable** — state the prediction it makes:

> "If `<X>` is the cause, then `<changing Y>` makes the bug disappear / `<changing Z>` makes it
> worse."

If you cannot state the prediction, the hypothesis is a vibe. Discard it or sharpen it.

**Show the ranked list to Alex before testing.** He often has context that re-ranks instantly
("we deployed a change to #3 on Tuesday") or has already ruled one out. Cheap checkpoint, big
saving. Don't block on it — proceed with your own ranking if he's away.

---

## Phase 4 — Instrument

Each probe maps to a specific prediction from Phase 3. **Change one variable at a time.**

Tool preference, in order:

1. **Debugger or REPL inspection** where the environment supports it. One breakpoint beats ten
   log lines.
2. **Targeted logs** at the boundaries that distinguish competing hypotheses.
3. Never "log everything and grep".

**Tag every debug log with a unique prefix** — `[DEBUG-a4f2]`. Cleanup at the end becomes a
single grep. Untagged debug logs survive into production; tagged ones die.

**Performance branch.** For a performance regression, logs are usually the wrong instrument.
Establish a baseline measurement first, then bisect against it — measure first, fix second. Use
the `performance-profiling-protocol` skill for the measurement methodology rather than
improvising one here; this skill owns the diagnosis loop, that one owns the profiling.

---

## Phase 5 — Fix and regression-test

Write the regression test **before the fix** — but only if a **correct seam** exists for it.

A correct seam is one where the test exercises the **real bug pattern as it occurs at the call
site**. If the only available seam is too shallow — a single-caller unit test when the bug needs
multiple callers, a test that can't replicate the chain that triggered it — a regression test
there gives false confidence, which is worse than none.

**If no correct seam exists, that is itself the finding.** Record it. The architecture is
preventing the bug from being locked down, and that is a real result to carry into Phase 6.

If a correct seam exists:

1. Turn the minimised repro into a failing test at that seam.
2. Watch it fail.
3. Apply the fix.
4. Watch it pass.
5. Re-run the Phase 1 loop against the **original, un-minimised** scenario.

Step 5 is not optional. A fix that satisfies the minimised repro but not the original scenario
means the minimisation cut something load-bearing.

---

## Phase 6 — Cleanup and post-mortem

Required before declaring done:

- [ ] Original repro no longer reproduces (re-run the Phase 1 loop)
- [ ] Regression test passes, or the absence of a correct seam is documented
- [ ] All `[DEBUG-...]` instrumentation removed — grep the prefix to confirm
- [ ] Throwaway harnesses deleted, or moved to a clearly-marked debug location
- [ ] The hypothesis that turned out correct is stated in the commit or PR message, so the next
      person debugging this area learns from it

**Then ask: what would have prevented this bug?**

Make this recommendation **after** the fix is in, not before — you know far more now than you did
at the start. Route it by what the answer turns out to be:

- **It was a production incident with user impact** → hand off to `incident-postmortem` for the
  full blameless write-up, timeline, and action items. This skill's findings are that
  document's root-cause section.
- **The real finding is architectural** — no good test seam, tangled callers, hidden coupling →
  say so explicitly with specifics, and open it as its own piece of work rather than folding it
  into this fix.
- **It was a class of bug, not an instance** — missing input validation, an unguarded trust
  boundary, an unsafe schema change → point at the relevant skill (`input-validation-sanitization`,
  `auth-authorization-audit`, `db-migration-safety`, `secure-error-handling`) and note that the
  same bug likely exists elsewhere.
- **It was a one-off** → say that plainly. Not every bug has a lesson, and inventing one wastes
  the next reader's time.
