---
name: birdclaw-x-intelligence
description: >
  Turn X (Twitter) into an actionable intelligence briefing using the local-first `birdclaw` CLI and its
  `bird` transport. Use this skill whenever the user wants to know what is happening on X / Twitter right
  now, what today's news is, which tweets are worth replying to, who to engage with, or what they should
  tweet about. Triggers on: "what's happening on X", "twitter digest", "what's the news on twitter today",
  "who should I reply to", "find hot tweets to engage with", "what should I tweet about", "give me a
  twitter briefing", or any request to mine X for trending events, engagement targets, or post ideas.
  Sources from the algorithmic "For You" feed and X's "Today's News", never the chronological Following
  feed. Assumes `birdclaw` is installed and already authenticated.
---

# birdclaw X Intelligence

X is a firehose. This skill turns it into three answers a creator actually needs:

1. **What is happening** - the trending and most impactful events right now.
2. **Where to engage** - the famous, hotly discussed tweets worth replying to.
3. **What to tweet** - the hot topics where the user's own post would land.

You produce a ranked, link-backed briefing. You **read and rank**; you do not post anything unless the user explicitly approves specific text.

## The tools

`birdclaw` is a local-first Twitter workspace backed by a single SQLite DB at `~/.birdclaw/birdclaw.sqlite`. It mirrors X surfaces locally, then exposes read / AI-digest / compose commands. It drives two transports, both of which you can also call directly:

- **`bird`** - GraphQL-over-cookies CLI. The rich one. Its live reads return full per-tweet engagement (`replyCount`, `retweetCount`, `likeCount`) and it can reach X's Explore tabs (`bird news`). This is your primary source for ranking and for Today's News.
- **`xurl`** - X API v2 CLI. birdclaw's other transport. You rarely need it directly.

`birdclaw digest` / `discuss` add an AI synthesis layer (OpenAI `gpt-5.5`) over the local store.

See `references/commands.md` for the exact, tested command + JSON shapes for everything below. Read it before composing a command so you use real flags, not guessed ones.

## Two non-negotiable sourcing rules

These come from how this user actually uses X. Violating them produces a briefing that looks fine and is useless.

### 1. Source from the algorithm, never the Following feed

This user does not curate who they follow. Their Following graph is noise. The signal lives in the **algorithmic "For You" feed** and **X's Explore / Today's News**, the same surfaces the user reads by hand.

- Right: `bird home` (For You feed, with engagement metrics), `bird news` (Today's News / trending), `bird search` (topic discovery), `birdclaw sync timeline --for-you` (persist For You locally).
- Wrong: `birdclaw sync timeline` with no flag (that is chronological Following), `birdclaw discuss --source home` over stale Following data, or any "top accounts I follow" framing.

If you catch yourself ranking the Following timeline, stop and re-source from For You + news.

### 2. Data must be fresh to within 12 hours

A stale briefing is worse than no briefing because it reads as current. Two cases:

- **Live `bird` reads** (`bird home`, `bird news`, `bird search`) hit X on every call, so they are always fresh. Prefer them.
- **Local-store reads** (`birdclaw digest`, `discuss --mode local`) read SQLite, which can be stale. Before trusting them, check freshness (see `references/sourcing.md`). If the relevant surface is older than 12 hours, refresh first: `birdclaw sync timeline --for-you --refresh`. Only then read.

Default posture: local-first for speed, but the 12h gate forces a refresh whenever the cache has gone cold. Never silently serve data you have not freshness-checked.

## Step 0 - Preflight (every run)

Confirm the tool is usable before doing anything. A briefing built on a dead transport is empty, not "fine".

```bash
birdclaw auth status --json   # expect installed:true and availableTransport != "none"
bird check                    # confirm the bird cookie transport is alive
```

- If auth is missing or `availableTransport` is `none`, **stop** and tell the user to authenticate (`birdclaw auth`). Do not emit an empty briefing.
- The AI passes (`birdclaw digest` / `discuss`) need `OPENAI_API_KEY`. If it is unset, those will fail. You can still deliver a full briefing from `bird` live reads plus your own synthesis. Say which path you took.

Then decide scope: a full three-part briefing, or just the one part the user asked for. Don't run work the user didn't ask for.

## Step 1 - What is happening

Goal: the trending and most impactful events, ranked, each with why-it-matters and a link.

1. **Today's News** is the spine. `bird news --news-only -n 10 --json` returns curated headlines with a `postCount` impact signal and a `category` ("AI · News", etc.). Rank by `postCount`.
2. **For You** adds what the algorithm is pushing at this user specifically: `bird home -n 50 --json`. Rank these by a blended engagement score (see `references/ranking.md`), not by like count alone.
3. **Optional AI narrative.** To get a written synthesis over the algorithm's feed, persist For You then digest it: `birdclaw sync timeline --for-you --refresh --json` then `birdclaw digest today --json`. Important: `digest` blends For-You + likes + bookmarks + mentions, so if the user's likes/bookmarks are stale the headline can skew. Treat the digest as narrative color; treat `bird news` + `bird home` as the ranked truth.

Output a "What's happening" section: each event = one-line summary, the driving accounts/headline, a representative link, and why it matters. Lead with the highest `postCount` / highest engagement items.

## Step 2 - Where to engage

Goal: famous, hotly discussed, **original** tweets the user has not already replied to, on topics where their reply gets seen.

1. Build a candidate pool from live `bird` reads (these carry the engagement metrics local SQL lacks):
   - `bird home -n 50 --json` (For You)
   - For each hot news topic from Step 1, drill in: `bird search "<topic keywords>" -n 20 --json`
2. Rank by a blended engagement score (`retweetCount` + `replyCount` + `likeCount`, reply-weighted because replies signal live conversation) crossed with author reach. See `references/ranking.md` for the formula.
3. Filter out the noise:
   - Replies, not originals (drop tweets where `inReplyToStatusId` is set) - you want to reply to source tweets, not tails.
   - Anything the user already replied to.
   - Authors in the local block / mute lists: `birdclaw blocks list --json`, `birdclaw mutes list --json`.
4. Fold in the user's own turf: `birdclaw inbox --score --hide-low-signal --kind mentions --json` surfaces high-signal mentions. Replying to those is often the highest-leverage engagement available.

Output a "Where to engage" section: each row = tweet link, author + follower reach, why it's hot (the engagement numbers), and a **suggested reply angle**. Never a posted reply, and never pre-written final text unless the user asks. Actioning is Step 4.

## Step 3 - What to tweet

Goal: hot topics where this user has standing and has not already posted, so their take adds something.

1. **Hot topics** come from `bird news --json` (and `bird trending --json`) crossed with the Step 1 themes.
2. **Derive the user's lane each run** - do not hardcode it. Infer the topics they have standing in from their own footprint:
   - Recent authored tweets: `birdclaw sync authored --json` then `birdclaw search tweets --author <handle> --since <date> --json`.
   - What they like and bookmark: `birdclaw search tweets --liked --json`, `--bookmarked --json`.
   Take the intersection of "hot right now" and "their lane".
3. **Gap check** - drop topics they have already posted about recently. The value is in the gap: a hot topic in their lane they have been silent on.
4. For each surviving topic, gauge the current angle and velocity with `bird search "<topic>" -n 20 --json` so the suggestion reacts to what people are actually saying.

Output a "What to tweet" section: each topic = why it's hot now, the user's credible angle, and 2-3 concrete draft tweet ideas. Drafts are proposals. Do not post them.

## Step 4 - Acting (only on explicit approval)

Reading and ranking is the default deliverable. Posting is a separate, deliberate act:

- Reply: `birdclaw compose reply <tweetId> "<text>"` (or `bird reply <tweetId> "<text>"`).
- Post: `birdclaw compose post "<text>"` (or `bird tweet "<text>"`).

Only run these when the user has approved the specific tweet text for that specific target. One approval is not a standing license. Read back the exact text and target before sending.

## Output: the briefing

Default deliverable is one Markdown briefing with the three sections, each ranked, each item link-backed. Use the structure in `references/briefing-template.md`. When the user asked for only one of the three, deliver only that section.

## Honesty rules (what keeps this trustworthy)

- **Rank on real numbers.** Engagement ranking comes from live `bird` reads that carry `retweetCount` / `replyCount` / `likeCount`. The local SQLite `tweets` table stores only `like_count`. If you ever fall back to local-only data, say so and say that ranking is likes-and-reach only. Never present a like-only ranking as if it captured retweets or replies.
- **Be current or be silent.** If you could not refresh and the data is older than 12h, say the briefing is stale and offer to refresh, rather than presenting old data as now.
- **Respect moderation.** Always exclude blocked and muted authors from engage / tweet suggestions.
- **Never auto-post.** Suggestions are suggestions. Posting needs explicit per-item approval.
- **No secrets.** Never surface auth tokens, cookies, or private DM content in a briefing.
- **Account scope.** Default to the user's primary account; pass `--account` only when they name another.

## Reference files

- `references/commands.md` - tested birdclaw + bird commands and their exact JSON output shapes. Read before composing any command.
- `references/sourcing.md` - For You vs Following, Today's News tabs and the news/trending quirk, the 12h freshness check (with SQL).
- `references/ranking.md` - the blended engagement score and how to filter the candidate pool.
- `references/briefing-template.md` - the exact output structure.
