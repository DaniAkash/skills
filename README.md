# Skills

A collection of battle-tested AI agent skills — structured knowledge that coding agents can use to write better code.

These skills are built using [skill-creator](https://github.com/anthropics/skills/tree/main/skills/skill-creator) from the Anthropic skills repo. Each skill goes through multiple rounds of eval-driven iteration: write the skill, run evaluations against real-world coding prompts, review failures, refine the rules, and repeat until the skill reliably produces correct code. This isn't a one-shot prompt — it's a tested, iterated artifact.

I ([@DaniAkash](https://github.com/DaniAkash)) use these skills daily in my own coding workflow. They exist because I kept seeing AI agents make the same mistakes, and I wanted a fix that actually sticks.

## Available Skills

| Skill | Evals | Iterations | Description |
|-------|-------|------------|-------------|
| [better-use-effect](skills/better-use-effect/SKILL.md) | 5 | 4 | Guides correct usage of React's `useEffect` hook — when to use it, when NOT to use it, and what modern alternatives exist. |

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

Point your coding agent at a skill's `SKILL.md` to load it as context. The skill provides rules, patterns, and anti-patterns that help the agent produce higher-quality code in that domain.
