# Review Checklist — Annotated Examples

Each category below includes an annotated bad-code snippet showing exactly what to look for in a diff.

---

## Correctness

**Off-by-one / wrong operator**
```diff
- if (index > items.length) {
+ if (index >= items.length) {
```
The original accesses `items[items.length]` — undefined. Tag P1 if this is in a hot path, P2 otherwise.

**Nullable assumption**
```ts
// BAD — user can be null if the session expired
const name = user.profile.displayName;
```
Tag P1 if this crashes the server, P2 if it's client-only.

**Wrong boolean logic**
```ts
// BAD — De Morgan violation: should be (!a || !b)
if (!a && !b) { block() }
// Should be: if (!a || !b) { block() }
```

---

## Async / Concurrency

**Missing await**
```ts
// BAD — fire-and-forget, caller never knows if this failed
async function saveUser(user: User) {
  db.users.insert(user);  // ← missing await
  return { ok: true };
}
```
Tag P0 if inside a transaction (data silently not saved). Tag P1 otherwise.

**Unhandled promise rejection**
```ts
// BAD — if fetchUser throws, the process crashes (Node) or silently fails (browser)
useEffect(() => {
  fetchUser(id).then(setUser);
}, [id]);
```

**Race condition**
```ts
// BAD — two concurrent requests can both read count=5, both write count=6
const count = await db.get('counter');
await db.set('counter', count + 1);
```

---

## Error Handling

**Swallowed error**
```ts
// BAD — caller gets undefined, has no idea why
try {
  return await parseConfig(raw);
} catch (e) {
  console.error(e);
  // no return, no rethrow
}
```

**Success response on failure**
```ts
// BAD — returns 200 even when the external call failed
try {
  await emailService.send(payload);
} catch (e) {
  logger.warn('email failed', e);
}
res.json({ sent: true }); // ← lies
```

---

## Security

**SQL injection**
```ts
// BAD — textbook injection vector
const rows = await db.query(
  `SELECT * FROM users WHERE email = '${req.body.email}'`
);
```
Always P0. Fix: parameterized query.

**Sensitive data in logs**
```ts
// BAD — JWT in plaintext log
logger.info('Auth token', { token: req.headers.authorization });
```
P0 — rotate keys immediately after merge.

**Missing auth check**
```ts
// BAD — route handler with no middleware guard
router.delete('/admin/users/:id', async (req, res) => {
  await db.users.delete(req.params.id);
});
```

---

## Data Integrity

**Missing transaction**
```ts
// BAD — if the second write fails, you have an order with no payment record
await db.orders.insert(order);
await db.payments.insert(payment); // if this throws, order exists with no payment
```
P0 — wrap both in a transaction.

**Unbounded delete**
```ts
// BAD — no WHERE clause
await db.query('DELETE FROM sessions');
```
P0.

---

## Performance

**N+1 query**
```ts
// BAD — one query per user in the list
const users = await db.users.findAll();
for (const user of users) {
  user.posts = await db.posts.findByUserId(user.id); // N queries
}
```
P2 for small datasets, P1 if this endpoint is called frequently.

**Missing pagination**
```ts
// BAD — returns every row; will OOM at scale
const allEvents = await db.events.findAll();
res.json(allEvents);
```

---

## Operational Safety

**Hardcoded secret**
```ts
// BAD — literal API key in source
const client = new StripeClient('sk_live_abc123xyz...');
```
P0 — key is now compromised. Rotate immediately.

**Irreversible migration**
```sql
-- BAD — no rollback path
ALTER TABLE users DROP COLUMN legacy_id;
```
P1 if `legacy_id` is still read anywhere in the codebase. P2 if confirmed unused but no down-migration exists.

**No observability on critical path**
```ts
// BAD — payment processing with no logging
async function chargeCard(customerId: string, amount: number) {
  return stripe.charges.create({ customer: customerId, amount });
  // no logging, no metrics, no alerting
}
```
P2 — you will not know when this starts failing.
