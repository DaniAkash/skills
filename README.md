# Skills

A collection of battle-tested AI agent skills — structured knowledge that coding agents can use to write better code.

These skills are built using [skill-creator](https://github.com/anthropics/skills/tree/main/skills/skill-creator) from the Anthropic skills repo. Each skill goes through multiple rounds of eval-driven iteration: write the skill, run evaluations against real-world coding prompts, review failures, refine the rules, and repeat until the skill reliably produces correct code. This isn't a one-shot prompt — it's a tested, iterated artifact.

I ([@DaniAkash](https://github.com/DaniAkash)) use these skills daily in my own coding workflow. They exist because I kept seeing AI agents make the same mistakes, and I wanted a fix that actually sticks.

## Available Skills

### [better-use-effect](skills/better-use-effect/SKILL.md)

Guides correct usage of React's `useEffect` hook — when to use it, when NOT to use it, and what modern alternatives exist. Covers derived state, data fetching, event handlers, subscriptions, and all the cases where `useEffect` is the wrong tool.

```bash
npx skills add DaniAkash/skills --skill better-use-effect
```

*5 evals · 4 iterations*

---

### [design-compare](skills/design-compare/SKILL.md)

Visual diff comparison between two screenshots using ImageMagick. Produces pixel-level diff highlights, side-by-side composites, blend overlays, and structured reports with numerical metrics (RMSE, AE, SSIM). Handles content-only differences using structural similarity, and guides agents through an iterative design QA loop: fix → screenshot → compare → repeat.

```bash
npx skills add DaniAkash/skills --skill design-compare
```

*4 evals · 2 iterations*

---

### [angry-reviewer](skills/angry-reviewer/SKILL.md)

Gate-keeping code review skill that channels a senior engineer on-call who has been paged at 3am one too many times. Reviews diffs with zero tolerance — asserts (never suggests), applies mandatory severity tiers (P0–P3), and outputs a structured verdict designed for use in agentic pre-merge pipelines. The reviewer always reads the entire diff before returning a verdict, surfacing every issue in a single pass.

```bash
npx skills add DaniAkash/skills --skill angry-reviewer
```

*4 evals · 1 iteration*

---

### [runtime-trace](skills/runtime-trace/SKILL.md)

Structured human-in-the-loop debugging mode for when the coding agent can't fully understand control flow from static reading. Instruments the code with prefixed `[TRACE]` log statements, hands off to the human to run the app and paste the captured output back, then uses the runtime trace to find the root cause. Trace mode is **iterative by design** — most non-trivial bugs take 2–4 rounds of narrowing the scope, and the skill pushes back hard against premature root-cause declarations. While tracing, normal rules are suspended (no commits, lint/test noise from logs is tolerated). The exit protocol cleanly separates *scaffolding* (the `[TRACE]` logs — removed) from *real work* (any code changes made during tracing — preserved), with an explicit cleanup checklist before resuming normal work.

```bash
npx skills add DaniAkash/skills --skill runtime-trace
```

*5 evals · 3 iterations*

---

### [responsiveness-audit](skills/responsiveness-audit/SKILL.md)

Audits any website for responsive design issues across all major device breakpoints using [agent-browser](https://agent-browser.dev/). Parallelizes screenshot capture across 4 device groups simultaneously, runs a 10-point layout check matrix at each breakpoint, and produces a detailed report with screenshots, severity-classified findings, layout transition analysis, and CSS fix suggestions. For authenticated pages, falls back to Chrome DevTools MCP to audit a live logged-in session.

```bash
npx skills add DaniAkash/skills --skill responsiveness-audit
```

*3 evals · 2 iterations*

---

### [birdclaw-x-intelligence](skills/birdclaw-x-intelligence/SKILL.md)

Turns X (Twitter) into an actionable intelligence briefing using the local-first [birdclaw](https://birdclaw.sh/) CLI and its `bird` transport. Answers three standing questions: what is happening right now, which tweets are worth replying to, and what to tweet about. Sources from the algorithmic "For You" feed and X's "Today's News" Explore tab (never the noisy chronological Following feed), ranks engagement from live reads that carry real reply/retweet/like counts, enforces a 12-hour freshness gate, respects local block and mute lists, and never posts without explicit approval. Every command and JSON shape in the references was tested against a live authenticated install.

```bash
npx skills add DaniAkash/skills --skill birdclaw-x-intelligence
```

*5 evals · 1 iteration*

## How Skills Are Built

Each skill follows a rigorous process powered by [skill-creator](https://github.com/anthropics/skills/tree/main/skills/skill-creator):

1. **Draft** — Write the initial skill from domain expertise and reference material
2. **Evals** — Define realistic coding prompts with specific assertions that the generated code must satisfy
3. **Run & Review** — Run evals against the skill, review where the agent gets it wrong
4. **Iterate** — Refine rules, add anti-patterns, tighten the skill based on failures
5. **Repeat** — Multiple rounds until eval pass rates are consistently high

The `evals/` directory in each skill contains the test cases used during development. You can re-run them to verify the skill works with your agent setup.

## Structure

```
skills/
└── <skill-name>/
    ├── SKILL.md        # The skill definition
    ├── references/     # Supporting reference material
    └── evals/          # Evaluation test cases
```

## Usage

Install any skill into your project with:

```bash
npx skills add DaniAkash/skills --skill <skill-name>
```

This adds the skill to your project so your coding agent automatically picks it up. The skill provides rules, patterns, and anti-patterns that guide the agent toward higher-quality code in that domain.
