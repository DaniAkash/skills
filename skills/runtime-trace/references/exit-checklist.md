# Exit Checklist

Trace mode exits when the root cause is confirmed by the human. Before resuming normal work (commits allowed, lint/tests must pass), run this checklist in order. Don't skip steps — leftover trace logs ship to production more often than you'd think.

---

## 1. Get explicit confirmation from the human

You must have a clear "yes, that's the bug" from the human before exiting. If they're uncertain, do another round of tracing — don't exit on a guess.

If they say "yes, that's the bug" — proceed.

---

## 2. Remove every `[TRACE]` log statement

Go through each file you instrumented and delete every line you added. The instructions are:

- Remove the **entire log statement**, including any helper imports you added solely to support the trace (e.g. an unused `pprint` import, a temporary `dataclasses.asdict` call wrapper, a `console.log` helper, etc.)
- Do **not** comment them out — delete them
- Do **not** convert them to permanent logging — that's a separate decision and should be its own change
- If you added logs inside a hot loop, double-check the loop is back to its original form

---

## 3. Verify with grep

After your manual cleanup, run a literal-string search for `[TRACE]` across the project:

```bash
grep -r '\[TRACE\]' . --exclude-dir=node_modules --exclude-dir=.git
```

Or with ripgrep:

```bash
rg '\[TRACE\]'
```

The result must be **empty**. If anything is still found:
- Remove it
- Re-run the grep
- Don't proceed until grep returns nothing

The only exception is references documentation that *describes* the trace skill itself — i.e. files that contain the literal text `[TRACE]` as documentation, not as runtime code. Use your judgment.

---

## 4. Lint passes

Run the project's lint command:

```bash
# common examples — use whatever the project actually uses
bun lint
pnpm lint
biome check
eslint .
ruff check
```

If lint fails:
- If the failure is from your trace logs, it shouldn't be — you removed them all in step 2
- If the failure is pre-existing in the codebase, that's not your concern for this exit (note it for the user, but don't fix it as part of the exit checklist)
- If the failure is from changes you made that weren't trace logs (e.g. you accidentally edited something else), fix it before proceeding

---

## 5. Tests pass

Run the project's test command:

```bash
# whatever the project uses
bun test
pnpm test
pytest
go test ./...
cargo test
```

Same logic as lint:
- Failures from your trace logs shouldn't exist anymore — you removed them
- Pre-existing failures unrelated to the trace work are not part of this exit
- New failures from non-trace changes you accidentally made — fix them

---

## 6. Now write the fix

Trace mode is over. The actual bug fix is a separate piece of work that starts now. Treat it as such:

- It's a fresh change, not a continuation of the trace
- It should be small and scoped to the root cause you confirmed
- Test the fix (manually or with a new test case)
- Commit with a meaningful message that references the bug, not the trace

---

## 7. Commits are allowed again

Normal mode is back on. Commit the fix.

If the trace itself produced learnings worth keeping (e.g. "this codepath isn't well covered by tests"), capture them in a note or a follow-up issue — but not as committed `[TRACE]` logs.

---

## Quick reference

```
☐ Human confirmed root cause
☐ All [TRACE] log statements removed
☐ grep '\[TRACE\]' returns nothing in source code
☐ Lint passes
☐ Tests pass
☐ Fix is written as a separate, scoped change
☐ Commit the fix
```

Don't tick "trace mode complete" until every box is ticked.
