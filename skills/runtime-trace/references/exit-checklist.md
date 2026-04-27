# Exit Checklist

Trace mode exits when the root cause is confirmed by the human. Before resuming normal work (commits allowed, lint/tests must pass), run this checklist in order. Don't skip steps — leftover trace logs ship to production more often than you'd think.

## The principle: scaffolding vs. real work

Two layers happened during trace mode and they have **different lifespans**:

- **`[TRACE]` log statements** — *scaffolding*. Tagged with `[TRACE]` so they're greppable. They come out on exit, every time, with no exceptions.
- **Code changes** (everything else you wrote: defensive guards, functional updates, restructures, hypothesis patches that turned out to be the fix) — *real work*. They **stay** on exit.

The cleanup below is targeted at the scaffolding only. Do not revert your code changes. If a change you made during tracing turned out to be the fix, that's a feature of the workflow, not something to undo.

---

## 1. Get explicit confirmation from the human

You must have a clear "yes, that's the bug" from the human before exiting. If they're uncertain, do another round of tracing — don't exit on a guess.

If they say "yes, that's the bug" — proceed.

---

## 2. Remove every `[TRACE]` log statement (and **only** the log statements)

This step is narrow on purpose: you're removing scaffolding, not reverting work.

**Remove:**
- Every `[TRACE]` log statement you added, in full
- Imports/helpers that exist **solely** to support tracing (e.g. an unused `pprint`, a logging-only wrapper added just for the trace)

**Keep:**
- All other code changes you made during tracing — defensive guards, refactors, functional updaters, hypothesis patches, the change that turned out to be the fix
- These are real work and live on after trace mode

**Don't:**
- Comment logs out — delete them
- Convert logs to permanent logging — that's a separate decision and should be its own change
- Revert structural changes you made alongside the logs because "they were part of the trace work"

If a log was inside a hot loop, double-check the loop is back to its original form (no leftover counter, no leftover guard that existed only to throttle the log).

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

## 6. Decide what's left to do

Trace mode is over. There are two cases:

**Case A — A code change you made during tracing already fixes the bug.**
Common: while testing a hypothesis you switched to a functional updater, added a guard, or restructured logic, and the human confirmed in Step 5 that this also resolves the symptom. The fix is already in the file. There's nothing to write — but consider:
- Add a regression test that captures the bug, so this doesn't come back
- Make sure the change is scoped (not a sweeping refactor smuggled in under "the fix")
- The commit message references the bug, not the trace

**Case B — The bug is still there.**
You confirmed the cause with the trace, but no code change you made during tracing happened to fix it. Write the fix now as a normal piece of work:
- It's a fresh change, not a continuation of the trace
- Small and scoped to the root cause you confirmed
- Test it (manually or with a new test case)
- Commit with a meaningful message that references the bug

---

## 7. Commits are allowed again

Normal mode is back on. Commit the fix.

If the trace itself produced learnings worth keeping (e.g. "this codepath isn't well covered by tests"), capture them in a note or a follow-up issue — but not as committed `[TRACE]` logs.

---

## Quick reference

```
☐ Human confirmed root cause
☐ All [TRACE] log statements removed
☐ Code changes from trace mode are kept (don't revert them)
☐ grep '\[TRACE\]' returns nothing in source code
☐ Lint passes
☐ Tests pass
☐ Fix is in place — either via trace-mode code changes (Case A) or written now (Case B)
☐ Commit
```

Don't tick "trace mode complete" until every box is ticked.
