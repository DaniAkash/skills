# Handoff Prompts

The handoff message is what makes this skill work. A vague request gets a vague answer; a specific request gets the trace you need.

Every handoff message must answer four questions for the human:

1. **What command to run** (exact, copy-pasteable)
2. **What action to take** (the steps that should reproduce the bug)
3. **What to capture** (every line containing `[TRACE]`, in order)
4. **How to send it back** (paste in the conversation, in a code block, in order)

---

## Initial handoff

Use this as the first request after instrumenting the code.

> I've added `[TRACE]` logs at the suspected points along this code path. Before I can make progress, I need to see what actually happens at runtime.
>
> Please:
>
> 1. **Run:** `<exact command>`
> 2. **Do this:** `<the action that reproduces the bug — be specific>`
> 3. **Capture:** every line in the terminal/output that starts with `[TRACE]`, in the order they appear
> 4. **Send back:** paste them into the conversation in a code block, preserving order
>
> While we're tracing, I won't commit anything and will ignore any lint/test noise from the added logs. Once we find the root cause and you confirm it, I'll strip the logs and write the fix.

---

## When the bug doesn't reproduce

Sometimes the human runs the trace and the bug doesn't fire. Don't assume it's fixed — assume the trigger is wrong.

> The trace doesn't show the bug, which is interesting on its own. A few possibilities:
>
> - Was there a different action sequence when you saw the bug originally? (e.g. a specific order, a particular input, an external dependency)
> - Are there any environment differences? (different data, different feature flag, different user state)
> - Did the bug happen on a fresh load or only after some prior interaction?
>
> If we can find the trigger, we can re-trace. If you can't reliably reproduce it, that itself is a signal — the bug may be a race condition or depend on timing/state we haven't captured yet.

---

## Follow-up: narrowing the scope

If the first trace shows that the bug happens somewhere between two of your log points but you can't tell exactly where, ask for a second round.

> Looking at the trace: I can see the divergence happens between `<file:line A>` (where the value is correct) and `<file:line B>` (where the value is wrong), but the gap is too wide. Let me add a few more `[TRACE]` logs in that range.
>
> *(adds more logs)*
>
> Please re-run the same scenario and paste the new trace. Same protocol — every line starting with `[TRACE]`, in order, in a code block.

---

## Follow-up: testing a hypothesis

When the first trace gives you a hypothesis but you want to confirm it before declaring root cause.

> Based on the trace, I think the issue is that `<X>` is being called twice with stale state. To confirm, I'd like to:
>
> 1. Add one more `[TRACE]` log inside `<specific function>` that prints the call stack so we can see who's invoking it
> 2. Re-run the same scenario and check if my hypothesis matches
>
> If you'd rather skip this and just try a fix, that's fine — but the trace will give us certainty before I make changes.

---

## Confirmation prompt before exit

Before stripping all your trace logs and writing the fix, get explicit confirmation. This avoids the case where the agent thinks it's found the bug but actually misread the trace.

> The trace shows:
> - At `<file:line>`, `<value>` is `<expected>` — as we expected
> - At `<file:line>`, `<value>` is `<actual>` — this is where things diverge
> - The cause is `<short explanation>` — `<one-sentence root cause>`
>
> The fix would be `<what would change>`.
>
> Does this match what you're seeing on your end? If yes, I'll clean up the trace logs and write the fix as separate work. If you want me to verify anything else first, let me know.

---

## When to NOT ask for a trace

Some situations don't need this protocol. Don't waste the human's time:

- The error message already says the line and the cause — read the error first
- You haven't actually read the relevant code yet — read it first
- The fix is a one-liner you're confident in — write it, run the tests, ship it
- The bug is in a deterministic path you can reason about — reason about it

The trace protocol has a cost (the human has to actually run something and copy output). Use it when reading isn't enough — not as a default first step.

---

## Multi-process or distributed scenarios

If the trace involves multiple processes (frontend + backend, multiple workers, microservices), make this explicit in the handoff:

> This trace involves both the frontend and the API. Please:
>
> 1. **Run frontend:** `bun dev` (in one terminal)
> 2. **Run API:** `bun api:dev` (in another terminal)
> 3. **Reproduce:** open the app, click "Save"
> 4. **Capture:** every line containing `[TRACE]` from **both terminals**, and please indicate which terminal each line came from. The order is important.
>
> Easiest way: paste the frontend trace in one code block labeled "FRONTEND" and the API trace in another labeled "API". I'll merge them by timestamp / order.
