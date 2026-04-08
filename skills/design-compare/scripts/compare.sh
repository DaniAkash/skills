#!/bin/bash
# compare.sh - Visual diff between two images using ImageMagick
# Usage: ./compare.sh <reference.png> <implementation.png> [output_dir]
#
# Produces:
#   diff_highlighted.png  - Red pixels where images differ
#   diff_side_by_side.png - Both images side by side
#   diff_overlay.png      - 50% blend of both images
#   report.txt            - Structured metrics with pass/fail status

set -uo pipefail

REFERENCE="$1"
IMPLEMENTATION="$2"
OUT_DIR="${3:-.diff_output}"

# Validate inputs
if [ ! -f "$REFERENCE" ]; then
  echo "Error: Reference image not found: $REFERENCE" >&2
  exit 1
fi

if [ ! -f "$IMPLEMENTATION" ]; then
  echo "Error: Implementation image not found: $IMPLEMENTATION" >&2
  exit 1
fi

if ! command -v magick &> /dev/null; then
  echo "" >&2
  echo "ERROR: ImageMagick is not installed." >&2
  echo "" >&2
  echo "The design-compare skill requires ImageMagick 7+ to run." >&2
  echo "Please install it for your platform:" >&2
  echo "" >&2
  echo "  macOS:   brew install imagemagick" >&2
  echo "  Ubuntu:  sudo apt-get install imagemagick" >&2
  echo "  Fedora:  sudo dnf install ImageMagick" >&2
  echo "  Arch:    sudo pacman -S imagemagick" >&2
  echo "  Windows: winget install ImageMagick.ImageMagick" >&2
  echo "" >&2
  echo "After installing, verify with: magick --version" >&2
  exit 1
fi

# Check dimensions match
REF_SIZE=$(magick identify -format "%wx%h" "$REFERENCE")
IMPL_SIZE=$(magick identify -format "%wx%h" "$IMPLEMENTATION")

if [ "$REF_SIZE" != "$IMPL_SIZE" ]; then
  echo "Warning: Image dimensions differ (reference: $REF_SIZE, implementation: $IMPL_SIZE)" >&2
  echo "Resizing implementation to match reference..." >&2
  RESIZED_IMPL=$(mktemp /tmp/design-compare-resized-XXXXXX.png)
  magick "$IMPLEMENTATION" -resize "${REF_SIZE}!" "$RESIZED_IMPL"
  IMPLEMENTATION="$RESIZED_IMPL"
  RESIZED=true
else
  RESIZED=false
fi

mkdir -p "$OUT_DIR"

# 1. Pixel diff with bright red highlights
# magick compare returns exit code 1 when images differ — this is expected, suppress output
magick compare \
  -highlight-color "#FF0000" \
  -lowlight-color "#1a1a1a" \
  -fuzz 5% \
  "$REFERENCE" "$IMPLEMENTATION" \
  "$OUT_DIR/diff_highlighted.png" 2>/dev/null || true

# 2. Side-by-side composite (ImageMagick 7: inputs before operator)
magick "$REFERENCE" "$IMPLEMENTATION" +append "$OUT_DIR/diff_side_by_side.png"

# 3. Blend overlay (ghost of both images)
magick composite \
  -blend 50 \
  "$REFERENCE" "$IMPLEMENTATION" \
  "$OUT_DIR/diff_overlay.png"

# 4. Numerical metrics
# magick compare outputs metrics to stderr and returns exit code 1 when images differ
STATS=$(magick compare -metric RMSE -fuzz 5% "$REFERENCE" "$IMPLEMENTATION" null: 2>&1 || true)
AE_RAW=$(magick compare -metric AE -fuzz 5% "$REFERENCE" "$IMPLEMENTATION" null: 2>&1 || true)
SSIM_RAW=$(magick compare -metric SSIM "$REFERENCE" "$IMPLEMENTATION" null: 2>&1 || true)

# AE output can be "24602" or "24602 (0.205017)" — extract just the integer count
AE=$(echo "$AE_RAW" | awk '{print int($1)}')

# ImageMagick SSIM outputs dissimilarity: "1130.32 (0.0172)" where the parenthetical
# is the normalized value (0 = identical). Convert to SSIM where 1 = identical.
SSIM_DISSIM=$(echo "$SSIM_RAW" | grep -oE '\(([0-9.]+)\)' | tr -d '()')
if [ -n "$SSIM_DISSIM" ]; then
  SSIM=$(echo "scale=4; 1 - $SSIM_DISSIM" | bc)
else
  SSIM="N/A"
fi

# Get total pixels
TOTAL_PIXELS=$(magick identify -format "%[fx:w*h]" "$REFERENCE")

# Calculate percentage
if [ "$TOTAL_PIXELS" -gt 0 ] 2>/dev/null && [ "$AE" -ge 0 ] 2>/dev/null; then
  DIFF_PERCENT=$(echo "scale=4; ($AE / $TOTAL_PIXELS) * 100" | bc)
else
  DIFF_PERCENT="N/A"
fi

# Determine status
if [ "$DIFF_PERCENT" != "N/A" ]; then
  IS_UNDER_1=$(echo "$DIFF_PERCENT < 1" | bc -l)
  if [ "$IS_UNDER_1" -eq 1 ]; then
    STATUS_TEXT="PASS — negligible difference"
  else
    IS_UNDER_5=$(echo "$DIFF_PERCENT < 5" | bc -l)
    if [ "$IS_UNDER_5" -eq 1 ]; then
      STATUS_TEXT="REVIEW — minor differences, inspect diff_highlighted.png"
    else
      IS_UNDER_15=$(echo "$DIFF_PERCENT < 15" | bc -l)
      if [ "$IS_UNDER_15" -eq 1 ]; then
        STATUS_TEXT="REVIEW — moderate differences, likely layout/spacing issues"
      else
        STATUS_TEXT="FAIL — major structural differences"
      fi
    fi
  fi
else
  STATUS_TEXT="ERROR — could not calculate metrics"
fi

# 5. Structured report
cat > "$OUT_DIR/report.txt" << EOF
=== VISUAL DIFF REPORT ===
Reference:       $1
Implementation:  $2
$([ "$RESIZED" = true ] && echo "Note:            Implementation was resized from $IMPL_SIZE to $REF_SIZE" || true)

--- METRICS ---
RMSE (0=identical, 1=max diff): $STATS
Differing pixels (AE):          $AE / $TOTAL_PIXELS
Difference percentage:          ${DIFF_PERCENT}%
SSIM (1=identical, 0=different): $SSIM

--- THRESHOLDS ---
< 1%   : Near identical, acceptable
1-5%   : Minor differences, review diff_highlighted.png
5-15%  : Moderate differences, likely layout/spacing issues
> 15%  : Major differences, structural problems

--- STATUS ---
$STATUS_TEXT

--- OUTPUT FILES ---
diff_highlighted.png  : Red pixels = areas that differ
diff_side_by_side.png : Direct visual comparison
diff_overlay.png      : Ghost blend of both images
report.txt            : This file
EOF

cat "$OUT_DIR/report.txt"

# Cleanup temp file if we resized
if [ "$RESIZED" = true ] && [ -f "$RESIZED_IMPL" ]; then
  rm "$RESIZED_IMPL"
fi
