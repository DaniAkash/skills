# Correct useEffect Usage

useEffect is the right tool when you need to synchronize a component with an external system — something outside of React's rendering cycle. This reference covers the legitimate use cases and the patterns for writing effects correctly.

## Legitimate Use Cases

### 1. DOM Manipulation

Focus management, scroll position, and measuring elements are external system interactions.

```tsx
function AutoFocusInput() {
  const inputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    inputRef.current?.focus()
  }, [])

  return <input ref={inputRef} />
}
```

For measurements that must happen before paint (e.g., positioning a tooltip), use `useLayoutEffect`:

```tsx
function Tooltip({ targetRef, children }: TooltipProps) {
  const [position, setPosition] = useState({ top: 0, left: 0 })
  const tooltipRef = useRef<HTMLDivElement>(null)

  useLayoutEffect(() => {
    const rect = targetRef.current?.getBoundingClientRect()
    if (rect) {
      setPosition({ top: rect.bottom + 8, left: rect.left })
    }
  }, [targetRef])

  return <div ref={tooltipRef} style={position}>{children}</div>
}
```

### 2. Subscriptions and Event Listeners

Connecting to browser APIs, WebSockets, or any event source that lives outside React.

```tsx
function useOnlineStatus() {
  const [isOnline, setIsOnline] = useState(navigator.onLine)

  useEffect(() => {
    function handleOnline() { setIsOnline(true) }
    function handleOffline() { setIsOnline(false) }

    window.addEventListener('online', handleOnline)
    window.addEventListener('offline', handleOffline)

    return () => {
      window.removeEventListener('online', handleOnline)
      window.removeEventListener('offline', handleOffline)
    }
  }, [])

  return isOnline
}
```

Note: for external store subscriptions, `useSyncExternalStore` is often the better choice. See `references/modern-alternatives.md`.

### 3. Third-Party Widget Integration

Libraries with imperative APIs (maps, video players, charts) need effects to bridge between React's declarative model and the widget's imperative lifecycle.

```tsx
function MapWidget({ center, zoom }: MapProps) {
  const containerRef = useRef<HTMLDivElement>(null)
  const mapRef = useRef<MapInstance | null>(null)

  useEffect(() => {
    if (!containerRef.current) return
    const map = createMap(containerRef.current, { center, zoom })
    mapRef.current = map

    return () => { map.destroy() }
  }, []) // Create once

  // Separate effect for updating — finer-grained control
  useEffect(() => {
    mapRef.current?.setCenter(center)
  }, [center])

  useEffect(() => {
    mapRef.current?.setZoom(zoom)
  }, [zoom])

  return <div ref={containerRef} style={{ width: '100%', height: 400 }} />
}
```

### 4. Timers

Intervals and timeouts that are tied to the component's presence in the tree.

```tsx
function Timer() {
  const [elapsed, setElapsed] = useState(0)

  useEffect(() => {
    const id = setInterval(() => {
      setElapsed(e => e + 1) // functional update avoids stale closure
    }, 1000)

    return () => clearInterval(id)
  }, []) // stable because setElapsed uses functional form

  return <p>{elapsed}s</p>
}
```

### 5. Analytics and Telemetry

Page view tracking runs because the component was displayed — this is a legitimate "synchronization with an external system."

```tsx
useEffect(() => {
  analytics.trackPageView(pathname)
}, [pathname])
```

---

## Patterns for Writing Effects Correctly

### Always Clean Up

Every subscription, listener, timer, or connection must be cleaned up. React calls the cleanup function before running the effect again and when the component unmounts.

```tsx
useEffect(() => {
  const connection = createConnection(roomId)
  connection.connect()

  return () => { connection.disconnect() }
}, [roomId])
```

### Handle Race Conditions in Async Effects

Async operations inside effects can race. Use a cleanup flag to discard stale results:

```tsx
useEffect(() => {
  let ignore = false

  async function loadData() {
    const result = await fetchData(id)
    if (!ignore) {
      setData(result)
    }
  }

  loadData()

  return () => { ignore = true }
}, [id])
```

This ensures that if `id` changes rapidly, only the last fetch's result is applied.

### Use Functional State Updates

When updating state based on the previous value inside an effect, use the functional form. This removes the state variable from the dependency array and prevents stale closures:

```tsx
// BAD: count in deps causes the interval to restart every second
useEffect(() => {
  const id = setInterval(() => setCount(count + 1), 1000)
  return () => clearInterval(id)
}, [count])

// GOOD: functional update, no dependency on count
useEffect(() => {
  const id = setInterval(() => setCount(c => c + 1), 1000)
  return () => clearInterval(id)
}, [])
```

### Use Primitive Dependencies

Specify the narrowest dependency possible. Objects create new references on every render, causing unnecessary effect re-runs:

```tsx
// BAD: re-runs on any user field change
useEffect(() => {
  logActivity(user.id)
}, [user])

// GOOD: re-runs only when id changes
useEffect(() => {
  logActivity(user.id)
}, [user.id])
```

### Derive Booleans for Boundary-Based Effects

When an effect should run on a transition rather than every value change:

```tsx
// BAD: runs on width=767, 766, 765...
useEffect(() => {
  if (width < 768) enableMobileMode()
}, [width])

// GOOD: runs only when the boolean flips
const isMobile = width < 768
useEffect(() => {
  if (isMobile) enableMobileMode()
}, [isMobile])
```

### Use useReducer for Complex State in Effects

When an effect needs to update multiple related state variables, `useReducer` decouples the update logic from the effect trigger. `dispatch` is always stable, so it never needs to be in the dependency array:

```tsx
const [state, dispatch] = useReducer(reducer, initialState)

useEffect(() => {
  const id = setInterval(() => {
    dispatch({ type: 'tick' })
  }, 1000)
  return () => clearInterval(id)
}, []) // dispatch is stable
```

### Move Functions Inside Effects

If a function is only used by one effect, move it inside to make dependencies explicit:

```tsx
// BAD: fetchUrl is unstable, causes re-runs
function SearchResults({ query }: { query: string }) {
  function fetchUrl() {
    return `/api/search?q=${query}`
  }

  useEffect(() => {
    fetch(fetchUrl()).then(/* ... */)
  }, [fetchUrl]) // fetchUrl changes every render
}

// GOOD: function inside the effect
function SearchResults({ query }: { query: string }) {
  useEffect(() => {
    function fetchUrl() {
      return `/api/search?q=${query}`
    }
    fetch(fetchUrl()).then(/* ... */)
  }, [query]) // clear, minimal dependency
}
```

### App-Level Initialization

One-time app initialization should not go in useEffect without a guard, because components can remount (especially in Strict Mode):

```tsx
let didInit = false

function App() {
  useEffect(() => {
    if (didInit) return
    didInit = true

    loadFromLocalStorage()
    checkAuthToken()
  }, [])
}
```

Or move it to module level entirely:

```tsx
if (typeof window !== 'undefined') {
  checkAuthToken()
  loadFromLocalStorage()
}

function App() {
  // ...
}
```

---

## The useMountEffect Wrapper

If your team frequently needs mount-only effects for external system synchronization, a named wrapper makes intent explicit and discourages ad-hoc useEffect usage:

```tsx
function useMountEffect(effect: () => void | (() => void)) {
  useEffect(effect, [])
}
```

Use it for:
- DOM integration (focus, scroll)
- Third-party widget lifecycles
- Browser API subscriptions on mount

This is not about avoiding useEffect — it is about making mount-only synchronization a deliberate, named pattern rather than a bare `useEffect(..., [])` scattered through the codebase.
