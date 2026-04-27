---
name: runtime-trace
description: >
  Structured human-in-the-loop debugging mode for when static code reading isn't enough.
  Use this skill whenever you're stuck debugging an issue where you can't tell what's actually
  happening at runtime — async timing, complex control flow, multiple call paths, conditional
  branches, or bugs that only reproduce when the app is running. Instead of guessing, the skill
  guides you through instrumenting the code with prefixed `[TRACE]` log statements, handing off
  to the human to run the app and capture the output, then reading the runtime trace to find the
  root cause. While in trace mode, normal rules are suspended (no commits, lint/test noise from
  logs is tolerated) — the goal is evidence, not progress. Trigger on: "I'm stuck debugging X",
  "help me figure out why Y is happening", "something weird is going on at runtime", "let's add
  some logs and see", "I can't tell what's wrong without running it", "trace what happens when",
  or any debugging conversation where the agent needs to see actual runtime behavior to make
  progress. When in doubt and you've reread the same code three times without a hypothesis,
  use this skill — gathering evidence beats guessing.
---

# Runtime Trace

You are stuck. The code looks fine, you've read it twice, but the bug is still there and you can't tell why. Static reading has run out of road.

This skill gives you a structured way to **gather runtime evidence with the human as your experiment runner**. You instrument the suspect code with `[TRACE]` log statements, the human runs the app and triggers the bug, you read the trace and see exactly where reality diverges from what you expected. No guessing.

Two layers happen during this work, and they have **different lifespans**:

- **The `[TRACE]` log statements** are *scaffolding*. Tagged with `[TRACE]` so they're easy to grep, copy, and strip. Always temporary — they come out on exit.
- **Code changes** (defensive guards, functional updates, restructured logic, hypothesis-testing patches, even the eventual fix) are *real work*. They stay when you exit. They're not part of the scaffolding.

That distinction is the whole game. When you exit, you remove the scaffolding and keep the work.

While you're tracing, normal commit/lint/test discipline is paused — you're in active iteration, not shipping. Once the human confirms the bug is understood and you've stripped the logs, normal flow resumes.

---

## When to enter trace mode

You should enter trace mode when:

- You've read the relevant code once or twice and don't have a confident hypothesis about what's wrong
- The bug involves async timing, race conditions, or order-dependent state
- Multiple code paths could be responsible and you can't tell which one runs
- The bug only happens under specific runtime conditions (live data, real user input, integration with external services)
- You've made a change you thought would fix it and the bug persists with no clear reason

You should **not** enter trace mode when:

- The fix is obvious from reading the code (typos, missing null check, wrong operator)
- The error message already tells you the line and the cause
- You haven't read the code yet — read it first
- The user is asking for a feature, not debugging an issue

---

## The protocol

Trace mode runs in 6 steps. Don't skip steps.

### Step 1 — State the question and your hypothesis

Before adding any logs, write one or two sentences answering:
- **What specifically don't you understand?** ("Why does the cart total show 0 after the second item is added?")
- **What's your best current hypothesis?** ("I think `recalculateTotal` is being called with stale state, but I'm not sure.")
- **Which code paths are candidates?** List the 1–3 functions or branches you suspect.

This forces you to be honest about whether you actually need a trace or just need to read more carefully. If you can't articulate the question, you don't need logs yet — you need to read.

### Step 2 — Instrument with `[TRACE]` logs

Add log statements at strategic points along the suspect code path. Every line must:

- Start with the prefix `[TRACE]` so the human can grep/copy them cleanly
- Identify the location: file name and either line number or function name
- Dump the relevant variables (stringified — don't trust `Object.toString`)
- Be at a meaningful point: function entries, branch decisions, key state mutations, async resolution points

Place logs at:
- Entry to each suspected function (with arguments)
- Both sides of every `if/else` or `switch` branch you care about
- Just before and just after any async boundary (`await`, `.then`, callback fires)
- Right before and right after any state mutation
- Anywhere your hypothesis says "this value should be X here"

**Don't over-instrument.** Five well-placed logs beat fifty scattered ones — too many makes the trace unreadable and tells the human you don't actually have a hypothesis. See `references/log-templates.md` for language-specific examples.

### Step 3 — Hand off to the human

You cannot run the app yourself. Send a message to the human telling them exactly:
1. **What command to run** (e.g. `bun dev`, `pnpm test:e2e`, `python manage.py runserver`)
2. **What action to take** that should reproduce the bug (e.g. "open the app, add two items to cart, then change the quantity of the first item")
3. **What to capture** — every line containing `[TRACE]`, in the order they appear
4. **How to send it back** — paste into the conversation, in order, inside a code block

Use the templates in `references/handoff-prompts.md`. The handoff message is what makes this skill work — a vague "can you run it?" gets a vague answer.

### Step 4 — Read the trace

When the human pastes the trace back, read it **in order** and compare to what your hypothesis said should happen. Specifically:

- Does the order of calls match your mental model?
- Are the variable values what you expected at each step?
- **Where does reality first diverge from expectation?** That divergence is your bug — or it's the next place to instrument.

If the trace is enough to explain the bug, go to Step 5. If not, narrow the scope: add more logs around the divergence point and ask for another round (return to Step 3).

### Step 5 — Confirm root cause with the human

Don't just declare the bug found. Say what the trace showed and what you now believe is happening. Ask the human to confirm before exiting trace mode.

> "The trace shows `recalculateTotal` is called twice on the second add — once with the new item and once with the stale items array, and the second call clobbers the first. The bug is that we're recalculating in both the reducer and the effect. Does that match what you're seeing? If yes, I'll clean up the trace logs and write the fix."

If you already made a code change during tracing that appears to have fixed the bug, **state that explicitly** so the human can confirm both the cause and the fix in one step:

> "The trace shows the same stale-closure pattern I suspected. I switched `setItems` to the functional updater form on line 28 while tracing — that change appears to fix it. Can you confirm both: (1) is this the cause you're seeing, and (2) does the fix on line 28 hold? If yes, I'll just strip the `[TRACE]` logs and we're done — the code change stays."

### Step 6 — Exit trace mode

Once the human confirms the bug is understood, exit cleanly. The cleanup is **targeted at the scaffolding only** — the logs come out, the code changes stay.

1. Remove **every** `[TRACE]` log statement you added — and any imports/helpers that exist *solely* to support tracing (e.g. an unused `pprint`, a logging-only wrapper)
2. **Keep all other code changes you made during tracing** — defensive guards, functional updates, restructures, hypothesis patches that turned out to fix the bug. These are real work, not scaffolding. Don't revert them.
3. Run `grep -r '\[TRACE\]' <project>` (or equivalent) and verify it returns nothing
4. Make sure lint passes
5. Make sure tests pass
6. Decide what's left to do:
   - **If your trace-mode code changes already fix the bug**, you're done with the fix itself — consider adding a test that captures the bug, then commit
   - **If the bug is still there**, write the fix now (it's a normal piece of work, not a continuation of trace mode)
7. Commits are allowed again

See `references/exit-checklist.md` for the full verification.

---

## Suspended rules during trace mode

These rules are **off** while you're between Step 1 and Step 6. They turn back on after Step 6.

| Rule | Normal mode | Trace mode |
|------|-------------|------------|
| Git commits | Required at meaningful points | **Do not commit** while `[TRACE]` logs are still in the code |
| Lint cleanliness | Must pass | Tolerated when caused by added logs (gone after exit) |
| Test passing | Must pass | Tolerated when caused by added logs |
| `[TRACE]` log statements | N/A | **Scaffolding** — added freely while tracing, fully removed on exit |
| Code changes (guards, refactors, hypothesis patches, the actual fix) | Standard discipline | **Allowed and kept** — these are real work, not scaffolding |
| Claiming the bug is fixed | Allowed when verified | **Only after the trace shows what was happening** — don't paper over the cause with a hopeful change |

The point isn't to freeze normal work — it's to **separate the temporary scaffolding from the lasting changes**. You can absolutely make code changes while tracing (a defensive guard to test a hypothesis, a switch to functional state updates, a restructure that incidentally fixes the bug). Those stay. Only the `[TRACE]` log statements are temporary.

What trace mode protects against is *premature* claims of a fix — a code change that "seems to make the bug go away" without trace evidence about *why* the bug was happening can easily be hiding the cause rather than fixing it. So: change code freely, but don't claim the bug is fixed until the trace explains what was happening.

**Note:** Pre-existing test or lint failures unrelated to your trace logs are not "tolerated" — those still matter, you just don't have to *fix* them while in trace mode. Don't merge "lint failures from added logs" with "lint failures that already existed in the codebase."

---

## Trace log format

Every line you add starts with `[TRACE]` and includes location + variables. Quick reference:

**JavaScript / TypeScript**
```ts
console.log('[TRACE]', 'cart.ts:42', 'recalculateTotal:enter', { items, total });
```

**Python**
```python
print('[TRACE]', 'cart.py:42', 'recalculate_total:enter', {'items': items, 'total': total})
```

For other languages and language-specific gotchas (e.g. struct printing in Go, debug formatting in Rust), see `references/log-templates.md`.

---

## Sample handoff message

> I've added `[TRACE]` logs at the suspected points. Please:
>
> 1. Run: `bun dev`
> 2. Open the app at `localhost:3000/cart`
> 3. Add two items, then change the quantity of the first item from 1 to 2
> 4. From the terminal, copy every line containing `[TRACE]` — in the order they appear — and paste them back here in a code block
>
> While we're tracing, I won't commit anything and will ignore any lint/test noise from the added logs. Once we find the root cause and you confirm it, I'll strip all the logs and write the fix.

For more variations (no-repro scenarios, follow-up rounds, multi-process apps), see `references/handoff-prompts.md`.

---

## What this skill protects against

This skill exists because two failure modes are common:

1. **Guessing instead of asking.** Agent rereads the code, makes a guess, ships a "fix" that doesn't address the real issue, bug persists, user is frustrated.
2. **Asking poorly.** Agent says "can you run it and tell me what happens?" — gets back "it's still broken" — has no more information than before.

Trace mode replaces both with: *gather specific evidence, read it carefully, then act*.
