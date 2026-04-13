# Breakpoints Reference

## Standard Breakpoints (8)

| Width | Device Context | Real Devices | What Typically Breaks |
|-------|---------------|-------------|----------------------|
| 320px | Small phone | iPhone SE (1st/2nd gen), Galaxy A series (small) | Everything — most fragile breakpoint |
| 375px | Standard phone | iPhone 14/15, Pixel 7 | Text overflow, touch targets too small |
| 768px | Tablet portrait | iPad (all), Galaxy Tab | Nav transition (hamburger appears), sidebars |
| 1024px | Tablet landscape / small laptop | iPad Pro landscape, Surface Go | Grid column jumps, sidebar visibility |
| 1280px | Laptop | MacBook Air 13", ThinkPad 14" | Max-width containers kick in |
| 1440px | Desktop | MacBook Pro 14", Dell 24" | Content centering, hero proportions |
| 1920px | Full HD monitor | Standard desktop monitors | Ultra-wide whitespace, text line length |
| 2560px | 4K / ultra-wide | iMac 27", LG UltraWide | Max-width containment, background images |

## Quick Mobile Check Breakpoints (3)

| Width | Priority |
|-------|---------|
| 320px | Stress test — worst case |
| 375px | Most common mobile device |
| 768px | Tablet / transition point |

## Device Group Assignment for Parallel Agents

| Agent | Breakpoints | Purpose |
|-------|------------|---------|
| Agent 1 (mobile) | 320px, 375px | Smallest screens |
| Agent 2 (tablet) | 768px, 1024px | Medium screens |
| Agent 3 (desktop) | 1280px, 1440px | Standard desktop |
| Agent 4 (large) | 1920px, 2560px | Wide screens |

## Trouble Zones

| Range | Why It Breaks |
|-------|--------------|
| 320–375px | Most fragile zone. Fixed-width elements cause overflow. |
| 768–1024px | Tablet no-man's land — many sites have NO breakpoint here. |
| 1024–1280px | Sidebar zone. Grid column jumps happen here. |
| 1440–1920px | Wide screen gap. max-w-7xl containers leave lots of whitespace. |
| 1920–2560px | Ultra-wide text line lengths, background images stop scaling. |

## Default Viewport Height: 900px

Use 900px height for all screenshots unless the user specifies otherwise.

## Framework Default Breakpoints

**Tailwind CSS v4 (default)**
- `sm`: 640px  
- `md`: 768px  
- `lg`: 1024px  
- `xl`: 1280px  
- `2xl`: 1536px

**Bootstrap 5**
- `sm`: 576px  
- `md`: 768px  
- `lg`: 992px  
- `xl`: 1200px  
- `xxl`: 1400px

**CSS Media Query Template**
```css
/* Mobile first approach */
/* Base: mobile styles */

@media (min-width: 640px) { /* sm */ }
@media (min-width: 768px) { /* md - tablet */ }
@media (min-width: 1024px) { /* lg - desktop */ }
@media (min-width: 1280px) { /* xl */ }
@media (min-width: 1536px) { /* 2xl */ }
```
