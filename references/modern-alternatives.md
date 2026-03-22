# Modern Alternatives to useEffect

React has steadily introduced hooks and patterns that eliminate the need for useEffect in scenarios where developers previously had no other option. This reference covers each alternative, when to use it, and how it replaces an effect-based pattern.

## useSyncExternalStore — External Subscriptions

Purpose-built for subscribing to data sources outside of React (Redux stores, browser APIs, custom event emitters). Replaces the manual useEffect + useState subscription pattern.

### Before (useEffect)

```tsx
function useWindowWidth() {
  const [width, setWidth] = useState(window.innerWidth)

  useEffect(() => {
    function handleResize() { setWidth(window.innerWidth) }
    window.addEventListener('resize', handleResize)
    return () => window.removeEventListener('resize', handleResize)
  }, [])

  return width
}
```

### After (useSyncExternalStore)

```tsx
function useWindowWidth() {
  return useSyncExternalStore(
    (callback) => {
      window.addEventListener('resize', callback)
      return () => window.removeEventListener('resize', callback)
    },
    () => window.innerWidth,    // client snapshot
    () => 1024                   // server snapshot (SSR fallback)
  )
}
```

**Why it is better**: Handles tearing (concurrent rendering), works with SSR, and is less error-prone than manual subscribe/unsubscribe in effects.

---

## useMemo — Derived Values

Replaces useEffect + setState for computing values from state or props. Eliminates the double-render caused by the effect pattern.

### Before (useEffect)

```tsx
const [sorted, setSorted] = useState<Item[]>([])
useEffect(() => {
  setSorted([...items].sort(compareFn))
}, [items])
```

### After (useMemo)

```tsx
const sorted = useMemo(() => [...items].sort(compareFn), [items])
```

Use `useMemo` only when the computation is expensive (>1ms). For cheap computations, just compute inline without memoization:

```tsx
const sorted = [...items].sort(compareFn) // fine if items is small
```

Note: React Compiler can auto-memoize in many cases, reducing the need for manual `useMemo`.

---

## useCallback — Stable Function References

Replaces useEffect dependency churn caused by unstable function references. When a function prop is in an effect's dependency array, useCallback stabilizes it.

### Before (unstable callback causes effect re-runs)

```tsx
function SearchPage({ onResults }: { onResults: (r: Result[]) => void }) {
  const [query, setQuery] = useState('')

  useEffect(() => {
    fetchResults(query).then(onResults)
  }, [query, onResults]) // onResults changes every render!
}
```

### After (useCallback stabilizes the reference)

```tsx
// Parent stabilizes the callback
const handleResults = useCallback((results: Result[]) => {
  setResults(results)
}, [])

// Child effect only re-runs when query changes
useEffect(() => {
  fetchResults(query).then(onResults)
}, [query, onResults]) // onResults is now stable
```

---

## useEffectEvent — Stable Callbacks Inside Effects (Experimental)

When you need to read the latest value of a prop or state inside an effect without adding it to the dependency array. Prevents effect re-runs while avoiding stale closures.

### Before (callback in deps causes re-subscription)

```tsx
function SearchInput({ onSearch }: { onSearch: (q: string) => void }) {
  const [query, setQuery] = useState('')

  useEffect(() => {
    const timeout = setTimeout(() => onSearch(query), 300)
    return () => clearTimeout(timeout)
  }, [query, onSearch]) // re-runs when onSearch changes
}
```

### After (useEffectEvent extracts the non-reactive part)

```tsx
import { useEffectEvent } from 'react'

function SearchInput({ onSearch }: { onSearch: (q: string) => void }) {
  const [query, setQuery] = useState('')
  const onSearchEvent = useEffectEvent(onSearch)

  useEffect(() => {
    const timeout = setTimeout(() => onSearchEvent(query), 300)
    return () => clearTimeout(timeout)
  }, [query]) // only re-runs when query changes
}
```

Note: `useEffectEvent` is experimental as of React 19. Check the React docs for current status before using in production.

---

## useTransition — Non-Blocking State Updates

Replaces useEffect-based patterns for managing loading states during async operations. The `isPending` flag replaces manual `setLoading(true/false)`.

### Before (manual loading state)

```tsx
const [results, setResults] = useState<Result[]>([])
const [isLoading, setIsLoading] = useState(false)

async function handleSearch(query: string) {
  setIsLoading(true)
  const data = await fetchResults(query)
  setResults(data)
  setIsLoading(false)
}
```

### After (useTransition)

```tsx
const [results, setResults] = useState<Result[]>([])
const [isPending, startTransition] = useTransition()

async function handleSearch(query: string) {
  startTransition(async () => {
    const data = await fetchResults(query)
    setResults(data)
  })
}
// isPending is true while the transition runs — no manual management
```

---

## useDeferredValue — Deferred Expensive Renders

Replaces useEffect + setTimeout debouncing patterns for keeping input responsive while heavy rendering happens in the background.

### Before (useEffect debounce)

```tsx
const [query, setQuery] = useState('')
const [debouncedQuery, setDebouncedQuery] = useState('')

useEffect(() => {
  const timeout = setTimeout(() => setDebouncedQuery(query), 300)
  return () => clearTimeout(timeout)
}, [query])

const results = useMemo(() => expensiveFilter(items, debouncedQuery), [items, debouncedQuery])
```

### After (useDeferredValue)

```tsx
const [query, setQuery] = useState('')
const deferredQuery = useDeferredValue(query)

const results = useMemo(
  () => expensiveFilter(items, deferredQuery),
  [items, deferredQuery]
)
```

Important: `useDeferredValue` defers rendering, not network requests. For debouncing API calls, you still need a debounce utility in the event handler.

---

## use — Reading Promises During Render (React 19)

Replaces useEffect for data fetching by reading Promises during render, integrated with Suspense and Error Boundaries.

### Before (useEffect fetching)

```tsx
function UserProfile({ userId }: { userId: string }) {
  const [user, setUser] = useState<User | null>(null)

  useEffect(() => {
    let ignore = false
    fetchUser(userId).then(data => {
      if (!ignore) setUser(data)
    })
    return () => { ignore = true }
  }, [userId])

  if (!user) return <Skeleton />
  return <h1>{user.name}</h1>
}
```

### After (use with Suspense)

```tsx
// Server Component creates the promise
function UserProfilePage({ userId }: { userId: string }) {
  const userPromise = fetchUser(userId)
  return (
    <Suspense fallback={<Skeleton />}>
      <UserProfile userPromise={userPromise} />
    </Suspense>
  )
}

// Client Component reads it
'use client'
import { use } from 'react'

function UserProfile({ userPromise }: { userPromise: Promise<User> }) {
  const user = use(userPromise)
  return <h1>{user.name}</h1>
}
```

Important: Create Promises in Server Components, not Client Components. A Promise created during render in a Client Component would be recreated on every render.

---

## useOptimistic — Optimistic UI Updates (React 19)

Replaces useEffect-based patterns for optimistic updates where you show the expected result immediately while the server confirms.

### Before (manual optimistic state)

```tsx
function LikeButton({ postId, initialLiked }: Props) {
  const [liked, setLiked] = useState(initialLiked)
  const [isPending, setIsPending] = useState(false)

  async function handleClick() {
    setIsPending(true)
    setLiked(!liked) // optimistic
    try {
      await toggleLike(postId)
    } catch {
      setLiked(liked) // revert on error
    } finally {
      setIsPending(false)
    }
  }
}
```

### After (useOptimistic)

```tsx
import { useOptimistic, startTransition } from 'react'

function LikeButton({ postId, liked, onToggle }: Props) {
  const [optimisticLiked, setOptimisticLiked] = useOptimistic(liked)

  function handleClick() {
    startTransition(async () => {
      setOptimisticLiked(!optimisticLiked)
      await toggleLike(postId)
      onToggle() // parent refreshes real state
    })
  }

  return (
    <button onClick={handleClick}>
      {optimisticLiked ? 'Unlike' : 'Like'}
    </button>
  )
}
```

Automatic state convergence — no try/catch revert needed.

---

## useActionState — Form Submissions (React 19)

Replaces useEffect + useState patterns for form submission with built-in pending state and sequential action queuing.

### Before (manual form state)

```tsx
function ContactForm() {
  const [result, setResult] = useState<FormResult | null>(null)
  const [isPending, setIsPending] = useState(false)

  async function handleSubmit(formData: FormData) {
    setIsPending(true)
    const res = await submitForm(formData)
    setResult(res)
    setIsPending(false)
  }

  return <form onSubmit={handleSubmit}>...</form>
}
```

### After (useActionState)

```tsx
import { useActionState } from 'react'

function ContactForm() {
  const [result, dispatch, isPending] = useActionState(
    async (prevState: FormResult | null, formData: FormData) => {
      return await submitForm(formData)
    },
    null
  )

  return (
    <form action={dispatch}>
      {result?.error && <p>{result.error}</p>}
      <button disabled={isPending}>
        {isPending ? 'Sending...' : 'Send'}
      </button>
    </form>
  )
}
```

When passed to `<form action={...}>`, React automatically wraps submission in a Transition and manages isPending.

---

## useId — Stable Unique IDs

Replaces useEffect + useState patterns for generating unique IDs on mount (common for accessibility attributes).

### Before

```tsx
const [id, setId] = useState('')
useEffect(() => { setId(crypto.randomUUID()) }, [])
```

### After

```tsx
const id = useId() // stable, SSR-safe, no effect needed
```

---

## Summary Table

| Pattern | Replace useEffect With |
|---|---|
| Derived values from state/props | Inline computation or `useMemo` |
| External store subscription | `useSyncExternalStore` |
| Stabilizing function dependencies | `useCallback` |
| Non-reactive values in effects | `useEffectEvent` (experimental) |
| Loading states for async work | `useTransition` |
| Debouncing expensive renders | `useDeferredValue` |
| Fetching data | `use` + Suspense or data library |
| Optimistic UI | `useOptimistic` |
| Form submission state | `useActionState` |
| Generating unique IDs | `useId` |
| Resetting component state | `key` prop |
