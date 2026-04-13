# Responsiveness Audit Report Template

Use this structure for every audit. Fill in all sections. Skip only breakpoints with zero findings (but still list them in the summary as "Pass").

---

```markdown
# Responsiveness Audit: [URL or Site Name]

**Date**: YYYY-MM-DD  
**Mode**: Standard (8 breakpoints) / Quick Mobile / Targeted Range  
**Breakpoints tested**: 320px, 375px, 768px, 1024px, 1280px, 1440px, 1920px, 2560px  
**Tool**: agent-browser / Chrome DevTools MCP (for authenticated session)  
**Audited by**: Claude Code

---

## Summary

| Breakpoint | Device | Status | Issue Count |
|-----------|--------|--------|------------|
| 320px | Mobile S | ✅ Pass / ⚠️ Warn / ❌ Fail | 0 |
| 375px | Mobile M | | |
| 768px | Tablet | | |
| 1024px | Tablet L | | |
| 1280px | Desktop | | |
| 1440px | Desktop L | | |
| 1920px | Full HD | | |
| 2560px | Ultra-wide | | |

**Overall status**: Pass / Warn / Fail  
**Total issues**: X critical, X high, X medium, X low

---

## Critical & High Issues

> List only critical and high severity issues here for quick scanning.

### Issue 1: [Short title]

- **Severity**: Critical / High  
- **Affected breakpoints**: 320px, 375px  
- **Check category**: Horizontal overflow / Navigation / Touch targets / etc.  
- **Description**: [What is broken and why it matters]  
- **Screenshot**: `![320px screenshot](./screenshots/320px-homepage.png)`  
- **CSS Fix**:
  ```css
  /* Add fix here */
  ```

### Issue 2: [Short title]
...

---

## Layout Transitions

| Transition | Observed At | Clean? | Notes |
|-----------|------------|--------|-------|
| Horizontal nav → hamburger | ~768px | ✅ Yes | Smooth transition, menu works |
| 3-col grid → 1-col | ~640px | ⚠️ Partial | Gap jumps unexpectedly |
| Sidebar hides | ~1024px | ❌ No | Content reflows abruptly, jumps |

---

## Per-Breakpoint Details

> Include only breakpoints with findings. List clean breakpoints in summary only.

### 375px — Mobile M

**Status**: ⚠️ Warn

**Screenshot**: `![375px](./screenshots/375px-homepage.png)`

**Check Matrix**:

| Check | Result | Notes |
|-------|--------|-------|
| Horizontal overflow | ✅ Pass | |
| Text overflow | ⚠️ Warn | Hero heading wraps awkwardly at 3 lines |
| Navigation transition | ✅ Pass | Hamburger menu present |
| Content stacking | ✅ Pass | |
| Image scaling | ✅ Pass | |
| Touch targets | ⚠️ Warn | "Subscribe" button is 36px tall |
| Whitespace balance | ✅ Pass | |
| CTA above fold | ✅ Pass | |
| Font readability | ✅ Pass | |
| Z-index / overlap | ✅ Pass | |

**Issues**:
- **[Medium]** Subscribe button too small (36px, should be ≥44px)

---

### 768px — Tablet

...

---

## Recommendations

### Quick Fixes (CSS changes only)

1. **Fix touch target sizes** — Add `min-height: 44px` to all interactive elements
   ```css
   button, a.cta, input[type="submit"] { min-height: 44px; }
   ```

2. **Prevent horizontal overflow** — Add box-sizing reset
   ```css
   *, *::before, *::after { box-sizing: border-box; }
   img, video, iframe { max-width: 100%; }
   ```

### Structural Changes

1. **Navigation** — Implement a proper hamburger menu toggle for ≤768px
2. **Grid layout** — Add `@media (max-width: 640px) { grid-template-columns: 1fr; }` to all multi-column grids

### Priority Order

1. [Critical issues first]
2. [High issues]
3. [Medium issues]
4. [Low / cosmetic]
```

---

## Status Legend

| Symbol | Meaning |
|--------|---------|
| ✅ Pass | No issues at this breakpoint/check |
| ⚠️ Warn | Medium or low severity issues |
| ❌ Fail | Critical or high severity issue |
