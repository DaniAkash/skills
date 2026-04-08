---
name: design-compare
description: Visual diff comparison between two screenshots using ImageMagick. Use this skill whenever you need to compare a design mockup against an implementation screenshot, compare an .html file's rendered output against the actual app UI, do design QA between iterations, verify visual regression after code changes, or any task where you need to find pixel-level differences between two images. Also use when the user says "compare these screenshots," "what's different between these images," "check if the implementation matches the design," "visual diff," "design QA," "screenshot comparison," or "does this match the mockup." Even if the user just gives you two images and asks what changed — this is the skill to use.
---

# Design Compare

Compare two screenshots to find visual differences using ImageMagick. This skill is for design QA — figuring out exactly *where* and *how much* an implementation differs from a reference image, then iterating until they match.

## When to Use This

- Comparing a design mockup (Figma export, reference PNG) against a code-generated screenshot
- Comparing an `.html` file rendered in a browser against the actual app UI
- Checking visual regression between two versions of the same page
- Iterative design QA: fix → screenshot → compare → repeat until matching

## Prerequisites

ImageMagick 7+ must be installed. Check with:

```bash
magick --version
```

If missing, install via Homebrew: `brew install imagemagick`

Also needs `bc` for percentage calculations (pre-installed on macOS/Linux).

## The Comparison Workflow

### Step 1: Run the comparison script

The skill bundles `scripts/compare.sh`. Run it with:

```bash
bash <skill-path>/scripts/compare.sh <reference.png> <implementation.png> [output_dir]
```

- `reference.png` — the "correct" image (design mockup, previous version, etc.)
- `implementation.png` — the image you're checking against the reference
- `output_dir` — where to save results (defaults to `.diff_output/`)

The script produces four outputs:

| File | What it shows | When to use it |
|------|--------------|----------------|
| `diff_highlighted.png` | Red pixels where images differ | **Where** — locate exact areas that need fixing |
| `diff_side_by_side.png` | Both images next to each other | **What** — direct visual comparison |
| `diff_overlay.png` | 50% blend of both images | **How different** — overall composition feel |
| `report.txt` | Numerical metrics + pass/fail status | **How much** — quantitative assessment |

### Step 2: Read the report

The `report.txt` contains structured metrics:

```
=== VISUAL DIFF REPORT ===
Original:        reference.png
Implementation:  implementation.png

--- METRICS ---
RMSE (0=identical, 1=max diff): 0.045 (2925.5)
Differing pixels (AE):          12847 / 2073600
Difference percentage:          0.6196%

--- STATUS ---
PASS — negligible difference
```

**Thresholds for deciding what to do:**

| Difference % | Status | Action |
|-------------|--------|--------|
| < 1% | PASS | Near identical. Acceptable — move on. |
| 1–5% | REVIEW | Minor differences. Inspect `diff_highlighted.png` to see if they matter (could be font rendering, antialiasing). |
| 5–15% | REVIEW | Moderate differences. Likely layout shifts, spacing issues, or color mismatches. Fix needed. |
| > 15% | FAIL | Major structural differences. Something is fundamentally wrong — wrong layout, missing elements, etc. |

### Step 3: Inspect the highlighted diff

If the difference is above 1%, open `diff_highlighted.png`. Red pixels mark every area that differs. This tells you exactly which regions of the UI need attention — a misaligned button, wrong padding, different font size, color mismatch, etc.

Use this to decide what to fix next. Don't try to fix everything at once — focus on the largest red regions first.

### Step 4: Fix and re-compare

After making code changes:

1. Take a new screenshot of the implementation
2. Run `compare.sh` again with the same reference image
3. Check if the difference percentage decreased
4. Repeat until status shows PASS (< 1%) or the remaining differences are acceptable (font rendering, antialiasing)

This is the core loop: **fix → screenshot → compare → read report → repeat**.

## Handling Common Situations

### Images are different sizes

ImageMagick will error if the images have different dimensions. Before comparing, resize the implementation to match the reference:

```bash
# Get reference dimensions
REF_SIZE=$(magick identify -format "%wx%h" reference.png)

# Resize implementation to match (use ! to force exact dimensions)
magick implementation.png -resize "${REF_SIZE}!" implementation_resized.png

# Now compare
bash <skill-path>/scripts/compare.sh reference.png implementation_resized.png
```

The `!` flag forces exact pixel dimensions (ignoring aspect ratio). This is appropriate for design QA where both images should represent the same viewport.

### High diff from antialiasing or font rendering

Font rendering differs between systems and browsers. If `diff_highlighted.png` shows thin red outlines around text but the layout is correct, increase the fuzz tolerance:

```bash
# Inside your comparison, use higher fuzz (10-15% for font-heavy UIs)
magick compare -highlight-color "#FF0000" -lowlight-color "#1a1a1a" \
  -fuzz 10% reference.png implementation.png diff_highlighted.png
```

The default 5% fuzz handles most antialiasing noise. Go to 10–15% only if fonts or shadows are the primary source of diff.

### Comparing specific regions

If you only care about a particular section (e.g., the header), crop both images first:

```bash
# Crop a 800x200 region starting at position (0,0) from both images
magick reference.png -crop 800x200+0+0 +repage ref_header.png
magick implementation.png -crop 800x200+0+0 +repage impl_header.png

# Compare just the headers
bash <skill-path>/scripts/compare.sh ref_header.png impl_header.png
```

### Dark or complex backgrounds

On dark UIs, the default lowlight color (`#1a1a1a`) may blend in. Switch to a more visible lowlight:

```bash
magick compare -highlight-color "#FF0000" -lowlight-color "#333333" \
  -fuzz 5% reference.png implementation.png diff_highlighted.png
```

## Understanding the Metrics

**RMSE (Root Mean Square Error):** A value between 0 and 1 measuring average color difference across all pixels. Lower is better. Values below 0.02 are usually imperceptible.

**AE (Absolute Error):** Raw count of pixels that differ (above the fuzz threshold). This is the most intuitive metric — "12,847 out of 2,073,600 pixels are different."

**Difference percentage:** AE divided by total pixels, times 100. This is what the thresholds are based on.

The `-fuzz 5%` parameter means pixels that differ by less than 5% in color value are treated as identical. This filters out sub-pixel rendering noise that would otherwise inflate the diff count.

## The Iterative Design QA Loop

When doing multi-round design QA (fixing implementation to match a design), follow this pattern:

```
1. Take screenshot of current implementation
2. Run compare.sh against reference design
3. Read report.txt
4. If PASS → done
5. If not → inspect diff_highlighted.png
6. Identify the largest/most impactful differences
7. Fix the code (CSS, layout, colors, spacing)
8. Go to step 1
```

Prioritize fixes by visual impact: layout/structural issues first, then spacing/sizing, then colors, then fine details like shadows and borders. Each iteration should reduce the difference percentage. If it increases, you may have introduced a regression — check what changed.

## Running Individual ImageMagick Commands

If you need more control than the bundled script provides, here are the individual commands. See `references/imagemagick-commands.md` for detailed options.

**Pixel diff with red highlights:**
```bash
magick compare -highlight-color "#FF0000" -lowlight-color "#1a1a1a" \
  -fuzz 5% reference.png implementation.png diff_highlighted.png
```

**Side-by-side:**
```bash
magick reference.png implementation.png +append side_by_side.png
```

**Blend overlay:**
```bash
magick composite -blend 50 reference.png implementation.png overlay.png
```

**Get metrics only (no output image):**
```bash
# RMSE
magick compare -metric RMSE -fuzz 5% reference.png implementation.png /dev/null 2>&1

# Absolute pixel count
magick compare -metric AE -fuzz 5% reference.png implementation.png /dev/null 2>&1

# Total pixels for percentage calculation
magick identify -format "%[fx:w*h]" reference.png
```
