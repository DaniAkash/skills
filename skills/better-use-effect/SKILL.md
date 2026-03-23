---
name: better-use-effect
description: Guides correct usage of React's useEffect hook — when to use it, when NOT to use it, and what modern alternatives exist. Use this skill whenever writing, reviewing, or refactoring React components that involve useEffect, side effects, data fetching, derived state, event handling, subscriptions, or any code where useEffect might be considered. Also applies when working with React hooks like useState, useMemo, useCallback, useReducer, useSyncExternalStore, useTransition, useOptimistic, useActionState, or the use hook. This skill is especially important when AI agents are generating React code, as they tend to overuse useEffect as a catch-all for anything that "needs to happen."
---

# Better useEffect

useEffect exists for one purpose: **synchronizing a component with an external system**. If you are not connecting to a browser API, a WebSocket, a third-party widget, or some other system outside of React, you almost certainly do not need useEffect.

## Decision Flowchart

Before writing `useEffect`, walk through these questions in order — stop at the first match. See `references/decision-flowchart.md` for expanded examples of each case.

1. **Computing a value from props or state?** → Compute inline. Use `useMemo` if expensive.
2. **Responding to a user interaction?** → Event handler.
3. **Fetching data?** → Data library (TanStack Query, SWR) or `use` hook with Suspense.
4. **Resetting state when a prop changes?** → `key` prop for clean remount.
5. **Subscribing to an external data source?** → `useSyncExternalStore`.
6. **Synchronizing with a browser API / third-party widget / external system?** → useEffect with cleanup.

## Anti-Patterns

### 1. Derived State via Effects

```tsx
// BAD — double render, state drift
const [filtered, setFiltered] = useState([])
useEffect(() => { setFiltered(items.filter(i => i.active)) }, [items])

// GOOD
const filtered = items.filter(i => i.active)
```

### 2. Data Fetching in Effects

```tsx
// BAD — race conditions, no caching
useEffect(() => { fetch(`/api/user/${id}`).then(r => r.json()).then(setUser) }, [id])

// GOOD
const { data: user } = useQuery(['user', id], () => fetchUser(id))
```

### 3. Event Responses via Effects

```tsx
// BAD — flag relay
const [submitted, setSubmitted] = useState(false)
useEffect(() => { if (submitted) { postForm(); setSubmitted(false) } }, [submitted])

// GOOD
function handleSubmit() { postForm() }
```

### 4. Resetting State on Prop Change

```tsx
// BAD
useEffect(() => { setDraft(''); setAttachments([]) }, [noteId])

// GOOD
<NoteEditor key={noteId} noteId={noteId} />
```

### 5. Effect Chains

Multiple effects where one sets state that triggers another. Consolidate into the event handler or derive values inline. See `references/anti-patterns.md` for detailed examples.

## Non-Primitive Dependencies

Objects, arrays, and functions in dependency arrays cause effects to re-run every render because React uses reference comparison (`Object.is`). This applies equally to:

- **Props** from the parent (objects, arrays, callbacks)
- **Locally-owned state** that is an object or array
- **Inline objects/functions** created during render

### Props: stabilize at source or destructure

```tsx
// Parent stabilizes
const data = useMemo(() => transform(raw), [raw])
return <Chart data={data} animate={true} color="blue" />

// Or child destructures to primitives
const { animate, color } = config
useEffect(() => { init({ animate, color }) }, [animate, color])
```

### Local object state: depend on primitive fields, not the object

This is easy to miss because you own the state. If your effect only reads specific fields from a state object, depend on those fields — not the whole object.

```tsx
// BAD — lastSaved is a new object after every save → effect re-runs
const [lastSaved, setLastSaved] = useState({ title: '', body: '' })
useEffect(() => {
  const timer = setTimeout(() => save(title, body), 2000)
  return () => clearTimeout(timer)
}, [title, body, lastSaved]) // lastSaved is an object — unstable

// GOOD — depend on the primitive fields you actually read
const lastSavedRef = useRef({ title: '', body: '' })
useEffect(() => {
  const timer = setTimeout(() => {
    save(title, body)
    lastSavedRef.current = { title, body }
  }, 2000)
  return () => clearTimeout(timer)
}, [title, body]) // only primitives
```

If you need to compare current state to a previous snapshot, use a ref for the snapshot — refs don't trigger re-runs.

### Do NOT narrow deps to dodge non-primitives

If your effect reads an entire array, do not depend on `.length` alone. The effect will miss content changes.

```tsx
// BAD — stale if contents change but length stays the same
useEffect(() => { items.forEach(process) }, [items.length])

// GOOD — depend on what you read
useEffect(() => { items.forEach(process) }, [items])
```

### Do NOT use JSON.stringify in deps

```tsx
// ANTIPATTERN — runs every render, breaks on non-serializable data
const stable = useMemo(() => data, [JSON.stringify(data)])
```

## Callback Props in Effects

Callback props are functions — new reference every render unless the parent uses `useCallback`. If an effect calls a callback prop, stabilize it with a ref:

```tsx
// BAD — effect re-fires every render
useEffect(() => {
  const timer = setTimeout(() => onDismiss(id), 5000)
  return () => clearTimeout(timer)
}, [id, onDismiss]) // onDismiss is unstable

// GOOD — ref-based stable wrapper
const onDismissRef = useRef(onDismiss)
onDismissRef.current = onDismiss
useEffect(() => {
  const timer = setTimeout(() => onDismissRef.current(id), 5000)
  return () => clearTimeout(timer)
}, [id]) // stable
```

If a callback is **only used in event handlers** (click, submit, etc.) and never in effects, it does not need stabilization — just call it directly. Only stabilize callbacks that appear in effect dependency arrays.

## Rules for Writing Effects

1. **Always include cleanup** for subscriptions, timers, and listeners
2. **Never lie about dependencies** — include every value the effect reads
3. **Stabilize non-primitives** — destructure objects to primitives, use refs for callbacks and snapshots, or stabilize at the source
4. **Handle race conditions** with a cleanup flag (`let ignore = false`)
5. **Use functional state updates** — `setCount(c => c + 1)` removes `count` from deps
6. **Use `useReducer`** for complex state — `dispatch` is always stable
7. **Move functions inside effects** if only used by that effect

## When useEffect IS Correct

- DOM manipulation (focus, scroll, layout measurement)
- Subscriptions (WebSocket, event listeners, Intersection Observer)
- Third-party widgets with imperative APIs
- Analytics / page view tracking
- Timers tied to component lifecycle

See `references/correct-usage.md` for patterns. See `references/modern-alternatives.md` for React 19 hooks (`use`, `useOptimistic`, `useActionState`, `useEffectEvent`).
