---
name: writing-for-agents
description: >
  Reference for writing any document an agent reads — a SKILL.md, a CLAUDE.md or AGENTS.md, a
  reference file reached by a pointer. Covers the two budgets (context load vs cognitive load),
  the information hierarchy, completion criteria, leading words, and the pruning discipline. Use
  this skill whenever Alex is writing, editing, reviewing, or debugging a skill, a CLAUDE.md, an
  AGENTS.md, or a prompt-shaped document; whenever a skill triggers too often, too rarely, or
  behaves inconsistently run to run; and whenever a document has grown long enough that Alex
  wonders what to cut. Also trigger proactively before writing a new SKILL.md from scratch — the
  levers here decide whether the skill works, and retrofitting them afterwards is harder. For the
  create-test-evaluate-iterate loop around a skill, use `skill-creator`; this skill is about the
  writing itself, and the two compose.
---

# Writing for Agents

A reference for every document an agent consumes. The packaging differs — a skill, a `CLAUDE.md`,
a doc reached by a pointer — but the writing does not: the same levers make each one predictable.

**Predictable means the agent takes the same _process_ every run, not that it produces the same
output.** Aiming at identical output is how a document ends up over-specified and brittle. Aim at
identical process.

Use this alongside `skill-creator`, which owns the surrounding loop — capturing intent, writing
test prompts, running evals, iterating. This skill owns the words on the page.

For frontmatter, the invocation choice, and router skills, read
[`references/skill-mechanics.md`](references/skill-mechanics.md).

---

## Context pointers

A **context pointer** is a reference held in the agent's context that names some out-of-context
material and encodes the condition for reaching it. A skill's `description` is one. A line in
`CLAUDE.md` naming a doc is the same object.

**The pointer's wording, not its target, decides when the agent reaches the material — and how
reliably.** A must-have target behind a weakly worded pointer is a variance bug. Sharpen the
wording first; inline the material only if sharpening fails.

A pointer does two jobs: state what the material is, and list the **branches** that should
trigger reaching it. (A branch is a distinct case the document handles, so different runs take
different paths through it.)

Every word of an always-loaded pointer costs on every turn, so it earns harder pruning than the
body:

- **Front-load the leading word.** The pointer is where it does its triggering work.
- **One trigger per branch.** Synonyms renaming a single branch are one branch written twice.
  Collapse them; keep only genuinely distinct branches.
- **Cut identity the body already carries.**

---

## The two loads

Every document and pointer spends one of two budgets:

- **Context load** — the cost of always-loaded material on the agent's window. A `CLAUDE.md`
  line, a skill description, anything sitting in context every turn, spending tokens and
  attention whether or not it fires.
- **Cognitive load** — the cost on the human. Which documents exist, and when to reach for each.
  The human is the index.

Cognitive load is **not a cost to minimise.** It is the price of human agency. Spend it where
human judgement matters; remove it where it does not.

Material reached only through a pointer escapes context load at the price of the pointer's own
line. Material with no pointer at all rides entirely on cognitive load.

---

## Information hierarchy

A document is built from two content types, which mix freely:

- **Steps** — the ordered actions the agent performs.
- **Reference** — definitions, rules, and facts consulted on demand.

All steps is a recipe. All reference is a review's rule set, or this document. Both is common.

The core decision is where each piece sits on the **information hierarchy**, a ladder ranked by
how immediately the agent needs the material:

1. **In-file step** — the primary tier: what the agent does, in order.
2. **In-file reference** — consulted on demand. Often a legitimately flat peer set (every rule of
   a review on one rung). That is a fine arrangement, not a smell.
3. **Disclosed reference** — pushed into a separate file, reached by a context pointer, loaded
   only when the pointer fires. Spans a sibling file in the same folder through fully external
   reference any document can point at.

Push too little down and the top bloats. Push too much and you hide material the agent actually
needs. That tension is the whole decision.

**Progressive disclosure** is the move down the ladder. It is not primarily a token optimisation —
it is how the hierarchy is protected. The cleanest test is branching: **inline what every branch
needs; push behind a pointer what only some branches reach.**

When a document has steps, in-file reference that should have been disclosed *buries* them, and
attending to those steps becomes a coin flip. That makes disclosure a variance lever, not just a
legibility one.

**Co-location** is the within-file companion. Where the ladder decides how far down a piece sits,
co-location decides what sits beside it once there. Keep a concept's definition, rules, and
caveats under one heading rather than scattered, so reading one part brings its neighbours along.
The test: the document should read like documentation written for the agent.

(Scattering is distinct from duplication. Duplication repeats one meaning in two places;
scattering fragments one meaning across many.)

**Sprawl** is the failure mode here — a document simply too long, even when every line is live
and unique. Attention thins across the excess, and every extra line is one more to keep relevant.
The cure is the ladder: disclose reference behind pointers, and split by branch or sequence so
each path carries only what it needs.

---

## Steps and completion criteria

Every step ends on a **completion criterion** — the condition telling the agent the work is done.
Two properties make it a lever:

### Clarity

Can the agent tell done from not-done?

A vague bound ("understanding reached", "sufficiently covered") invites **premature completion**:
ending the step before it is genuinely done, attention slipping toward *being done*.

The visible steps still ahead — the **post-completion steps** — supply the pull. The criterion's
clarity is the resistance.

Defend in order:

1. **Sharpen the bound first.** Local and cheap. "Every modified model accounted for" beats
   "review the models".
2. **Only if it is irreducibly fuzzy _and_ you observe the rush**, hide the later steps by
   splitting the sequence. Note that hiding only works across a real context boundary — a handoff
   or a subagent dispatch. An inline call leaves the later steps in context and clears nothing.

### Demand

How much does the criterion require?

"Every modified model accounted for" forces thorough work where "produce a change list" does not.
Demand drives **legwork** — the digging the agent does within the work, latent in the wording
rather than written as its own step.

Demand is not step-bound. "Every rule applied" binds a body of flat reference just as "every step
done" binds a sequence — which is how an all-reference document still carries an exhaustiveness
bar.

**The strongest criteria are both checkable and exhaustive.**

---

## When to split

Splitting one document into two spends one of the two loads, so split only when the cut earns it.

- **By sequence** — split a run of steps where the post-completion steps tempt the agent to rush
  the one in front of it. Keeping them out of view drives more legwork on the current task.
  Beware the reverse: merging two sequences exposes each step to what follows, inviting premature
  completion.
- **By invocation** — see [`references/skill-mechanics.md`](references/skill-mechanics.md).

---

## Leading words

A **leading word** is a compact concept already living in the model's pretraining that the agent
thinks with while running the document — *lesson*, *frontier*, *fog of war*, *tracer bullet*,
*seam*, *red*.

Repeated **as a token, never as a sentence**, it accumulates a distributed definition and anchors
a whole region of behaviour in the fewest possible tokens, by recruiting priors the model already
holds.

Coining your own works if you define it clearly — but a made-up word recruits no priors. You pay
in definition tokens what a pretrained word gives free. **Reach for an existing word first.**

It anchors twice:

- **In the body — execution.** The agent reaches for the same behaviour every time the word
  appears. Inside flat reference, it focuses attention on a class of thing to look for.
- **In a pointer — invocation.** When the same word lives in your prompts, your docs, and your
  codebase, the agent links that shared language to the material and reaches it more reliably.

**Hunt for opportunities to refactor with leading words.** A triad spelled out at three sites, or
a pointer spending a sentence to gesture at one idea, is a passage begging to collapse into a
single token:

- "fast, deterministic, low-overhead" → **tight** (a *tight* loop).
- "a feedback loop you believe in" → **red** — a fuzzy gate becomes a binary observable state
  (the loop goes *red* on the bug, or it doesn't).

You win twice: fewer tokens, and a sharper hook for the agent to hang its thinking on. Assume
every document you write is carrying restatements that leading words retire.

### Negation is the failure mode beside this lever

Steering by prohibition drags the forbidden behaviour into context and makes it *more* available,
not less. *Don't think of an elephant*, and the elephant is all there is. The negation is a weak
modifier that the strongly-activated concept overruns, so the ban half-reads as an instruction to
do the thing.

**Prompt the positive.** State the target behaviour ("write one-line comments") so the banned one
is never spoken. A prohibition earns its place only as a hard guardrail you cannot phrase
positively — and even then, pair it with the positive target so attention lands on what to do.

---

## Pruning

- **Single source of truth.** Keep each meaning in one authoritative place, so changing the
  behaviour is a one-place edit. **Duplication** costs maintenance and tokens, and inflates a
  meaning's prominence on the ladder past its real rank. (It is the accidental inverse of a
  leading word, which repeats a *token* on purpose, never the *meaning*.)

- **The environment is a source of truth too** — `package.json` scripts, config files, the
  directory layout, `--help` output. A document that restates it is a **cache**: a copy of a
  lookup, earning its load only when the lookup is expensive. Cache what the agent cannot find by
  looking — the unwritten convention, the reason behind a choice, the gotcha no config confesses.
  Leave one-file, one-command lookups to the environment, where they cannot go stale.

- **Check every line for relevance.** Does it still bear on what the document does? A line loses
  relevance by never bearing on the task (mere exposition, or a branch that should be disclosed),
  or by going stale as the world it describes changes. Shorter documents are easier to keep
  relevant.

  Without a pruning discipline the default fate is **sediment**: stale layers that settle because
  adding feels safe and removing feels risky, until you have to core down through them to find
  what is still live.

- **Hunt no-ops sentence by sentence.** An instruction the model already obeys by default pays
  load to say nothing.

  The test — *does this change behaviour versus the default?* — is **model-relative, not
  reader-relative.** Two people disagreeing about a no-op are disagreeing about the default, and
  they settle it by running the document, not by debating it.

  When a sentence fails the test, delete the whole sentence rather than trimming words from it.

  The test also grades leading words: a word too weak to beat the default (*be thorough*, when the
  agent is already thorough-ish) is a no-op. The fix is a stronger word (*relentless*), not a
  different technique.

---

## Reviewing an existing document

### Step 0 — the pointer pass is library-wide, not per-document

Run this **once across every description at once**, before opening any single file. Collisions are
invisible from inside one document: two skills can each have a perfectly clear pointer and still
share a trigger phrase, and only a side-by-side read finds it.

- **Extract every description** and read them as one list.
- **Identical trigger phrases in two descriptions** are a coin flip at invocation time. Fix by
  making one conditional on something other than the phrase — the project, the directory, the
  artifact type — and adding the reciprocal line to the other.
- **High term overlap without explicit routing** is the same bug in slower motion. Overlap is fine
  when each description ends by naming its siblings and when to prefer them; it is a defect when
  they merely coexist.
- **Sum the character count.** That total is loaded on every turn of every session, forever.
  Knowing the number is the point; cutting it is only worth doing once it hurts.

Skipping this and reviewing file-by-file will produce a pile of true, small findings and miss the
largest one.

### Then, per document

Run these in order. The first two are cheap and catch most problems.

1. **Read the pointer alone.** From the description or `CLAUDE.md` line by itself, is it obvious
   when this fires? List the branches it claims. A missing branch means undertriggering.
2. **No-op sweep.** Sentence by sentence: does this beat the default? Delete whole sentences that
   don't. Findings here are **hypotheses about the model's defaults**, not facts — the test is
   model-relative. Confirm the expensive ones by running the document with and without the line
   before deleting in bulk.
3. **Negation sweep.** Every "don't" and "never" — can it be restated as the positive target?
   Keep the prohibition only as a hard guardrail, and pair it with the positive.
4. **Criterion audit.** Every step: can the agent tell done from not-done, and does the bound
   demand enough? Sharpen the vague ones.
5. **Ladder check.** Anything in-file that only some branches reach → candidate for disclosure.
   Anything disclosed that every branch needs → pull it back inline.
6. **Leading-word hunt.** Find the restatements. Collapse each into one token.
7. **Duplication check.** Each meaning in exactly one place. Each token repeated on purpose.
