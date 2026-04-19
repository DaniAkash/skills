# Severity Tiers Reference

## Decision Rule

When in doubt between two tiers, ask: **"Will this definitely be hit under real production traffic?"**

- Definitely yes + causes data loss, outage, or security breach → **P0**
- Definitely yes + causes failures or broken behavior → **P1**
- Probably yes under edge cases → **P2**
- Unlikely, or just ugly → **P3**

If you're stuck between P0 and P1: does this cause **data loss or a security breach** in normal operation? If yes, P0. If it just crashes or misbehaves, P1.

---

## P0 — BLOCKER

**Hard block. Do not merge under any circumstances.**

The change will cause data loss, a production outage, a security breach, or silent data corruption once it hits real traffic — not "could in theory," but "will."

**Examples:**
- Raw string interpolation in a SQL query → SQL injection
- Writing unencrypted PII to logs
- Deleting rows without a WHERE clause
- Overwriting a file at a path derived from user input without sanitization
- Auth middleware removed or bypassed on a protected route
- A migration with `DROP TABLE` and no rollback

**Common mis-tagging:** Don't tag P0 just because something is in the auth path. If an auth check is wrong but requires a very specific attack vector to exploit, it's P1. P0 is for things that will blow up on their own.

---

## P1 — CRITICAL

**Block until fixed.**

The change will cause failures under real traffic — not speculative, but definitely going to happen. Broken auth logic, error paths that will be hit, race conditions on any contended resource.

**Examples:**
- Missing `await` on a DB write inside a transaction (silent no-op, data never saved)
- Unhandled promise rejection that crashes a Node process
- Auth check that returns `true` for the wrong condition
- Race condition on a shared counter with concurrent requests
- External API call with no error handling in a hot path

**Common mis-tagging:** P1 is for things that will break under real usage, not things that might break under unusual usage. If it requires a very specific timing window or unusual input to trigger, consider P2.

---

## P2 — MAJOR

**Should fix before merge.**

The change introduces a meaningful regression or logic error that will degrade production quality — not a showstopper, but something real users will feel.

**Examples:**
- N+1 query on a list endpoint that will slow down under any real data volume
- Missing pagination — endpoint returns all rows, will OOM at scale
- Error is caught and logged but the caller gets a success response
- Off-by-one that produces wrong results in a non-obvious edge case
- Synchronous file I/O in a request handler

**Common mis-tagging:** P2 is not a dumping ground for "things I don't like." It requires a concrete scenario where users are harmed.

---

## P3 — MINOR

**Note it, ship at your own risk.**

Code smell, weak naming, missing types, inconsistent style, minor readability issues. Won't cause a production problem, but will make the next person's life harder.

**Examples:**
- Variable named `data` or `temp` with no indication of what it holds
- Missing TypeScript types on a public function signature
- Inconsistent error message formatting vs the rest of the codebase
- Magic number with no explanation
- Dead code left in the diff

**Note:** P3s should be listed but never block a merge. If there are many P3s and no higher severity issues, verdict is still `APPROVED WITH CONCERNS` only if there's at least one P2.
