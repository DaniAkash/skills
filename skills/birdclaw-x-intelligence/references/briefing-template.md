# Briefing template

The default deliverable is one Markdown briefing. Lead with a one-line freshness + source note so the reader knows what they are looking at. When the user asked for only one of the three parts, deliver only that section.

Keep it scannable: ranked lists, real links, one line of "why" per item. The user is going to act off this, so every engage/tweet item must be actionable on its own.

```markdown
# X briefing - <date/time>, <account handle>

_Source: For You feed + Today's News (live `bird`). Data current as of <time> (<N>h old / live)._

## What's happening

1. **<headline / event>** - <one-line why it matters>. <postCount or engagement>. <link>
2. ...
   (ranked by postCount for news items, by blended engagement for For-You items)

## Where to engage

1. **@<author>** (<followers> followers) - <one-line why it's hot: the engagement numbers>.
   - Tweet: <link>
   - Suggested angle: <how the user could add value, not pre-written final text>
2. ...
   (originals only, already-replied/blocked/muted excluded, ranked by impact)

### From your mentions
- **@<author>** - <high-signal mention worth a reply>. <link>

## What to tweet

1. **<topic>** - hot now (<why>), in your lane (<why you have standing>), you haven't posted on it.
   - Angle: <the take>
   - Drafts:
     - "<draft tweet 1>"
     - "<draft tweet 2>"
2. ...
```

## Tone and rules in the output

- State freshness honestly in the header. If the data is older than 12h and you could not refresh, say "STALE" and offer to refresh, rather than presenting old data as current.
- If you ranked on local-only data (likes + reach, no retweets/replies), note it under the relevant section.
- Suggested reply angles and draft tweets are proposals. Do not post anything. If the user approves specific text for a specific target, then act via `compose reply` / `compose post`.
- Never include auth tokens, cookies, or private DM content.
