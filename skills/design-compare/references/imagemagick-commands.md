# ImageMagick Commands Reference

Detailed reference for all ImageMagick commands used in design comparison.

## Table of Contents

1. [magick compare](#magick-compare)
2. [magick composite](#magick-composite)
3. [magick +append](#magick-append)
4. [magick identify](#magick-identify)
5. [magick convert/resize](#magick-convertresize)
6. [Metrics Deep Dive](#metrics-deep-dive)
7. [Fuzz Tolerance Guide](#fuzz-tolerance-guide)
8. [Cropping for Region Comparison](#cropping-for-region-comparison)

---

## magick compare

The core comparison command. Produces a diff image highlighting differences.

```bash
magick compare [options] reference.png implementation.png output.png
```

### Key Options

| Option | Default | Description |
|--------|---------|-------------|
| `-highlight-color` | red | Color for pixels that differ |
| `-lowlight-color` | white | Color for pixels that match |
| `-fuzz N%` | 0% | Tolerance for color matching |
| `-metric METRIC` | — | Output a numerical metric instead of (or in addition to) an image |
| `-channel all` | all | Which color channels to compare |

### Common Patterns

**Red-on-dark diff (best for visual inspection):**
```bash
magick compare -highlight-color "#FF0000" -lowlight-color "#1a1a1a" \
  -fuzz 5% ref.png impl.png diff.png
```

**Metrics only (no output image):**
```bash
magick compare -metric RMSE ref.png impl.png /dev/null 2>&1
magick compare -metric AE -fuzz 5% ref.png impl.png /dev/null 2>&1
```

**Per-channel comparison (isolate color issues):**
```bash
magick compare -metric RMSE -channel red ref.png impl.png /dev/null 2>&1
magick compare -metric RMSE -channel green ref.png impl.png /dev/null 2>&1
magick compare -metric RMSE -channel blue ref.png impl.png /dev/null 2>&1
```

---

## magick composite

Blends or overlays two images together.

```bash
magick composite [options] overlay.png background.png output.png
```

### Blend Overlay

A 50% blend creates a "ghost" effect showing both images simultaneously. Useful for spotting alignment issues.

```bash
magick composite -blend 50 ref.png impl.png overlay.png
```

**Different blend ratios:**
- `-blend 25` — implementation is dominant, reference is faint
- `-blend 50` — equal blend (default recommendation)
- `-blend 75` — reference is dominant, implementation is faint

### Difference Composite

An alternative to `compare` that shows raw color differences:

```bash
magick composite -compose difference ref.png impl.png raw_diff.png
```

This produces a black image where differences appear as bright pixels. Useful for programmatic analysis but less visually clear than the highlight approach.

---

## magick +append

Joins images horizontally (side by side).

```bash
magick ref.png impl.png +append side_by_side.png
```

For vertical stacking (top/bottom):
```bash
magick ref.png impl.png -append stacked.png
```

### Adding Labels

```bash
magick \( ref.png -set label "Reference" \) \
       \( impl.png -set label "Implementation" \) \
       +append -geometry +10+0 labeled_comparison.png
```

---

## magick identify

Gets image metadata without modifying the image.

```bash
# Dimensions
magick identify -format "%wx%h" image.png

# Total pixel count
magick identify -format "%[fx:w*h]" image.png

# Full info
magick identify -verbose image.png

# Color space
magick identify -format "%[colorspace]" image.png
```

---

## magick convert/resize

In ImageMagick 7, `convert` is replaced by `magick` directly.

### Resize to Match Reference

```bash
REF_SIZE=$(magick identify -format "%wx%h" ref.png)
magick impl.png -resize "${REF_SIZE}!" impl_resized.png
```

The `!` flag forces exact dimensions, ignoring aspect ratio. Without it, ImageMagick preserves aspect ratio and fits within the bounding box.

### Crop a Region

```bash
# Crop WIDTHxHEIGHT+X+Y
magick image.png -crop 800x200+0+0 +repage cropped.png
```

`+repage` resets the virtual canvas to match the crop — without it, the cropped image retains the original canvas offset, which can cause comparison issues.

---

## Metrics Deep Dive

### RMSE (Root Mean Square Error)

- Range: 0 (identical) to 1 (maximum difference)
- Measures: Average color distance across all pixels
- Output format: `value (raw_value)` e.g., `0.045 (2925.5)`
- The raw value is on ImageMagick's internal scale (0–65535 for Q16)

**Interpretation:**
| RMSE | Meaning |
|------|---------|
| 0.00 | Identical |
| < 0.02 | Imperceptible to humans |
| 0.02–0.05 | Noticeable if looking closely |
| 0.05–0.15 | Clearly different |
| > 0.15 | Very different |

### AE (Absolute Error)

- Range: 0 to total_pixels
- Measures: Count of pixels that differ (above fuzz threshold)
- Most intuitive metric — "N pixels are different"
- Used for calculating difference percentage

### Other Available Metrics

| Metric | Description |
|--------|-------------|
| `MAE` | Mean Absolute Error — average per-pixel difference |
| `MSE` | Mean Squared Error — like RMSE but not square-rooted |
| `PHASH` | Perceptual Hash — structural similarity, good for detecting same-content-different-encoding |
| `SSIM` | Structural Similarity Index — closer to human visual perception |
| `DSSIM` | Dissimilarity (1-SSIM) — higher means more different |
| `NCC` | Normalized Cross-Correlation |
| `PSNR` | Peak Signal-to-Noise Ratio (in dB) |

For design QA, RMSE + AE is the recommended combination. SSIM can be useful for perceptual comparison but is harder to threshold.

---

## Fuzz Tolerance Guide

The `-fuzz N%` parameter defines how much two colors can differ and still be considered "the same."

| Fuzz % | Filters out | Use when |
|--------|------------|----------|
| 0% | Nothing | Exact pixel-perfect comparison needed |
| 3% | Sub-pixel rendering noise | Comparing same-browser screenshots |
| 5% | Antialiasing + minor rendering | **Default — good for most design QA** |
| 10% | Font rendering differences | Cross-browser/cross-OS comparison |
| 15% | Significant color variance | Comparing different themes/modes (not recommended) |

Higher fuzz = fewer "different" pixels reported. Start at 5% and increase only if font rendering or antialiasing is producing false positives in the highlighted diff.

---

## Cropping for Region Comparison

When you only need to compare a specific part of the UI:

```bash
# Step 1: Identify the region (x, y, width, height)
# Top navigation bar: 1920x80 starting at (0,0)
magick ref.png -crop 1920x80+0+0 +repage ref_nav.png
magick impl.png -crop 1920x80+0+0 +repage impl_nav.png

# Step 2: Compare the cropped regions
magick compare -metric AE -fuzz 5% ref_nav.png impl_nav.png /dev/null 2>&1
```

This is useful when:
- You've fixed a specific area and want to verify just that region
- The overall diff is noisy but you care about a particular section
- You're doing component-level QA (header, sidebar, card, etc.)
