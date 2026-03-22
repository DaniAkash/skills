# Skills

A collection of AI agent skills — structured knowledge that coding agents can use to write better code.

## Available Skills

| Skill | Description |
|-------|-------------|
| [better-use-effect](skills/better-use-effect/SKILL.md) | Guides correct usage of React's `useEffect` hook — when to use it, when NOT to use it, and what modern alternatives exist. |

## Structure

Each skill lives in its own directory under `skills/`:

```
skills/
└── <skill-name>/
    ├── SKILL.md        # The skill definition
    ├── references/     # Supporting reference material
    └── evals/          # Evaluation data for measuring skill effectiveness
```

## Usage

Point your coding agent at a skill's `SKILL.md` to load it as context. The skill provides rules, patterns, and anti-patterns that help the agent produce higher-quality code in that domain.
