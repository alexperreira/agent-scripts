---
name: code-review-checklist
description: >
  Two-axis code review — Standards (correctness, edge cases, error handling, security, test
  coverage, naming, and a Fowler smell baseline) and Spec (does the diff faithfully implement
  what the task doc actually asked for?) — run as parallel subagents and reported side by side.
  Use this skill whenever Alex asks to "review this code", "check this PR", "look over this
  implementation", "does this look right", "review since main", or pastes code for feedback.
  Also trigger proactively when Claude Code produces an implementation and Alex wants a second
  pass before merging, or when a task doc has been executed and the output needs validation
  against acceptance criteria. Goes beyond surface-level style feedback — focuses on what will
  actually break in production, what's missing, and what's subtly wrong.
---

# Code Review Checklist

A structured review lens for evaluating code changes, run along **two independent axes**:

- **Standards** — is this good code? Correctness, edge cases, error handling, security, test
  coverage, naming, and a baseline of code smells.
- **Spec** — is this the *right* code? Does the diff faithfully implement what the originating
  task doc or issue actually asked for?

Good code review is not proofreading. The goal is to find what will break in production, what
the author assumed that isn't guaranteed, and what's missing — not to enforce style preferences
or rewrite working code.

---

## Why two axes

A change can pass one axis and fail the other, and each masks the other when they're merged into
one list:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the task doc asked but breaks conventions and leaks secrets in the
  error path → **Spec pass, Standards fail.**

The second case is the one a single-list review reliably gets wrong: a diff with eight clean
🔵 Consider findings *reads* like a healthy review, and the fact that it built the wrong feature
never surfaces because nobody was looking for it.

**Run them separately. Report them separately. Never merge or re-rank findings across axes.**

---

## Core Principles

1. **Find what breaks, not what you'd do differently.** Style and preference comments are low
   value. Focus on correctness, safety, and maintainability issues that will cause real problems.

2. **Classify findings by severity.** Not all issues are equal. A missing null check on a
   critical path is not the same as a variable name that could be clearer. Always label severity.

3. **Explain the failure mode, not just the problem.** "This could throw" is less useful than
   "This throws a TypeError if `user` is null, which happens when the session expires mid-request."

4. **Praise what's right.** If something is well-designed, say so. It anchors good patterns and
   makes critical feedback easier to receive.

5. **Don't block on nits.** Nitpicks (naming, minor style) should never block a merge. Label
   them clearly so the author can decide.

---

## Severity Labels

Use these consistently across both axes:

| Label | Meaning |
|---|---|
| 🔴 **Blocking** | Will cause bugs, data loss, security issues, or crashes in production. Must fix before merge. |
| 🟡 **Should Fix** | Likely to cause problems under realistic conditions. Strong recommendation to fix before merge. |
| 🔵 **Consider** | Worth addressing but not urgent. Can be a follow-up task. |
| ⚪ **Nit** | Minor style or naming. Non-blocking. Author's call. |

---

# Process

## Step 1 — Pin the fixed point

A review needs a defined diff. Whatever Alex named is the fixed point — a commit SHA, a branch
name, a tag, `main`, `HEAD~5`.

If he didn't name one, ask. Don't guess: reviewing the wrong range wastes both subagents.

Capture the diff command once:

```bash
git diff <fixed-point>...HEAD     # three-dot: compares against the merge-base
git log <fixed-point>..HEAD --oneline
```

**Verify before dispatching.** Confirm the ref resolves (`git rev-parse <fixed-point>`) and the
diff is non-empty. A bad ref or an empty diff should fail here, in one place — not twice, inside
two parallel subagents.

If Alex pasted code directly rather than pointing at a branch, the pasted code *is* the diff.
Skip the git commands and carry on.

## Step 2 — Identify the spec source

Look for what this change was supposed to do, in this order:

1. **A task doc** — the output of `task-doc-generator` is the canonical spec source. Look under
   the project's task doc directory for one matching the branch name or feature.
2. **Issue references in commit messages** — `#123`, `Closes #45`.
3. **A path Alex passed as an argument.**
4. **A spec or ADR** under `docs/` matching the feature. An ADR isn't a spec, but if the change
   contradicts one, that's a Spec-axis finding.
5. **Ask.** If nothing is found, ask Alex where the spec is.

If he says there isn't one, **skip the Spec subagent and say so explicitly in the report.** A
review with no Spec axis is half a review, and the report should be honest about which half ran.

## Step 3 — Dispatch both subagents in parallel

Run them concurrently so neither pollutes the other's context. The Standards agent must not know
what the spec said — otherwise it starts rationalising smells as "well, the spec asked for it."
The Spec agent must not know about the smells — otherwise scope creep gets buried under nits.

**Standards subagent** — give it:
- the diff command and commit list,
- the full text of Review Lenses 1–6 and the Smell Baseline below (it has no other access to them),
- the brief: *"Apply every lens and the smell baseline to this diff. For each finding give:
  location, what's wrong, the concrete failure mode, a suggested fix, and a severity label.
  Distinguish hard violations from judgement calls — smells are always judgement calls. Skip
  anything linting or type-checking already enforces. Report findings only; do not summarise the
  change."*

**Spec subagent** — give it:
- the diff command and commit list,
- the full text or path of the spec,
- the brief: *"Compare this diff against the spec. Report (a) requirements the spec asked for
  that are missing or only partially implemented; (b) behaviour in the diff that the spec never
  asked for — scope creep; (c) requirements that look implemented but where the implementation
  doesn't actually satisfy what was asked. Quote the specific spec line or acceptance criterion
  for every finding. Severity-label each. Report findings only."*

## Step 4 — Aggregate without merging

Present both reports under their own headings. Light cleanup is fine. **Do not merge the two
lists, and do not re-rank findings across axes** — that reranking is exactly what the separation
exists to prevent.

End with one line per axis: the count of findings and the worst issue *within that axis*. Don't
pick a single winner across axes.

---

# Axis A — Standards

## Review Lens 1: Correctness

The implementation must do what it claims to do, under all realistic inputs.

**Questions to ask:**
- Does the logic match the stated intent? Are there off-by-one errors, wrong operators, inverted
  conditions?
- Are all code paths covered? Does every branch reach a valid return or throw?
- Are comparisons using the right equality semantics? (`===` vs `==`, reference vs value, etc.)
- Are mutations happening where they shouldn't be? (Shared state, unexpected side effects)
- Are async operations handled correctly? Missing `await`, unhandled promise rejections,
  race conditions between concurrent operations?
- Does the implementation match the acceptance criteria in the task doc?

**Common failure modes:**
```ts
// ❌ Off-by-one: excludes the last element
for (let i = 0; i < items.length - 1; i++) { ... }

// ❌ Missing await: function returns before async work completes
function saveUser(data) {
  db.users.create(data); // fire-and-forget — caller gets undefined
  return { ok: true };
}

// ❌ Mutation of input: caller's array is modified unexpectedly
function addItem(list, item) {
  list.push(item); // mutates caller's reference
  return list;
}
```

---

## Review Lens 2: Edge Cases & Boundary Conditions

The implementation must handle inputs at the edges of what's possible, not just the happy path.

**Questions to ask:**
- What happens with an empty array, empty string, or zero?
- What happens with a null or undefined input where the code assumes a value?
- What happens at numeric boundaries (0, negative numbers, MAX_INT)?
- What happens when a list has exactly one item vs. many items?
- What happens if an external call (DB, API, file system) returns nothing, errors, or takes too long?
- What happens on the first call ever (no prior state, empty DB)?
- What happens if this function is called twice concurrently?

**Common failure modes:**
```ts
// ❌ Crashes on empty array
const first = items[0].id; // TypeError if items is []

// ❌ NaN propagation
const ratio = completed / total; // NaN if total === 0, silently corrupts downstream calcs

// ❌ Assumes at least one result
const user = await db.users.findFirst({ where: { email } });
return user.id; // TypeError if no user found
```

---

## Review Lens 3: Error Handling

Errors must be caught at the right level, surfaced with enough context to debug, and never
silently swallowed.

**Questions to ask:**
- Are all failure modes caught? Are there uncaught promise rejections or unhandled exceptions?
- Are errors logged with enough context to diagnose in production? (Request ID, user ID,
  input that caused the failure)
- Are errors re-thrown at the right level, or swallowed at the wrong one?
- Does the error response to the client match the API error envelope? (No raw stack traces,
  no DB error strings, correct HTTP status)
- Are retryable errors handled differently from permanent errors?
- Is the error handling itself correct? (Catching `Error` base class vs. specific types)

**Common failure modes:**
```ts
// ❌ Swallowed error — caller never knows it failed
try {
  await sendEmail(user.email, content);
} catch (e) {
  console.log('email failed'); // logged but not re-thrown, not surfaced to caller
}

// ❌ Exposes internals in error response
res.status(500).json({ error: e.message }); // may leak DB connection string, file path, etc.

// ❌ Catches too broadly, hides real bugs
try {
  return processOrder(data);
} catch (e) {
  return null; // TypeError from a bug in processOrder is now indistinguishable from "not found"
}
```

---

## Review Lens 4: Security

Every trust boundary must be explicitly defended. Never assume input is safe.

**Questions to ask:**
- Is all external input validated before use? (Request body, query params, file uploads,
  webhook payloads, environment variables read at runtime)
- Are authorization checks performed before any data access or mutation? Is it possible to
  access another user's data by changing an ID in the request?
- Are there any SQL injections, command injections, or template injections possible?
- Are secrets handled correctly? No hardcoded credentials, no secrets in logs, no secrets
  in error responses or URLs
- Are file paths constructed from user input? (Path traversal risk)
- Are there timing-safe comparisons where needed? (Token and signature verification)
- Does this introduce any new attack surface that isn't covered by existing auth middleware?

**Common failure modes:**
```ts
// ❌ IDOR — no ownership check
const record = await db.documents.findUnique({ where: { id: req.params.id } });
return record; // returns any user's document if they guess the ID

// ❌ Path traversal
const file = fs.readFileSync(`./uploads/${req.query.filename}`);
// filename = "../../.env" reads secrets

// ❌ Secret in log
logger.info('Calling Stripe', { apiKey: process.env.STRIPE_KEY });
```

---

## Review Lens 5: Test Coverage

Tests must cover what matters. Missing tests on critical paths are a 🔴 Blocking finding.

**Questions to ask:**
- Is the happy path tested?
- Are the edge cases identified in Lens 2 tested?
- Are error conditions tested — not just that an error is thrown, but that the right error
  is thrown with the right message/code?
- Are tests isolated? Do they depend on external state (DB, network, filesystem) when they
  shouldn't?
- Are tests testing behavior, not implementation? (Tests that assert on internal state or
  mock count are brittle)
- If this is a bug fix, is there a regression test that would have caught the original bug?

**Common failure modes:**
- Happy path only, no error or edge case coverage
- Tests that pass because they don't actually assert on the right thing
  (`expect(result).toBeDefined()` instead of `expect(result.id).toBe('usr_abc')`)
- **Tautological tests** — the assertion recomputes the expected value the same way the code
  does (`expect(add(a, b)).toBe(a + b)`, or a snapshot derived by hand using the same logic), so
  it passes by construction and can never disagree with the implementation. Expected values must
  come from an independent source: a known-good literal, a worked example, the spec.
- Tests that rely on test execution order or shared mutable state
- No regression test for a bug fix — the bug will recur

---

## Review Lens 6: Naming & Clarity

Code is read far more than it's written. Names must communicate intent without requiring
the reader to trace the implementation.

**Questions to ask:**
- Do function and variable names describe what they do, not how?
- Are boolean names phrased as predicates? (`isActive`, `hasPermission`, not `active`, `permission`)
- Are functions doing one thing? If a function name requires "and", it probably needs to be split.
- Are magic numbers and strings named? (`MAX_RETRY_COUNT = 3` not `if (attempts > 3)`)
- Are abbreviations avoided unless they're universally understood in the domain?
- Would a new team member understand this code without asking the author?

---

## Smell Baseline

On top of the six lenses, the Standards axis always carries this fixed set of code smells
(Fowler, *Refactoring*, ch. 3). It applies even when a repo documents no standards of its own.

Two rules bind it:

- **The repo overrides.** A documented repo standard always wins. Where a project convention
  endorses something the baseline would flag, suppress the smell.
- **Always a judgement call.** Each smell is a labelled heuristic ("possible Feature Envy"),
  never a hard violation — and skip anything linting or type-checking already enforces.

Each reads *what it is* → *how to fix*. Match against the diff:

- **Mysterious Name** — a function, variable, or type whose name doesn't reveal what it does or
  holds. → Rename it. If no honest name comes, the design is murky.
- **Duplicated Code** — the same logic shape in more than one hunk or file in the change. →
  Extract the shared shape; call it from both.
- **Feature Envy** — a method that reaches into another object's data more than its own. → Move
  the method onto the data it envies.
- **Data Clumps** — the same few fields or params keep travelling together (a type wanting to be
  born). → Bundle them into one type; pass that.
- **Primitive Obsession** — a primitive or string standing in for a domain concept that deserves
  its own type. → Give the concept its own small type.
- **Repeated Switches** — the same `switch` or `if`-cascade on the same type recurs across the
  change. → Replace with polymorphism, or one map both sites share.
- **Shotgun Surgery** — one logical change forces scattered edits across many files in the diff.
  → Gather what changes together into one module.
- **Divergent Change** — one file or module is edited for several unrelated reasons. → Split so
  each module changes for one reason.
- **Speculative Generality** — abstraction, parameters, or hooks added for needs the spec doesn't
  have. → Delete it; inline back until a real need shows.
- **Message Chains** — long `a.b().c().d()` navigation the caller shouldn't depend on. → Hide the
  walk behind one method on the first object.
- **Middle Man** — a class or function that mostly just delegates onward. → Cut it; call the real
  target directly.
- **Refused Bequest** — a subclass or implementer that ignores or overrides most of what it
  inherits. → Drop the inheritance; use composition.

---

# Axis B — Spec

Does the diff faithfully implement what was actually asked for? Three questions, in order.

### 1. What's missing or partial?

Walk every requirement and acceptance criterion in the task doc and mark it implemented,
partially implemented, or absent. **Quote the criterion** for each finding.

Partial is the dangerous category and the easiest to miss: the endpoint exists but ignores the
pagination the doc specified; the validation runs on create but not on update; three of the four
states in the doc are handled.

### 2. What's here that nobody asked for? (Scope creep)

Behaviour in the diff that the spec never requested. Flag it — don't assume it's a bonus.
Unrequested behaviour is untested by the acceptance criteria, unreviewed by whoever wrote the
doc, and permanent once merged.

A refactor that came along for the ride belongs here too. It may well be a good refactor; it's
still outside what was agreed, and it inflates the blast radius of a change that was scoped to be
small.

### 3. What looks done but isn't?

The subtlest category, and the reason this axis needs its own agent. The code appears to satisfy
a requirement, but doesn't:

- The doc said "notify the user"; the code writes a row to a `notifications` table nothing reads.
- The doc said "idempotent"; the handler is safe on retry only when the first attempt got far
  enough to write its key.
- The doc said "soft delete"; the record is flagged, and four other queries still return it.

For each, quote the requirement and state concretely what the implementation actually does
instead.

### Contradicted decisions

If the change contradicts an existing ADR, that's a Spec finding. Say which ADR and what it
decided. It's not automatically wrong — ADRs get superseded — but it needs to be a deliberate
choice, recorded, not an accident.

---

# Review Output Format

```markdown
## Code Review: [File or Feature Name]

**Reviewed:** `<fixed-point>...HEAD` (N commits)
**Spec source:** [path or issue, or "none found — Spec axis skipped"]

### Summary
[2–3 sentences. Is this safe to merge? What's the main concern on each axis?]

---

## Standards

#### 🔴 Blocking — [Short label]
**Location:** `src/path/to/file.ts:42`
**Issue:** [What's wrong]
**Failure mode:** [What actually happens when this breaks]
**Suggested fix:**
```ts
// corrected code
```

#### 🟡 Should Fix — [Short label]
...

#### 🔵 Consider — [Short label]
...

#### ⚪ Nit
- `line 18`: [minor issue]
- `line 34`: [minor issue]

---

## Spec

#### 🔴 Blocking — Missing: [requirement]
**Spec says:** > [quoted acceptance criterion]
**Diff does:** [what's actually there, or nothing]
**Gap:** [what would need to change]

#### 🟡 Should Fix — Scope creep: [what was added]
**Not in spec.** [What it does, why it's a risk to ship unreviewed]

#### 🟡 Should Fix — Looks done, isn't: [requirement]
**Spec says:** > [quoted criterion]
**Diff does:** [what it actually does instead]

---

### Axis summary
- **Standards:** N findings. Worst: [one line]
- **Spec:** N findings. Worst: [one line]

### What's Working Well
- [Specific thing done well — be genuine, not perfunctory]
```

---

## Scope Rules

- Review only what's in the diff / submitted code. Don't review the surrounding codebase
  unless a finding requires context from it.
- Don't rewrite working code to match a different style. If it's correct and clear, say so.
- If a finding is outside the scope of the current task doc, note it as a 🔵 Consider with
  a suggestion to open a follow-up task — don't block the current work.
- If the code hasn't been tested yet, say so in the summary and note which lenses couldn't
  be fully applied.
- **Never resolve a disagreement between the two axes by dropping one.** A diff that is clean
  code implementing the wrong thing has one 🔴 on the Spec axis and zero on Standards, and the
  report must show exactly that.

---

## Related skills

Findings that belong to a specialist skill should say so rather than being re-derived here:

- Auth, access control, session handling → `auth-authorization-audit`
- Schema and migration safety → `db-migration-safety`
- Error payload leakage → `secure-error-handling`
- Input validation at trust boundaries → `input-validation-sanitization`
- New or updated packages → `dependency-supply-chain-security`
- Test design rather than test presence → `test-strategy-planner`
