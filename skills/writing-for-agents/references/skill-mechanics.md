# Skill mechanics

The skill-specific branch of [`writing-for-agents`](../SKILL.md): what changes when the document
is a skill. Frontmatter, the invocation choice, and router skills. Everything else about writing
it is the universal reference in `SKILL.md`.

---

## Frontmatter

Required:

- **`name`** — the skill identifier. Matches the folder name.
- **`description`** — the skill's top-level context pointer. All "when to use" information lives
  here, never in the body, because the body is not loaded until the skill has already fired.

Optional, and rarely needed:

- **`disable-model-invocation: true`** — see below.
- **`argument-hint`** — a short prompt for what the human should type after the skill name.

**Hard limit: the `description` must be under 1024 characters.** Skill upload rejects anything at
or over it. Budget to roughly 950 to leave headroom for a later edit, and count characters rather
than eyeballing — a description that reads short can run long once trigger phrases accumulate.

Hitting the limit is usually a signal, not just a constraint. A description straining against 1024
is either carrying branches that belong to a second skill, or carrying routing text that exists
only because two skills collide (see *Choosing* below). Splitting or merging is often the real fix;
trimming adjectives is the fallback.

The `description` is subject to every pointer-writing rule in `SKILL.md`: front-load the leading
word, one trigger per branch, cut identity the body already carries.

One deliberate exception to pruning: agents **undertrigger** skills far more often than they
overtrigger them. A description written at the minimum viable length usually fires too rarely. Be
slightly pushy — name the proactive cases explicitly ("also trigger when…", "don't wait to be
asked if…"), and name the adjacent skill to route to when this one is the wrong fit. Those lines
earn their context load by fixing the more common failure.

---

## Invocation

Two choices, trading the two loads against each other.

### Model-invoked (omit `disable-model-invocation`)

The skill keeps a `description` in the agent's reach, so:

- the agent can fire it autonomously,
- **other skills can reach it**,
- the human can still type its name — model-invocation always *includes* user reach. A
  description only ever adds agent discovery; it never removes the human's.

The cost is permanent context load: that description sits in the window on every turn, whether or
not it ever fires.

A model-invoked skill whose content is all reference is also the natural home for **shared
reference**. Because another skill can invoke it, reference needed by several skills lives in one
place instead of being copied into each.

### User-invoked (`disable-model-invocation: true`)

The description is stripped from the agent's reach. Only the human typing the skill's name can
invoke it, and **no other skill can reach it either**.

Zero context load — but it spends cognitive load, because the human is now the index that has to
remember the skill exists. The `description` becomes human-facing: a one-line summary with the
trigger lists stripped out.

### Choosing

**Pick model-invocation only when the agent must reach the skill on its own, or another skill
must.** If it only ever fires by hand, make it user-invoked and pay no context load.

Two consequences worth holding onto:

- A skill that other skills need to compose with **must** be model-invoked. This is why an
  interview primitive, a design vocabulary, or a shared format reference is model-invoked even
  when a human would rarely type its name.
- **Shared reference that two user-invoked skills both need can live in neither.** With no
  descriptions, neither can fire the other. Push it to a plain file outside the skill system —
  external reference that any skill can point at.

---

## Splitting by invocation

The invocation cut of splitting (the sequence cut lives in `SKILL.md`):

Split off a model-invoked skill when either holds:

- you have a distinct **leading word** that should trigger it on its own — a word you actually
  use in your prompts, not a hypothetical one, or
- another skill must be able to reach it.

You pay context load for the new always-loaded description, so that independent reach has to be
worth it. A split that produces a skill nothing else reaches, and that you never type, has bought
nothing and costs every turn.

---

## Router skills

When user-invoked skills multiply past what a human can remember, that piled-up cognitive load is
cured by a **router skill**: one user-invoked skill that names the others and says when to reach
for each, so the human has one name to remember instead of twenty.

Its hard limit: **a router can only hint, never fire.** User-invoked skills have no description,
so nothing but the human can reach them. The router outputs a recommendation; the human types the
name.

A router is only worth its own load once the set is genuinely unmemorable. Below that threshold it
is a document that goes stale — and a router that still lists a renamed skill, or omits a new one,
is a router that lies. Re-sync it in the same change that adds, renames, or removes a skill.
