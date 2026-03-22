# Should I Use useEffect?

Walk through these questions in order. Stop at the first one that matches your situation.

## Question 1: Are you computing a value from existing state or props?

Examples: filtering a list, concatenating strings, calculating totals, transforming data shapes.

**Answer: Compute it inline during render.**

```tsx
// Just compute it. No state, no effect.
const fullName = firstName + ' ' + lastName
const filtered = items.filter(i => i.active)
const total = subtotal + tax
```

If the computation is expensive (>1ms), wrap it in `useMemo`:

```tsx
const sorted = useMemo(() => [...items].sort(compareFn), [items])
```

---

## Question 2: Are you responding to a user interaction?

Examples: form submission, button click, drag action, keyboard shortcut.

**Answer: Put the logic in the event handler.**

The question to ask: did this code need to run because the user did something, or because the component appeared on screen? If the user did something, it belongs in a handler.

```tsx
function handleSubmit() {
  post('/api/contact', formData)
  showToast('Sent!')
}
```

---

## Question 3: Are you fetching data from an API?

Examples: loading a user profile, searching, paginating results.

**Answer: Use a data-fetching library or React's `use` hook.**

- TanStack Query, SWR, or your framework's data layer (Next.js Server Components, Remix loaders)
- React 19's `use` hook with Suspense for promise-based data
- If none of these are available and you must use useEffect, always handle race conditions with `let ignore = false` in the cleanup

---

## Question 4: Are you resetting component state when a prop changes?

Examples: clearing a form when switching users, resetting a player when the video ID changes.

**Answer: Use React's `key` prop.**

```tsx
<Editor key={documentId} documentId={documentId} />
```

When the key changes, React destroys and recreates the component with fresh state. No effect needed.

---

## Question 5: Are you adjusting some (not all) state when a prop changes?

Examples: clearing a selection when the item list changes, but keeping the search term.

**Answer: Derive the value instead of storing it.**

```tsx
// Instead of watching items and resetting selection:
const [selectedId, setSelectedId] = useState<string | null>(null)
const selection = items.find(i => i.id === selectedId) ?? null
// If the item is gone, selection is automatically null
```

If derivation is not possible, you can adjust state during rendering (not in an effect):

```tsx
const [prevItems, setPrevItems] = useState(items)
if (items !== prevItems) {
  setPrevItems(items)
  setSelection(null)
}
```

---

## Question 6: Are you subscribing to an external data source?

Examples: browser online/offline status, Redux store, window resize, media queries, custom event emitter.

**Answer: Use `useSyncExternalStore`.**

```tsx
const isOnline = useSyncExternalStore(
  callback => {
    window.addEventListener('online', callback)
    window.addEventListener('offline', callback)
    return () => {
      window.removeEventListener('online', callback)
      window.removeEventListener('offline', callback)
    }
  },
  () => navigator.onLine,
  () => true
)
```

If you need the subscription to change based on props (e.g., subscribing to different channels), useEffect with cleanup may be more appropriate.

---

## Question 7: Are you synchronizing with an external system?

Examples: connecting to a WebSocket, initializing a map library, managing focus, setting up an Intersection Observer, starting a timer.

**Answer: Yes, use useEffect.** This is what it is for.

```tsx
useEffect(() => {
  const connection = createConnection(roomId)
  connection.connect()
  return () => connection.disconnect()
}, [roomId])
```

Make sure to:
- Always return a cleanup function
- Include all values from the render scope in the dependency array
- Handle race conditions in async effects
- Use primitive dependencies where possible

---

## Quick Reference

| Situation | Use |
|---|---|
| Value from state/props | Inline computation or `useMemo` |
| User interaction response | Event handler |
| Data fetching | Data library, `use` hook, or framework loader |
| Reset all state on prop change | `key` prop |
| Reset some state on prop change | Derived value or state adjustment during render |
| External store subscription | `useSyncExternalStore` |
| External system synchronization | `useEffect` with cleanup |
| DOM measurement before paint | `useLayoutEffect` |
| Form submission state | `useActionState` |
| Optimistic UI updates | `useOptimistic` |
| Non-blocking async updates | `useTransition` |
| Deferred expensive renders | `useDeferredValue` |
