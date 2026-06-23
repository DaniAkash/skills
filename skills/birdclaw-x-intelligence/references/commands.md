# Tested commands and JSON shapes

Every command here was run live against a real authenticated install (birdclaw 0.8.5, bird 0.8.0) and the shapes are what they actually returned. Prefer these exact invocations over guessing flags. Add `--json` for machine-readable output; pipe through `python3 -c` or `jq` to rank.

## Table of contents

- [Preflight](#preflight)
- [Sourcing: For You feed](#sourcing-for-you-feed)
- [Sourcing: Today's News / trending](#sourcing-todays-news--trending)
- [Sourcing: topic search](#sourcing-topic-search)
- [Persisting For You into birdclaw](#persisting-for-you-into-birdclaw)
- [AI synthesis: digest and discuss](#ai-synthesis-digest-and-discuss)
- [Triage: inbox and mentions](#triage-inbox-and-mentions)
- [Moderation lists](#moderation-lists)
- [Acting: compose](#acting-compose)

## Preflight

```bash
birdclaw auth status --json
# -> { installed:true, availableTransport:"xurl"|"bird"|..., statusText, rawStatus }
bird check
# -> confirms the cookie transport has live credentials
birdclaw db stats --json
# -> { paths, stats:{ home, mentions, dms, needsReply, inbox }, transport }
```

Stop the run if `installed` is false or `availableTransport` is `"none"`.

## Sourcing: For You feed

The algorithmic feed, WITH engagement metrics. This is the workhorse for "what's happening" and "where to engage".

```bash
bird home -n 50 --json
```

Returns a JSON array of tweets, each:

```json
{
  "id": "<tweet-id>",
  "text": "...",
  "createdAt": "2026-06-23T05:45:52.000Z",
  "replyCount": 12,
  "retweetCount": 48,
  "likeCount": 310,
  "conversationId": "<conversation-id>",
  "author": { "handle": "...", "name": "...", "followersCount": "(often absent)" },
  "authorId": "<author-id>",
  "quotedTweet": { ... }
}
```

`--following` switches to the chronological Following feed. Do NOT use it for this skill; the user's Following graph is noise.

## Sourcing: Today's News / trending

X's Explore tabs, AI-curated. This is the user's beloved "Today's News".

```bash
bird news --news-only -n 10 --json
```

Returns a JSON array of news items:

```json
{
  "id": "twitter://trending/<trend-id>",
  "headline": "Example Headline About a Dev Tool Launch",
  "category": "AI · News",
  "timeAgo": "12 hours ago",
  "postCount": 691,
  "url": "twitter://trending/...",
  "tweets": []
}
```

Rank News items by `postCount` (how many posts discuss the topic = impact).

**Tabs:** `--news-only`, `--trending-only`, `--sports`, `--entertainment`, `--for-you`, `--ai-only`. For this user, `--news-only` (and optionally `--ai-only`) is the core; `--trending-only` is a useful secondary.

**Tested quirk - related tweets:** `--with-tweets --tweets-per-item N` attaches tweets, but they populate only for **Trending** items, not **News** items. News items return `postCount` and an empty `tweets: []`. So to get specific tweets for a news headline, do NOT rely on `--with-tweets`; instead feed the headline keywords into `bird search` (below), which returns full engagement metrics.

## Sourcing: topic search

Live keyword search, same rich engagement shape as `bird home`. This is how you turn a hot topic into specific tweets to engage with.

```bash
bird search "AI agents" -n 20 --json
# -> [ { id, text, createdAt, replyCount, retweetCount, likeCount,
#        conversationId, inReplyToStatusId, author, authorId }, ... ]
```

`inReplyToStatusId` is present here: use it to keep originals only (drop rows where it is set).

birdclaw also has `birdclaw discuss "<query>" --source search` which wraps live search + AI summary, but `discuss` REQUIRES a non-empty query (empty string errors with "Search query is required"). Use `discuss` when you want a synthesized take on a topic; use `bird search` when you want the raw ranked tweets.

## Persisting For You into birdclaw

To let the AI digest synthesize over the algorithm's feed (not Following), persist For You into the local store first:

```bash
birdclaw sync timeline --for-you --refresh --limit 50 --json
# -> { ok:true, source:"bird", kind:"timeline", feed:"for-you", count:50,
#      payload:{ data:[ { id, author_id, text, created_at, conversation_id, public_metrics, ... } ] } }
```

`--for-you` is the critical flag (the published docs lag the binary and omit it; the installed v0.8.5 has it). Default `--max-pages 3`, `--cache-ttl 120` seconds. `--refresh` bypasses the live cache.

## AI synthesis: digest and discuss

Both stream Markdown by default; add `--json` for the final structured envelope. Both need `OPENAI_API_KEY`. Both cache by context hash (re-runs return `cached:true`; `--refresh` busts).

```bash
birdclaw digest today --json --max-tweets 5000 --max-links 12
```

Returns:

```json
{
  "context": { "window":{...}, "counts":{ "home","mentions","authored","likes","bookmarks","dms","links" }, "tweets":[...], "links":[...], "hash":"..." },
  "digest": { "title", "summary", "keyTopics":[...], "notableLinks":[...], "people":[{ "handle","name","why" }], "actionItems":[...], "sourceTweetIds":[...] },
  "markdown": "...", "model":"gpt-5.5", "cached":false
}
```

`digest` periods: `today`, `24h`, `yesterday`, `week`. It BLENDS home + likes + bookmarks + mentions + authored within the window, so stale likes/bookmarks can skew the headline. Use it for narrative color, not for ranking.

```bash
birdclaw discuss "local-first" --source home --mode local --hide-low-quality \
  --question "Which tweets are most impactful and worth replying to? Give author + one-line why." --json
```

Returns:

```json
{
  "context": { "query","question","source","counts","tweets":[...],"hash" },
  "discussion": { "title","summary","themes":[...],"tensions":[...],"followUps":[...],"sourceTweetIds":[...] },
  "markdown":"...", "model":"gpt-5.5"
}
```

`--mode local` keeps it offline (reads the local store, no live fetch). `--source` ∈ all, search, home, mentions, authored, likes, bookmarks.

## Triage: inbox and mentions

```bash
birdclaw inbox --score --hide-low-signal --kind mentions --limit 10 --json
# -> { items:[ { id, entityKind, text, createdAt, needsReply, influenceScore,
#               participant:{ handle, followersCount, ... }, score, summary, reasoning } ] }
```

`--score` adds OpenAI 0-100 actionability scores (needs `OPENAI_API_KEY`); `--min-score <n>` filters. `--kind` ∈ mentions, dms, mixed.

```bash
birdclaw mentions export "<query>" --unreplied --limit 10
# -> mention tweets rendered as plaintext + markdown + metadata (always JSON)
```

## Moderation lists

Always exclude these authors from engage / tweet suggestions.

```bash
birdclaw blocks list --json
birdclaw mutes list --json
```

## Acting: compose

Only on explicit per-item approval of the exact text.

```bash
birdclaw compose reply <tweetId> "<text>"
birdclaw compose post "<text>"
# bird equivalents:
bird reply <tweetId> "<text>"
bird tweet "<text>"
```
