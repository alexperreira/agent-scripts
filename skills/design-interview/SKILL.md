---
name: design-interview
description: >
  Relentlessly interview Alex about a plan, design, decision, or idea until every branch of the
  design tree is resolved. Use this skill whenever Alex says "interview me about this", "grill me",
  "poke holes in this", "stress-test this", "what am I missing", or presents a plan, design, or
  approach and asks whether it holds up. Also trigger proactively — and say so — before any non-trivial build,
  spec, or migration where Alex has described a goal but not the decisions underneath it: the
  most common failure in agent-assisted work is building the wrong thing confidently. Other
  skills should invoke this skill directly whenever they need to align with Alex before acting,
  rather than writing their own interview loop.
---

# Design Interview

The interview primitive. Every other skill that needs to align with Alex before acting should
invoke this one rather than inventing its own question loop.

The purpose is not to collect requirements. It is to surface the decisions Alex has not yet
made — including the ones he does not yet know are decisions.

---

## The design tree

Model the work as a **design tree**: every decision branches into the decisions that hang off it.
"Which database" branches into "what's the migration story", "what's the connection pooling
model", "who owns the schema" — none of which can be answered before the first one is.

The **frontier** is every decision whose prerequisites are already settled: the questions that
can be asked *now*, without guessing at answers not yet heard.

---

## Work in rounds

**Ask the whole frontier in one round.** Number each question and give a recommended answer.
Then stop and wait.

Format every question like this:

```
❓ **Q1** — **<short question title>**: <the question. May be several paragraphs. May offer
multiple choices, in which case list them.>

➡️ <the recommended answer, and one line on why>
```

The recommendation is mandatory, not optional. An unanswered question with no recommendation
puts the whole load on Alex; a recommendation lets him accept in one word or push back with
specifics. Recommend even when uncertain — flag the uncertainty in the same line.

Each round of answers reshapes the tree. Settled decisions push the frontier outward and unblock
questions that depended on them. Recompute the frontier and ask the next round.

**A question whose answer depends on another question still open in this round belongs to a
later round, not this one.** Asking it now forces Alex to guess at his own future answer. This
is the single most common way a design interview goes wrong.

---

## Facts are the agent's job; decisions are Alex's

Never ask Alex something that can be looked up.

When a frontier question needs a fact from the environment — what the schema currently looks
like, which version is pinned, whether a route already exists, what an API actually returns —
dispatch a subagent to find it. Do not ask.

**Don't block on it.** A running exploration is an unsettled prerequisite, so only the questions
downstream of it wait. Ask the rest of the frontier now, and fold the subagent's findings into
the next round.

The split is absolute:

| Kind | Who resolves it |
|---|---|
| What the code currently does | Agent — go read it |
| What version, what config, what's installed | Agent — go check |
| What the third-party API supports | Agent — go read the docs |
| What Alex wants it to do | Alex |
| Which trade-off to accept | Alex |
| What "done" means | Alex |

---

## Completion

The session is done when **the frontier is empty**: every branch of the design tree visited,
nothing left silently assumed.

Do not act on the outcome until Alex confirms shared understanding has been reached. An interview
that slides into implementation without that confirmation has failed at its one job.

If the frontier empties in one round, say so plainly — the work was smaller than it looked, and
padding it with invented questions wastes Alex's time.

---

## Anti-patterns

- **Answering your own questions.** If the agent supplies both sides of the exchange, no
  alignment has happened. Recommendations are fine; proceeding on them unanswered is not.
- **One question at a time.** Serialises what could be parallel and turns a five-minute session
  into forty. Ask the whole frontier.
- **Asking lookupable facts.** Every one of these spends Alex's attention on work the agent
  should have done.
- **Rounds that never end.** The frontier must actually shrink. If it isn't shrinking, the
  questions are too fine-grained — coarsen them.
- **Interviewing about the wrong subject.** If Alex genuinely cannot answer because the
  knowledge lives in someone else's head, stop interviewing and say so.
