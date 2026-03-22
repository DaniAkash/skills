# useEffect Anti-Patterns

These are the five most common misuses of useEffect, each with a detailed explanation of why it is wrong, how to recognize it, and what to do instead.

## 1. Derived State via Effects

### Why it is wrong

When you store a value in state and then "sync" it from other state via useEffect, you cause two render cycles: the first renders with stale derived values, the second renders after the effect runs and updates state. This is unnecessary work and creates opportunities for state drift if you miss a dependency.

### Smell test

- You are about to write `useEffect(() => setX(deriveFrom(y)), [y])`
- You have state that only mirrors or transforms other state or props
- Two pieces of state always change together

### Incorrect

```tsx
function ProductList({ products }: { products: Product[] }) {
  const [search, setSearch] = useState('')
  const [filtered, setFiltered] = useState<Product[]>([])

  // Two render cycles. First shows unfiltered, then filtered.
  useEffect(() => {
    setFiltered(products.filter(p => p.name.includes(search)))
  }, [products, search])

  return (
    <>
      <input value={search} onChange={e => setSearch(e.target.value)} />
      {filtered.map(p => <ProductCard key={p.id} product={p} />)}
    </>
  )
}
```

### Correct — compute inline

```tsx
function ProductList({ products }: { products: Product[] }) {
  const [search, setSearch] = useState('')

  // Single render. Always consistent.
  const filtered = products.filter(p => p.name.includes(search))

  return (
    <>
      <input value={search} onChange={e => setSearch(e.target.value)} />
      {filtered.map(p => <ProductCard key={p.id} product={p} />)}
    </>
  )
}
```

### Correct — useMemo for expensive computations

If the computation takes more than ~1ms (measure with `console.time`), wrap it in `useMemo`:

```tsx
const filtered = useMemo(
  () => products.filter(p => p.name.includes(search)),
  [products, search]
)
```

### Another common case — cascading derived state

```tsx
// BAD: effect chains for values that are just arithmetic
function Cart({ subtotal }: { subtotal: number }) {
  const [tax, setTax] = useState(0)
  const [total, setTotal] = useState(0)

  useEffect(() => { setTax(subtotal * 0.1) }, [subtotal])
  useEffect(() => { setTotal(subtotal + tax) }, [subtotal, tax])
}

// GOOD: just compute it
function Cart({ subtotal }: { subtotal: number }) {
  const tax = subtotal * 0.1
  const total = subtotal + tax
}
```

---

## 2. Data Fetching in Effects

### Why it is wrong

Raw useEffect fetching creates several problems:

- **Race conditions**: If the user navigates quickly, an older fetch may resolve after a newer one, showing stale data
- **No caching**: Every mount triggers a new network request, even for data you already have
- **No deduplication**: If multiple components fetch the same data, each one makes its own request
- **No cancellation**: When a component unmounts mid-fetch, the response is wasted (or worse, calls setState on an unmounted component)
- **Loading/error boilerplate**: You end up reimplementing caching, retry, and stale-while-revalidate from scratch

### Smell test

- Your effect does `fetch(...)` and then `setState(...)`
- You are re-implementing caching, retries, cancellation, or stale-data handling
- Multiple components independently fetch the same endpoint

### Incorrect

```tsx
function UserProfile({ userId }: { userId: string }) {
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<Error | null>(null)

  useEffect(() => {
    setLoading(true)
    setError(null)
    fetch(`/api/users/${userId}`)
      .then(r => r.json())
      .then(data => { setUser(data); setLoading(false) })
      .catch(err => { setError(err); setLoading(false) })
  }, [userId])
}
```

### Correct — use a data library

```tsx
// TanStack Query
function UserProfile({ userId }: { userId: string }) {
  const { data: user, isLoading, error } = useQuery({
    queryKey: ['user', userId],
    queryFn: () => fetch(`/api/users/${userId}`).then(r => r.json()),
  })
}

// SWR
function UserProfile({ userId }: { userId: string }) {
  const { data: user, isLoading, error } = useSWR(
    `/api/users/${userId}`,
    fetcher
  )
}
```

### Correct — use hook with Suspense (React 19)

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
function UserProfile({ userPromise }: { userPromise: Promise<User> }) {
  const user = use(userPromise)
  return <h1>{user.name}</h1>
}
```

### If you must use useEffect for fetching

When a data library is not an option, always handle race conditions with a cleanup flag:

```tsx
useEffect(() => {
  let ignore = false

  async function fetchData() {
    const response = await fetch(`/api/users/${userId}`)
    const data = await response.json()
    if (!ignore) {
      setUser(data)
    }
  }

  fetchData()
  return () => { ignore = true }
}, [userId])
```

---

## 3. Event Responses via Effects

### Why it is wrong

When a side effect is caused by a specific user action (click, submit, drag), it should run in the event handler. Modeling it as "set flag state → effect reacts" adds an indirection that:

- Makes the effect re-run on unrelated dependency changes
- Can duplicate the action (e.g., theme changes trigger the effect again)
- Makes control flow harder to trace

The key question: did this code run because the **user did something**, or because the **component was displayed**? If the user did something, use an event handler.

### Smell test

- State is used as a boolean flag so an effect can do the real action
- You are building "set flag → effect runs → reset flag" mechanics
- The effect's dependency array includes values unrelated to the core action

### Incorrect

```tsx
function LikeButton({ postId }: { postId: string }) {
  const [liked, setLiked] = useState(false)

  useEffect(() => {
    if (liked) {
      postLike(postId)
      setLiked(false) // reset the flag
    }
  }, [liked, postId])

  return <button onClick={() => setLiked(true)}>Like</button>
}
```

### Correct

```tsx
function LikeButton({ postId }: { postId: string }) {
  return <button onClick={() => postLike(postId)}>Like</button>
}
```

### Another common case — form submission

```tsx
// BAD: effect as an action relay
function ContactForm() {
  const [submitted, setSubmitted] = useState(false)
  const theme = useContext(ThemeContext)

  useEffect(() => {
    if (submitted) {
      post('/api/contact', formData)
      showToast('Sent!', theme)
    }
    // theme in deps means this re-runs on theme change!
  }, [submitted, theme])

  return <button onClick={() => setSubmitted(true)}>Send</button>
}

// GOOD: do it in the handler
function ContactForm() {
  const theme = useContext(ThemeContext)

  function handleSubmit() {
    post('/api/contact', formData)
    showToast('Sent!', theme)
  }

  return <button onClick={handleSubmit}>Send</button>
}
```

### Exception: analytics

Page view tracking IS an effect — it runs because the component was displayed, not because the user clicked something:

```tsx
useEffect(() => {
  analytics.trackPageView(pathname)
}, [pathname])
```

---

## 4. Resetting State on Prop Change

### Why it is wrong

Watching a prop in an effect and calling setState to "reset" is lifecycle thinking from class components. It causes two renders (one with stale state, one with reset state) and requires you to remember to add every piece of state you want to reset.

React has a built-in mechanism for this: the `key` prop. When a component's key changes, React destroys and recreates it, resetting all state automatically.

### Smell test

- You are writing an effect whose only job is to reset local state when an ID or prop changes
- You want the component to behave like a brand-new instance for each entity

### Incorrect

```tsx
function ChatEditor({ conversationId }: { conversationId: string }) {
  const [draft, setDraft] = useState('')
  const [attachments, setAttachments] = useState<File[]>([])

  // Must remember to reset every piece of state
  useEffect(() => {
    setDraft('')
    setAttachments([])
  }, [conversationId])

  return <textarea value={draft} onChange={e => setDraft(e.target.value)} />
}
```

### Correct — use key

```tsx
// Parent controls identity
function ChatView({ conversationId }: { conversationId: string }) {
  return <ChatEditor key={conversationId} conversationId={conversationId} />
}

// Child starts fresh every time — no effect needed
function ChatEditor({ conversationId }: { conversationId: string }) {
  const [draft, setDraft] = useState('')
  const [attachments, setAttachments] = useState<File[]>([])

  return <textarea value={draft} onChange={e => setDraft(e.target.value)} />
}
```

### Adjusting some state (not all)

If you only need to adjust one piece of state when a prop changes, and resetting everything is too aggressive, derive it instead:

```tsx
// BAD: effect to null out selection when items change
useEffect(() => { setSelection(null) }, [items])

// GOOD: derive the selection — if the item no longer exists, it is null
const [selectedId, setSelectedId] = useState<string | null>(null)
const selection = items.find(item => item.id === selectedId) ?? null
```

---

## 5. Effect Chains

### Why it is wrong

When multiple effects each set state that triggers the next effect, you get:

- **Cascading re-renders**: Each setState in the chain causes a new render cycle
- **Hard-to-trace control flow**: The logic is spread across multiple effects with temporal coupling
- **Debugging pain**: You end up asking "why did this run?" without a clear entry point
- **Fragile dependency arrays**: Adding a new piece of state to the chain requires updating multiple effects

### Smell test

- You have 3+ useEffect hooks in one component
- Effects reference state set by other effects
- You are building event-driven control flow through state + dependency arrays

### Incorrect

```tsx
function GameBoard() {
  const [card, setCard] = useState<Card | null>(null)
  const [goldCount, setGoldCount] = useState(0)
  const [round, setRound] = useState(1)
  const [isGameOver, setIsGameOver] = useState(false)

  // Chain: card → goldCount → round → isGameOver
  useEffect(() => {
    if (card?.gold) setGoldCount(c => c + 1)
  }, [card])

  useEffect(() => {
    if (goldCount > 3) { setRound(r => r + 1); setGoldCount(0) }
  }, [goldCount])

  useEffect(() => {
    if (round > 5) setIsGameOver(true)
  }, [round])

  useEffect(() => {
    if (isGameOver) alert('Good game!')
  }, [isGameOver])
}
```

Four render cycles for one card placement.

### Correct — consolidate into the event handler

```tsx
function GameBoard() {
  const [card, setCard] = useState<Card | null>(null)
  const [goldCount, setGoldCount] = useState(0)
  const [round, setRound] = useState(1)

  // Derive — no state needed
  const isGameOver = round > 5

  function handlePlaceCard(nextCard: Card) {
    setCard(nextCard)

    if (nextCard.gold) {
      if (goldCount < 3) {
        setGoldCount(goldCount + 1)
      } else {
        setGoldCount(0)
        if (round + 1 > 5) {
          alert('Good game!')
        }
        setRound(round + 1)
      }
    }
  }
}
```

Single render cycle. All logic in one traceable function. `isGameOver` is derived, not synced.
