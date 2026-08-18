# Phase boundaries

A reference for deciding what to do with context at the seam between two chunks of work. Not a
skill — a doc to read once, keep somewhere findable, and point at from `CLAUDE.md` when it starts
paying off.

A **phase** is a chunk of work inside a session: the design interview, the implementation, the
QA pass.
The definition is fuzzy on purpose — a phase ends when you think *"ok, we're done with that."*

The **phase boundary** is the gap between two phases, and it is the only place this decision
belongs. Mid-phase there is no decision to make: continue, or split the work that's left into
subagents. Compacting mid-phase makes the agent lose the thread.

---

## The five options

| Option | What it does |
|---|---|
| **Continue** | Stay in the session. No context switch at all. |
| **Clear** | Empty the context window and start from nothing. |
| **Handoff** | Write a portable markdown file and seed a session anywhere with it. |
| **Subagent** | Send the task to its own context window and get a report back. |
| **Compact** | Compress this context and seed a fresh session with the summary. |

---

## The tree

Work top to bottom at the boundary. **The first yes wins.**

### 1. Can you continue in this session?

Two things make the answer yes:

- the next phase needs this phase as a **primary source**, or
- you have enough headroom left for the next phase to fit.

Grilling → implementation is the standard yes: the implementation wants the reasoning verbatim,
not a summary of it.

**Continue costs nothing and loses nothing, so rule it out before anything else.**

### 2. Is the context irrelevant to what comes next?

Is everything here — the exploration, the decisions, the dead ends — disposable? Then **clear**.
It's the cheapest move on the board: takes no time, hands back the whole window, and isn't
terminal (the old session stays resumable).

The cost of getting this wrong is one-way. Clear a *relevant* context and you lose the **why**
behind what you built. No amount of reading the diff back returns it.

### 3. Do you need to hand off?

**Handoff is narrow.** You need it only when you are:

- swapping to a **different harness** (Claude Code → Codex, or a Cowork session → a local one),
- moving to a **different directory** or repo,
- sending the work to a **colleague**,
- or forking a side task you found **mid-phase**, without derailing what you're doing.

That list is the whole clause. What a handoff buys is **portability** — a file that travels. If
nothing is travelling, you don't need one.

### 4. Can the task be done unattended?

Is it scoped tightly enough to run with you away from the keyboard, no steering? Then send it to a
**subagent** and leave this session untouched.

Automated review is the standard case: the agent reads the diff and reports back, and you aren't
needed while it does.

### 5. Otherwise, compact.

Relevant context, same harness, same directory, and you need to stay in the loop — this is where
the tree lands, and it lands here often.

Pass an instruction with it ("we're going to QA this area next") so the summary keeps what the
next phase actually needs.

**Compact is the default, not the first reach.** It sits at the bottom because the four questions
above it are all cheaper or more precise. The failure mode when people start here is a fresh
session that is confidently wrong about a decision the summary flattened.

---

## Primary and secondary sources

Every move except **Continue** turns a **primary source** — the session as it actually happened —
into a **secondary source**: a summary of it.

| Source | Information | Noise | Room to move |
|---|---|---|---|
| Primary (Continue) | Full | Lots | Little |
| Secondary (Compact, Handoff) | Lossy | Less | Lots |

This is why question 1 comes first. You only pay the lossiness when staying costs more than it
saves.

---

## These are judgement calls

None of the five questions is objective — each has taste in it, and the same boundary can go two
ways on two days.

The value isn't in getting each one right. It's in asking them **in order**, and **at the
boundary** rather than in the middle of the work.
