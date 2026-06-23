# Ranking and filtering

The point of ranking is to put the user's attention where it pays off: the events with real reach, and the tweets where a reply or a take gets seen. Use the real engagement numbers that live `bird` reads return; do not approximate from likes alone when retweets and replies are right there.

## Engagement score (for tweets)

Each tweet from `bird home` / `bird search` carries `replyCount`, `retweetCount`, `likeCount`. Combine them into one score. Weight replies and retweets above likes, because they signal active conversation and spread, which is exactly where a reply earns attention:

```
engagement = 3 * replyCount + 2 * retweetCount + 1 * likeCount
```

This is a starting heuristic, not a law. Replies are weighted highest because a tweet generating a live argument is the best place to add a voice; retweets next because reach compounds; likes are the weakest signal (cheap, passive). Adjust if the user tells you they care more about reach than conversation.

To weight by how far a reply would travel, factor in author reach (followers). Use a log so a 3M-follower account does not entirely drown a sharp 30k-follower one:

```
impact = engagement * (1 + log10(1 + author.followersCount))
```

Rank the candidate pool by `impact`, descending.

## News ranking (for events)

News items from `bird news --news-only` carry `postCount`, not per-tweet metrics. Rank events by `postCount` directly. `postCount` is the count of posts discussing the topic, so it already encodes breadth of conversation.

## Filtering the engage pool

Before ranking engage candidates, drop:

1. **Replies, not originals.** Tweets where `inReplyToStatusId` is set are tails of a thread. You want the source tweet, so the user's reply sits high in the conversation. Keep only originals.
2. **Already-replied.** Anything the user has already engaged with. Cross-check against their authored replies if available.
3. **Blocked / muted authors.** Pull `birdclaw blocks list --json` and `birdclaw mutes list --json` and exclude those handles/ids. Suggesting a reply to someone the user muted is a trust-breaker.
4. **Self.** Don't suggest the user reply to their own tweets.
5. **Low-quality noise.** Link-only tweets, engagement-bait, giveaway spam. `bird search` results can include these; a quick text heuristic (mostly-URL, "RT to win", emoji-only) is enough.

## Filtering the tweet-idea pool (Step 3)

For "what to tweet", the ranking is about fit, not raw engagement:

1. **Hot now** - the topic has momentum (`postCount`, or a dense cluster in `bird search`).
2. **In the user's lane** - derived each run from their authored history + likes + bookmarks. A hot topic the user has no standing in is not for them.
3. **Gap** - the user has not already posted about it recently. The value is the unfilled gap, not piling onto something they already covered.

Rank surviving topics by (momentum x lane-fit), and for each propose 2-3 concrete angles informed by what `bird search` shows people currently saying.

## A note on local-only fallback

If you are forced onto the local SQLite store (no live `bird`, offline), the `tweets` table has only `like_count` - no retweet or reply counts. In that case rank by `like_count * (1 + log10(1 + followers))` and SAY SO in the briefing: ranking is likes-and-reach only, retweets/replies not captured. Never present a like-only ranking as though it measured full engagement.
