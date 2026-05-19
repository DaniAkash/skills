# Trace Log Templates

Every trace log starts with `[TRACE]` and includes:
- **Location** — file name + line or function name
- **Phase** — what's happening (`enter`, `exit`, `branch`, `pre-mutation`, `post-mutation`, `await-pre`, `await-post`)
- **Safe variables only** — the minimum non-sensitive state needed to test the hypothesis

The prefix `[TRACE]` is what lets the human grep for your logs without copying unrelated noise. Don't change it. Don't pluralize it. Don't translate it.

Never print raw secrets or private user data. Do not log tokens, cookies, auth headers, passwords, API keys, session IDs, payment data, full environment objects, full request/response bodies, or personal data. Prefer booleans, counts, lengths, types, enum values, and short non-secret identifiers.

---

## JavaScript / TypeScript

### Good

```ts
console.log('[TRACE]', 'cart.ts:42', 'recalculateTotal:enter', {
  itemCount: items.length,
  totalCents: total,
});
console.log('[TRACE]', 'cart.ts:55', 'recalculateTotal:branch-empty', {
  itemCount: items.length,
});
console.log('[TRACE]', 'cart.ts:67', 'recalculateTotal:post-mutation', { newTotal });
```

For objects that don't stringify well (Maps, Sets, class instances), convert explicitly:

```ts
console.log('[TRACE]', 'cache.ts:30', 'cache:state', {
  entryCount: cache.size,
  hasEntries: cache.size > 0,
});
```

For React components, log inside the component body or inside hooks — never inside JSX:

```tsx
function Cart({ items }: Props) {
  console.log('[TRACE]', 'Cart.tsx', 'render', { itemCount: items.length });

  useEffect(() => {
    console.log('[TRACE]', 'Cart.tsx', 'effect:items-changed', { itemCount: items.length });
  }, [items]);
  // ...
}
```

### Bad

```ts
console.log(items, total);                    // No prefix — lost in console noise
console.log('debug:', items);                 // Wrong prefix — won't grep
console.log('[TRACE]', items);                // No location — useless once you have 20 of these
console.log(`[TRACE] ${items}`);              // Template-stringified object becomes "[object Object]"
```

---

## Python

### Good

```python
print('[TRACE]', 'cart.py:42', 'recalculate_total:enter', {'item_count': len(items), 'total_cents': total})
print('[TRACE]', 'cart.py:55', 'recalculate_total:branch-empty', {'item_count': len(items)})
print('[TRACE]', 'cart.py:67', 'recalculate_total:post-mutation', {'new_total': new_total})
```

If the project uses a logger, prefer it over `print` (output buffering, log levels):

```python
import logging
log = logging.getLogger(__name__)
log.info('[TRACE] cart.py:42 recalculate_total:enter %s', {'items': items, 'total': total})
```

For dataclasses, use `dataclasses.asdict()` so you see the fields, not just the repr:

```python
from dataclasses import asdict
print('[TRACE]', 'orders.py:88', 'order:state', {'status': order.status, 'item_count': len(order.items)})
```

### Bad

```python
print(items, total)                # No prefix
print('TRACE:', items)             # Inconsistent — the protocol is `[TRACE]`
print(f'[TRACE] items={items}')    # f-string of a list of objects loses field detail
```

---

## Go

### Good

```go
fmt.Printf("[TRACE] cart.go:42 RecalculateTotal:enter itemCount=%d total=%v\n", len(items), total)
fmt.Printf("[TRACE] cart.go:67 RecalculateTotal:post-mutation newTotal=%v\n", newTotal)
```

Use `%+v` for structs (prints field names, not just values). For maps with non-deterministic iteration order, sort keys before printing if order matters.

If you have a logger:

```go
log.Printf("[TRACE] cart.go:42 RecalculateTotal:enter items=%+v total=%v", items, total)
```

### Bad

```go
fmt.Println(items, total)            // No prefix, no field names
fmt.Printf("[TRACE] %v\n", items)    // %v on a struct hides field names
```

---

## Rust

### Good

```rust
println!("[TRACE] cart.rs:42 recalculate_total:enter item_count={} total={}", items.len(), total);
println!("[TRACE] cart.rs:67 recalculate_total:post-mutation new_total={}", new_total);
```

Use `{:#?}` (pretty-print Debug) for complex types — requires `#[derive(Debug)]`. If a type isn't Debug-printable, derive it temporarily for the trace.

If using `tracing` or `log`:

```rust
tracing::info!("[TRACE] cart.rs:42 recalculate_total:enter items={:?} total={}", items, total);
```

### Bad

```rust
println!("[TRACE] {}", items);       // Display might not be implemented; `{:?}` is what you want
println!("{:?}", items);             // No prefix, no location
```

---

## Shell scripts

For shell, write to stderr so trace output doesn't pollute pipelines:

```bash
echo "[TRACE] deploy.sh:line:$LINENO step=build env_name=$ENV_NAME target=$TARGET" >&2
```

For multi-variable dumps:

```bash
echo "[TRACE] deploy.sh:$LINENO state: env_name=$ENV_NAME branch=$BRANCH build_id=$BUILD_ID" >&2
```

---

## Universal rules

1. **Always prefix with `[TRACE]`** — exact spelling, exact bracket style. The human will grep for this literal string.
2. **Always include location** — file name plus line or function name. Without this, a 50-line trace is unreadable.
3. **Log derived, non-sensitive values** — counts, booleans, lengths, types, statuses, and non-secret IDs beat raw objects.
4. **Don't log inside hot loops without a counter** — if you log inside a 10,000-iteration loop, the human gets 10,000 lines and you get nothing useful. Log every Nth iteration or only the final state.
5. **Don't log secrets or PII** — even in a trace, even temporarily. Use placeholders or only log lengths/types.
