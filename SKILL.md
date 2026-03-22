---
name: better-use-effect
description: Guides correct usage of React's useEffect hook — when to use it, when NOT to use it, and what modern alternatives exist. Use this skill whenever writing, reviewing, or refactoring React components that involve useEffect, side effects, data fetching, derived state, event handling, subscriptions, or any code where useEffect might be considered. Also applies when working with React hooks like useState, useMemo, useCallback, useReducer, useSyncExternalStore, useTransition, useOptimistic, useActionState, or the use hook. This skill is especially important when AI agents are generating React code, as they tend to overuse useEffect as a catch-all for anything that "needs to happen."
---

# Better useEffect

useEffect exists for one purpose: **synchronizing a component with an external system**. If you are not connecting to a browser API, a WebSocket, a third-party widget, or some other system outside of React, you almost certainly do not need useEffect.

Most useEffect usage in the wild is compensating for something React already gives you better primitives for: derived state, event handlers, data-fetching abstractions, and component identity via keys.

## The Decision Flowchart

Before writing `useEffect`, walk through this:

1. **Are you computing a value from props or state?**
   Compute it inline during render. If expensive, wrap in `useMemo`.

2. **Are you responding to a user interaction?**
   Put the logic in the event handler. Effects run because a component rendered, not because the user did something.

3. **Are you fetching data?**
   Use a data-fetching library (TanStack Query, SWR) or React's `use` hook with Suspense.

4. **Are you resetting state when a prop changes?**
   Use React's `key` prop to force a clean remount.

5. **Are you subscribing to an external data source?**
   Use `useSyncExternalStore`.

6. **Are you synchronizing with a browser API, third-party widget, or external system?**
   This is what useEffect is for. Use it with proper cleanup.

If you reached step 6, useEffect is the right tool. Otherwise, there is a better pattern.

## The Anti-Patterns

### 1. Derived State via Effects

Setting state inside an effect based on other state or props causes a double render and creates state drift.

```tsx
// BAD — two render cycles, state drift risk
const [filtered, setFiltered] = useState([])
useEffect(() => {
  setFiltered(items.filter(i => i.active))
}, [items])

// GOOD — compute inline, single render
const filtered = items.filter(i => i.active)
```

### 2. Data Fetching in Effects

Raw useEffect fetching has no cancellation, no caching, no deduplication, and race conditions when the dep changes quickly.

```tsx
// BAD — race conditions, no caching
useEffect(() => {
  fetch(`/api/user/${id}`).then(r => r.json()).then(setUser)
}, [id])

// GOOD — data library handles everything
const { data: user } = useQuery(['user', id], () => fetchUser(id))
```

### 3. Event Responses via Effects

If a side effect is caused by a user action, it belongs in the event handler, not relayed through state + effect.

```tsx
// BAD — flag relay
const [submitted, setSubmitted] = useState(false)
useEffect(() => {
  if (submitted) { postForm(); setSubmitted(false) }
}, [submitted])

// GOOD — direct
function handleSubmit() { postForm() }
```

### 4. Resetting State on Prop Change

Use React's `key` prop. When key changes, React destroys and recreates the component with fresh state.

```tsx
// BAD — manual reset, must remember every piece of state
useEffect(() => { setDraft(''); setAttachments([]) }, [noteId])

// GOOD — React handles it
<NoteEditor key={noteId} noteId={noteId} />
```

### 5. Effect Chains

Multiple effects where one sets state that triggers another. Consolidate into the event handler or derive values inline.

For detailed code examples of all anti-patterns, read `references/anti-patterns.md`.

## Non-Primitive Dependencies

When you put an object, array, or function in a dependency array, the effect re-runs on every render because React uses `Object.is` (reference comparison). A new object with the same contents is still a different reference.

```tsx
// BUG: options is a new object every render → effect runs every render
const options = { animate: true, color: 'blue' }
useEffect(() => { renderChart(options) }, [options])
```

### Fix: Stabilize at the source

The best fix is to stabilize references where they are created — in the parent.

```tsx
// Parent memoizes, child's deps array just works
function Parent() {
  const data = useMemo(() => transform(raw), [raw])
  return <Chart data={data} animate={true} color="blue" />
}
function Chart({ data, animate, color }: Props) {
  useEffect(() => { renderChart(data, { animate, color }) }, [data, animate, color])
}
```

### Fix: Destructure to primitives

When you can't control the parent, pull primitive fields out of object props.

```tsx
function Chart({ config }: { config: ChartConfig }) {
  const { animate, color } = config
  useEffect(() => { init({ animate, color }) }, [animate, color])
}
```

### Fix: Hoist constants

For truly static values, move them to module scope.

```tsx
const OPTIONS = { animate: true, color: 'blue' } as const
function Chart() {
  useEffect(() => { init(OPTIONS) }, [])
}
```

### Do NOT narrow dependencies just to avoid non-primitives

This is a critical mistake. If your effect reads an entire array or object, do not replace it with `.length` or a single property just to make the dependency primitive. The effect will become stale — it will miss changes where the contents change but the surrogate value stays the same.

```tsx
// BAD — stale! If notification contents change but length stays the same, effect is stale
useEffect(() => {
  notifications.forEach(n => scheduleTimer(n))
}, [notifications.length]) // WRONG: reads full array, depends only on length

// GOOD — if the effect reads the full array, depend on the full array
// Accept the trade-off: the effect may re-run when the parent creates a new reference
// If that's too expensive, restructure the logic or stabilize in the parent
useEffect(() => {
  notifications.forEach(n => scheduleTimer(n))
}, [notifications])
```

The dependency array must honestly reflect what the effect reads. When that creates a non-primitive dependency, the correct response is to stabilize the reference (parent memoizes, useCallback, etc.) — not to lie about what the effect depends on.

### Do NOT use JSON.stringify in deps

```tsx
// ANTIPATTERN — runs every render, breaks on non-serializable data, order-sensitive
const stableData = useMemo(() => data, [JSON.stringify(data)])
```

## Callback Props in Effects

Callback props (`onDismiss`, `onSubmit`, `onChange`) are functions — they are non-primitive and get a new reference every render unless the parent wraps them in `useCallback`. This is one of the most common sources of unnecessary effect re-runs.

**If your effect calls a callback prop, you must handle it explicitly.**

```tsx
// BAD — onDismiss is a new function every render if parent doesn't useCallback it
// This effect re-fires every render, restarting all timers
useEffect(() => {
  const timer = setTimeout(() => onDismiss(id), 5000)
  return () => clearTimeout(timer)
}, [id, onDismiss]) // onDismiss is unstable

// GOOD — use a ref to read the latest callback without adding it to deps
function useLatestCallback<T extends (...args: never[]) => unknown>(fn: T): T {
  const ref = useRef(fn)
  ref.current = fn
  return useCallback((...args: Parameters<T>) => ref.current(...args), []) as T
}

function AutoDismiss({ id, onDismiss }: Props) {
  const stableDismiss = useLatestCallback(onDismiss)
  useEffect(() => {
    const timer = setTimeout(() => stableDismiss(id), 5000)
    return () => clearTimeout(timer)
  }, [id, stableDismiss]) // stableDismiss never changes
}

// ALSO GOOD — useEffectEvent (experimental, check React docs for status)
import { useEffectEvent } from 'react'
function AutoDismiss({ id, onDismiss }: Props) {
  const handleDismiss = useEffectEvent(() => onDismiss(id))
  useEffect(() => {
    const timer = setTimeout(handleDismiss, 5000)
    return () => clearTimeout(timer)
  }, [id]) // handleDismiss is not a dependency
}

// ALSO GOOD — move the callback call into the parent's event flow
// Instead of the child auto-dismissing via a timer effect,
// the parent can own the timer logic and call its own function
```

This applies to any callback prop: `onDismiss`, `onSubmit`, `onComplete`, `onError`, `onChange`. If it appears in your effect's dependency array and you don't control the parent, stabilize it.

## When useEffect IS Correct

useEffect is the right tool for synchronizing with external systems:

- **DOM manipulation**: Focus, scroll, measuring layout (`useLayoutEffect` for pre-paint measurement)
- **Subscriptions**: WebSocket connections, browser event listeners, Intersection Observer
- **Third-party widgets**: Map libraries, video players, chart libraries with imperative APIs
- **Analytics**: Page view tracking that runs because the component was displayed
- **Timers**: Intervals and timeouts tied to the component lifecycle

For detailed patterns including cleanup, race conditions, and dependency best practices, read `references/correct-usage.md`.

## Rules for Writing Effects Correctly

1. **Always include cleanup** for subscriptions, timers, and listeners
2. **Never lie about dependencies** — include every value from the render scope that the effect reads
3. **Stabilize non-primitives** — don't put raw objects, arrays, or callback props in deps. Stabilize at the source (parent memoizes), destructure to primitives, use refs for callbacks, or accept the trade-off when the effect is cheap and idempotent
4. **Handle race conditions** in async effects with a cleanup flag (`let ignore = false`)
5. **Use functional state updates** — `setCount(c => c + 1)` removes the dependency on `count`
6. **Use `useReducer`** when multiple state variables interact inside an effect — dispatch is always stable
7. **Move functions inside effects** if they are only used by that effect
8. **Use `useEffectEvent`** (when available) to extract non-reactive logic from effects

## Modern Alternatives

React 19 introduced hooks that eliminate even more useEffect use cases. Read `references/modern-alternatives.md` for `use`, `useOptimistic`, `useActionState`, `useEffectEvent`, `useSyncExternalStore`, `useTransition`, and `useDeferredValue`.
