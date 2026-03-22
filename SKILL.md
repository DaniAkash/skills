---
name: better-use-effect
description: Guides correct usage of React's useEffect hook — when to use it, when NOT to use it, and what modern alternatives exist. Use this skill whenever writing, reviewing, or refactoring React components that involve useEffect, side effects, data fetching, derived state, event handling, subscriptions, or any code where useEffect might be considered. Also applies when working with React hooks like useState, useMemo, useCallback, useReducer, useSyncExternalStore, useTransition, useOptimistic, useActionState, or the use hook. This skill is especially important when AI agents are generating React code, as they tend to overuse useEffect as a catch-all for anything that "needs to happen."
---

# Better useEffect

useEffect exists for one purpose: **synchronizing a component with an external system**. If you are not connecting to a browser API, a WebSocket, a third-party widget, or some other system outside of React, you almost certainly do not need useEffect.

Most useEffect usage in the wild is compensating for something React already gives you better primitives for: derived state, event handlers, data-fetching abstractions, and component identity via keys.

This matters even more when agents are writing code. useEffect is often added "just in case," but that impulse is the seed of the next race condition, infinite loop, or cascading re-render chain.

## The Decision Flowchart

Before writing `useEffect`, walk through this:

1. **Are you computing a value from props or state?**
   Do not store it in state. Do not sync it with an effect. Compute it inline during render. If it is expensive, wrap it in `useMemo`.

2. **Are you responding to a user interaction?**
   Put the logic in the event handler. Effects run because a component rendered, not because the user did something. These are different things.

3. **Are you fetching data?**
   Use a data-fetching library (TanStack Query, SWR) or React's `use` hook with Suspense. Raw useEffect fetching creates race conditions and reimplements caching badly.

4. **Are you resetting state when a prop changes?**
   Use React's `key` prop to force a clean remount. The component gets a fresh identity and all state resets automatically.

5. **Are you subscribing to an external data source?**
   Use `useSyncExternalStore`. It is purpose-built for this and handles server rendering correctly.

6. **Are you synchronizing with a browser API, third-party widget, or external system?**
   This is what useEffect is for. Use it with proper cleanup.

If you reached step 6, useEffect is the right tool. Otherwise, there is a better pattern.

## The Five Anti-Patterns

These are the most common misuses of useEffect. Each one has a better alternative. For detailed code examples of all five, read `references/anti-patterns.md`.

### 1. Derived State via Effects

Setting state inside an effect based on other state or props. This causes a double render — first with stale values, then with the "synced" values — and creates state drift when dependencies are missed.

```tsx
// Never do this
const [filtered, setFiltered] = useState([])
useEffect(() => {
  setFiltered(items.filter(i => i.active))
}, [items])

// Compute inline instead
const filtered = items.filter(i => i.active)
```

### 2. Data Fetching in Effects

Calling fetch inside useEffect without cancellation, caching, or deduplication. Every component instance runs its own fetch. Fast navigation causes race conditions where old responses overwrite new ones.

```tsx
// Fragile — race conditions, no caching
useEffect(() => {
  fetch(`/api/user/${id}`).then(r => r.json()).then(setUser)
}, [id])

// Use a data library instead
const { data: user } = useQuery(['user', id], () => fetchUser(id))
```

### 3. Event Responses via Effects

Using state as a flag so an effect can "react" to a user action. The state is a relay — the real work belongs in the handler.

```tsx
// The submitted flag is just a relay
const [submitted, setSubmitted] = useState(false)
useEffect(() => {
  if (submitted) { postForm(); setSubmitted(false) }
}, [submitted])

// Do it directly
function handleSubmit() { postForm() }
```

### 4. Resetting State on Prop Change

Watching a prop in an effect and calling setState to "reset" — this is lifecycle thinking from class components.

```tsx
// Effect resets state when userId changes
useEffect(() => { setComment('') }, [userId])

// Use key instead — React handles it
<ProfileEditor key={userId} userId={userId} />
```

### 5. Effect Chains

Multiple effects where one sets state that triggers another, creating a cascade of re-renders and hard-to-trace control flow.

Consolidate the logic into the event handler that starts the chain, or derive intermediate values inline. Read `references/anti-patterns.md` for the full pattern.

## When useEffect IS Correct

useEffect is the right tool for synchronizing with external systems. Read `references/correct-usage.md` for detailed patterns including cleanup, race condition prevention, and dependency best practices.

Legitimate uses:
- **DOM manipulation**: Focus, scroll, measuring layout (use `useLayoutEffect` if measurement must happen before paint)
- **Subscriptions**: WebSocket connections, browser event listeners, Intersection Observer
- **Third-party widgets**: Map libraries, video players, chart libraries with imperative APIs
- **Analytics**: Page view tracking, telemetry that runs because the component was displayed
- **Timers**: Intervals and timeouts tied to the component lifecycle

## Modern Alternatives Reference

React 19 introduced hooks that eliminate even more useEffect use cases. Read `references/modern-alternatives.md` for:
- `use` — read Promises during render with Suspense
- `useOptimistic` — optimistic UI without manual pending state
- `useActionState` — form submission with built-in isPending
- `useEffectEvent` — stable callbacks in effects without dependency churn
- `useSyncExternalStore` — subscribe to external stores
- `useTransition` / `useDeferredValue` — non-blocking state updates

## Critical Gotcha: Non-Primitive Dependencies

This is one of the most insidious useEffect bugs. When you put an object, array, or function in a dependency array, the effect re-runs on every render — even if the value is semantically identical — because React uses `Object.is` comparison, and non-primitives get new references on every render.

```tsx
// BUG: both data (array) and options (object) are non-primitives
// → new references every render → effect runs every render
function Chart({ data }: { data: DataPoint[] }) {
  const options = { animate: true, color: 'blue' }

  useEffect(() => {
    renderChart(data, options)
  }, [data, options]) // BOTH are new references every render
}
```

This is especially dangerous because:
- It looks correct — you included all dependencies as the linter tells you to
- It silently causes infinite re-renders or wasted work
- The bug is invisible until you hit performance issues or infinite loops
- **Props that are objects or arrays are just as dangerous** — the parent may pass a new reference on every render even if the contents haven't changed
- Inline objects, arrays, and arrow functions created during render are new references every time

### The Real Fix: Stabilize at the Source

The best fix is almost always to **stabilize references where they are created** — in the parent — rather than working around unstable references in the consumer. If the parent memoizes its data, the child's standard deps array just works.

```tsx
// PARENT: stabilize the data before passing it down
function Dashboard() {
  const data = useMemo(() => computeChartData(rawData), [rawData])
  return <Chart data={data} animate={true} color="blue" />
}

// CHILD: standard deps array works because parent provides a stable reference
function Chart({ data, animate, color }: ChartProps) {
  useEffect(() => {
    renderChart(data, { animate, color })
  }, [data, animate, color]) // data is stable from parent, animate/color are primitives
}
```

When you control the parent, this is always the cleanest solution — no refs, no tricks, no fighting the dependency system.

### When You Don't Control the Parent

If you're writing a reusable component and can't guarantee the parent will memoize:

```tsx
// Destructure object props to primitive values in the dependency array
function Chart({ config }: { config: { animate: boolean; color: string } }) {
  const { animate, color } = config
  useEffect(() => {
    renderChart({ animate, color })
  }, [animate, color]) // primitives — stable comparison
}

// For array/object props that feed an imperative API, use separate effects
function Chart({ data, animate, color }: ChartProps) {
  const chartRef = useRef<ChartInstance | null>(null)

  // Init once — animate and color captured at creation time
  useEffect(() => {
    chartRef.current = createChart({ animate, color })
    return () => { chartRef.current?.destroy() }
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  // Update data via the library's imperative API
  // data is non-primitive, so this effect may run more than needed,
  // but setData is cheap and idempotent — a reasonable trade-off
  useEffect(() => {
    chartRef.current?.setData(data)
  }, [data])
}
```

### Hoist constants outside the component

For values that are truly static, move them to module scope so they are the same reference across all renders:

```tsx
const DEFAULT_OPTIONS = { animate: true, color: 'blue' } as const

function Chart({ data }: { data: DataPoint[] }) {
  useEffect(() => {
    renderChart(data, DEFAULT_OPTIONS)
  }, [data]) // DEFAULT_OPTIONS is a module constant — always the same reference
}
```

### What NOT to do

Do not use `JSON.stringify` in dependency arrays to "stabilize" non-primitives:

```tsx
// ANTIPATTERN: JSON.stringify runs every render, breaks on non-serializable data,
// and is order-sensitive for objects
const stableData = useMemo(() => data, [JSON.stringify(data)]) // don't do this
```

**Every non-primitive in a dependency array is a potential bug.** This applies equally to objects you create inside the component AND to props passed from the parent. The parent may re-render for unrelated reasons and pass a new reference each time. The fix is to stabilize at the source, destructure to primitives, or accept the trade-off when the effect is cheap and idempotent.

The same applies to **function dependencies** — a function defined inside a component is a new reference every render. Use `useCallback` to stabilize it, move it inside the effect, or hoist it outside the component. See `references/anti-patterns.md` for detailed examples.

## Rules for Writing Effects Correctly

When you do need useEffect, follow these rules:

1. **Always include cleanup** for subscriptions, timers, and listeners
2. **Never lie about dependencies** — include every value from the render scope that the effect reads
3. **Never put non-primitive values directly in dependency arrays** — objects, arrays, and functions get new references every render. Destructure to primitives, hoist constants, or stabilize with `useMemo`/`useCallback`
4. **Handle race conditions** in async effects with a cleanup flag (`let ignore = false`)
5. **Use functional state updates** — `setCount(c => c + 1)` removes the dependency on `count`
6. **Use `useReducer`** when multiple state variables interact inside an effect — dispatch is always stable
7. **Move functions inside effects** if they are only used by that effect, to make dependencies explicit
8. **Use `useEffectEvent`** (when available) to extract non-reactive logic from effects
