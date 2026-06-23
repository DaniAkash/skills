# Sourcing and freshness

## Why For You, not Following

This user relies on X's algorithm to surface the right content. They do not curate their Following graph, so the chronological Following feed is mostly noise to them. Sourcing from Following would produce a briefing about accounts the user does not care about. Always source from the surfaces the user actually reads:

| Surface | Command | Carries engagement metrics? | Use for |
|---|---|---|---|
| For You feed | `bird home -n 50 --json` | Yes (reply/retweet/like) | what's happening, engage candidates |
| Today's News | `bird news --news-only -n 10 --json` | `postCount` per item | what's happening (the spine) |
| Topic search | `bird search "<topic>" -n 20 --json` | Yes | drilling a topic into engage targets / tweet angles |
| For You (persisted) | `birdclaw sync timeline --for-you --refresh` | in raw `public_metrics` | feeding the AI digest over the algorithm |

`bird home --following` and a bare `birdclaw sync timeline` (no `--for-you`) both pull the chronological Following feed. Neither belongs in this skill.

## Today's News tabs and the related-tweets quirk

`bird news` reaches the Explore tabs. Flags select the tab:

- `--news-only` - the core "Today's News" headlines. Each item has `postCount` (impact) and `category`.
- `--ai-only` - only AI-curated items.
- `--trending-only` - trending topics. These DO return related tweets with `--with-tweets`.
- `--sports`, `--entertainment` - niche tabs, usually skip for this user.

Tested behavior worth remembering: `--with-tweets --tweets-per-item N` only attaches tweets to **Trending** items. **News** items come back with `postCount` but `tweets: []`. So the reliable pipeline for "news headline -> tweets to engage with" is:

```
bird news --news-only --json   # get headlines + postCount
# then for a chosen headline:
bird search "<headline keywords>" -n 20 --json   # get the actual tweets, with engagement
```

## The 12-hour freshness gate

A stale briefing reads as current and misleads. Enforce freshness:

- **Live `bird` reads are always fresh.** `bird home`, `bird news`, `bird search` hit X on every call. When you build the briefing from these, you are current by construction. This is the preferred path.
- **Local-store reads can be stale.** `birdclaw digest` and `birdclaw discuss --mode local` read SQLite. Check the age of the For-You data before trusting them.

### How to check freshness

Newest For-You tweet in the local store vs now:

```bash
sqlite3 ~/.birdclaw/birdclaw.sqlite \
  "select max(created_at) as newest, datetime('now') as now_utc
   from tweets t join tweet_account_edges e on e.tweet_id=t.id
   where e.kind='home';"
```

Or the last sync timestamp from the cache table:

```bash
sqlite3 ~/.birdclaw/birdclaw.sqlite \
  "select cache_key, updated_at from sync_cache order by updated_at desc limit 5;"
```

If `newest` (or the relevant `updated_at`) is more than 12 hours before now, refresh before reading:

```bash
birdclaw sync timeline --for-you --refresh --limit 50 --json
# add likes / bookmarks / mentions only if the goal needs them:
birdclaw sync likes --early-stop --max-pages 3 --json
birdclaw sync bookmarks --early-stop --max-pages 3 --json
birdclaw sync mentions --limit 50 --refresh --json
```

Do not depend on `~/.birdclaw/audit/` for freshness; that directory only exists once `birdclaw jobs` are installed. Use `max(created_at)` and `sync_cache` instead.

### Default posture

Local-first for speed, with the 12h gate as a hard backstop. In practice: if the user wants a fast read and the cache is warm (< 12h), read local. If the cache is cold, or the user wants the freshest possible picture, go straight to live `bird` reads. Either way, never serve data you have not freshness-checked, and say which path you took.
