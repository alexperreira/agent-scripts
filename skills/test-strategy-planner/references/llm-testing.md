# Testing AI / LLM Outputs

Read when the feature produces or consumes LLM output. Standard deterministic test assertions
don't apply to generated content — use these patterns instead.

---

## What to test deterministically

- The **structure** of the output (required fields present, correct types, valid enum values)
- **Schema validation** — run the raw output through your Zod/Pydantic schema and assert it parses
- **Failure modes** — what happens when the model returns malformed output, times out, or errors
- **Retry logic** — does the system retry correctly on failure?
- **Prompt assembly** — unit test the function that builds the system prompt; assert it contains
  required sections given known inputs

---

## What to test with snapshot / golden output

- Representative outputs for known inputs — store as fixtures, review on change
- Useful for catching regressions in prompt changes, not for asserting correctness

---

## What to assert on

Assert only on properties that hold for every valid generation:

| Assert on | Example |
|---|---|
| Schema conformance | Output parses through the Zod/Pydantic schema |
| Required field presence | `description` is a non-empty string |
| Type and enum validity | `difficulty` is one of the declared enum values |
| Invariants and bounds | `sets.length` between 1 and 10; totals sum correctly |
| Error and retry behavior | Malformed response triggers exactly one retry, then a typed error |

Routes for everything else:

| Property | Where it belongs |
|---|---|
| Specific wording of generated text | Golden fixtures, reviewed on change — not assertions |
| Legitimately variable field values (e.g. a generated workout description) | Schema + invariant assertions only |
| Output quality | Human eval loop, not the automated test suite |
