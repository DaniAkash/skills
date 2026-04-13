---
name: responsiveness-audit
description: "Audit any website for responsiveness across all major device breakpoints using agent-browser. Use this skill whenever you need to check if a site is mobile-friendly, find layout breaks at specific viewport widths, audit responsive design quality, test across device sizes, or generate a responsiveness report with screenshots. Trigger with 'audit responsiveness', 'check if site is responsive', 'mobile test', 'responsiveness audit', 'responsive design check', 'breakpoint test', 'test at mobile', 'is this site responsive', 'check viewport', or whenever you need to identify what layout issues exist at different screen sizes."
compatibility: claude-code-only
---

# Audit Responsiveness

Audit any website for responsive design issues across all major device breakpoints. Takes screenshots at each viewport, runs a structured layout check matrix, and produces a detailed report with per-breakpoint findings, CSS fix suggestions, and actionable prioritization.

## Prerequisites: agent-browser

This skill requires `agent-browser` — a browser automation CLI built for AI agents.

**Check if installed:**

```bash
agent-browser --version
```

**If not installed**, stop and inform the user:

> `agent-browser` is required for this skill. Install it with one of these methods:
>
> ```bash
> # npm (all platforms)
> npm install -g agent-browser
> agent-browser install   # download Chrome (first time only)
>
> # Homebrew (macOS)
> brew install agent-browser
> agent-browser install
>
> # Or try without installing
> npx agent-browser install
> npx agent-browser open example.com
> ```
>
> Full installation guide: https://agent-browser.dev/installation

Do NOT attempt to install agent-browser automatically. Ask the user to install it and confirm before continuing.

## Auditing a Logged-In Page

For pages that require authentication (dashboards, settings, profile pages), use the **Chrome DevTools MCP** to connect to an existing authenticated browser session instead of agent-browser.

See `references/chrome-devtools-auth.md` for the full workflow. Key steps:
1. Ask the user to open the page in their browser and stay logged in
2. Use `mcp__chrome-devtools__*` tools to connect to that session
3. Use `mcp__chrome-devtools__resize_page` to test each breakpoint
4. Use `mcp__chrome-devtools__take_screenshot` for evidence

## Operating Modes

### Mode 1: Standard Audit (default)
Test 8 key breakpoints: **320px, 375px, 768px, 1024px, 1280px, 1440px, 1920px, 2560px**

Use this for a comprehensive audit covering all major device categories.

### Mode 2: Quick Mobile Check
Test 3 breakpoints: **320px, 375px, 768px**

Use when the user only wants to check mobile responsiveness quickly.

### Mode 3: Targeted Range
User-specified start/end widths at 80px increments.

Use when the user says "check between 768px and 1280px" or similar.

### Multi-URL
If the user provides multiple URLs, run parallel audits — one sub-agent per URL.

## Parallelization Strategy

**Always parallelize** — launch 4 sub-agents simultaneously, one per device group. Each agent opens a fresh session and tests its assigned breakpoints.

| Agent | Breakpoints | Device Category |
|-------|-------------|----------------|
| Agent 1 | 320px, 375px | Mobile (small + standard) |
| Agent 2 | 768px, 1024px | Tablet |
| Agent 3 | 1280px, 1440px | Desktop |
| Agent 4 | 1920px, 2560px | Large / Ultra-wide |

Each sub-agent workflow:
1. `agent-browser open <url> --session <agent-N>` — open in named session
2. `agent-browser set viewport <width> 900 --session <agent-N>` — set viewport
3. `agent-browser screenshot <output-path> --full-page --session <agent-N>` — capture full page
4. Inspect accessibility tree and DOM for issues
5. Repeat for each assigned breakpoint
6. `agent-browser close --session <agent-N>` — close session when done

After all 4 agents complete, merge findings into a single report.

## agent-browser Core Commands

```bash
# Open a URL in a named session
agent-browser open <url> --session audit-mobile

# Set the viewport size
agent-browser set viewport 375 900 --session audit-mobile

# Take a full-page screenshot (captures entire page, not just the visible viewport)
agent-browser screenshot ~/workbench/screenshots/<org>/<repo>/mobile-375.png --full-page --session audit-mobile

# Get an accessibility snapshot (detect overflow, missing labels, etc.)
agent-browser snapshot --session audit-mobile

# Check for horizontal scroll (inject script)
agent-browser eval "document.documentElement.scrollWidth > document.documentElement.clientWidth" --session audit-mobile

# Get computed styles for an element
agent-browser eval "getComputedStyle(document.querySelector('nav')).display" --session audit-mobile

# Close the session
agent-browser close --session audit-mobile
```

See `references/breakpoints.md` for the full device/breakpoint reference.

## Layout Check Matrix

Run ALL 10 checks at EVERY breakpoint. Record pass/warn/fail for each.

| # | Check | How to Detect |
|---|-------|---------------|
| 1 | **Horizontal overflow** | `document.documentElement.scrollWidth > document.documentElement.clientWidth` → any positive result = fail |
| 2 | **Text overflow / clipping** | Look for truncated text, text running off-screen, or overlapping elements in screenshot |
| 3 | **Navigation transition** | Is hamburger menu present at mobile? Does desktop nav collapse properly? |
| 4 | **Content stacking** | Multi-column layout should stack vertically on mobile |
| 5 | **Image / media scaling** | Images should not exceed their container width |
| 6 | **Touch targets (mobile only)** | Interactive elements should be ≥ 44px tall on ≤768px viewports |
| 7 | **Whitespace balance** | Check for excessive padding/margins making content too cramped or too spread |
| 8 | **CTA above fold** | Primary call-to-action should be visible without scrolling |
| 9 | **Font readability** | Body text should be ≥ 14px at all breakpoints |
| 10 | **Z-index / overlap issues** | Elements overlapping each other unexpectedly (sticky headers, modals, tooltips) |

## Severity Classification

| Severity | Definition |
|----------|-----------|
| **Critical** | Page is unusable at this breakpoint — content cut off, unreadable, overflow, broken layout |
| **High** | Key functionality impaired — nav broken, CTA hidden, text unreadable |
| **Medium** | User experience degraded — spacing off, minor overflow, poor stacking |
| **Low** | Cosmetic — minor whitespace imbalance, slight misalignment |

## Screenshot Storage

Save all screenshots to `~/workbench/screenshots/<Owner>/<Repo>/responsiveness-audit/` following the project conventions. If auditing a public URL with no associated repo, use a descriptive folder name derived from the domain.

Naming: `<breakpoint>px-<description>.png` (e.g. `375px-homepage.png`, `768px-homepage.png`)

## Report Output

Write the final report to `docs/responsiveness-audit-YYYY-MM-DD.md` in the project directory, or output inline if there is no associated project.

See `references/report-template.md` for the full report structure.

## Audit Workflow

```
1. Check agent-browser is installed (or Chrome DevTools MCP for auth pages)
2. Determine operating mode and URL(s)
3. Launch 4 parallel sub-agents (one per device group)
4. Each agent: open URL → set viewport → full-page screenshot → run check matrix → close session
5. Collect all findings from all agents
6. Identify layout transitions (exact px where layout breaks)
7. Group issues by severity
8. Generate CSS fix suggestions for each issue
9. Write report with screenshots, findings, and recommendations
10. Close any remaining open agent-browser sessions
```

## Session Cleanup

Always close every agent-browser session after the audit is complete. Leaving sessions open wastes memory and can interfere with future browser automation tasks.

After writing the report, run:

```bash
# Close each named session used during the audit
agent-browser close --session audit-mobile
agent-browser close --session audit-tablet
agent-browser close --session audit-desktop
agent-browser close --session audit-large

# Or close all sessions at once
agent-browser close --all
```

If a session was already closed by a sub-agent, `agent-browser close` on a non-existent session is safe — it will simply report that the session wasn't found.

## Layout Transition Detection

Report the exact pixel width range where major transitions occur:

- Column count changes (3-col → 2-col → 1-col)
- Navigation mode switches (horizontal nav → hamburger)
- Sidebar appears / disappears
- Hero image switches from landscape to portrait
- Grid reflows

Format: `Transition at ~768px: horizontal nav → hamburger menu`

## CSS Fix Suggestions

For each finding, suggest a concrete CSS fix. Examples:

**Horizontal overflow:**
```css
/* Add to global styles */
*, *::before, *::after { box-sizing: border-box; }
img, video { max-width: 100%; }
body { overflow-x: hidden; }
```

**Touch targets too small:**
```css
/* Minimum touch target size */
button, a, input, select { min-height: 44px; min-width: 44px; }
```

**Navigation not collapsing:**
```css
@media (max-width: 768px) {
  .nav-links { display: none; }
  .hamburger-menu { display: block; }
}
```

Always suggest the minimal CSS change that would fix the issue.
