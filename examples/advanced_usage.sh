#!/bin/bash
# Advanced usage examples for SVG to G-code conversion
#
# This script can be run from either:
#   - Top level: ./examples/advanced_usage.sh
#   - Examples directory: cd examples && ./advanced_usage.sh

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get the project root (parent of examples directory)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Determine SVG file path - check if we're in examples directory or top level
if [ -f "sample.svg" ]; then
    SVG_FILE="sample.svg"
elif [ -f "$SCRIPT_DIR/sample.svg" ]; then
    SVG_FILE="$SCRIPT_DIR/sample.svg"
else
    echo "Error: sample.svg not found"
    exit 1
fi

# Layer selection - process only the "cut" layer
python -m laser.cli "$SVG_FILE" --layer "cut" -o output_cut.gcode

# Layer selection - process only the "engrave" layer
python -m laser.cli "$SVG_FILE" --layer "engrave" -o output_engrave.gcode

# Custom speeds and passes
python -m laser.cli "$SVG_FILE" \
    --travel-speed 5000 \
    --cutting-speed 1000 \
    --passes 3 \
    --pass-depth 0.5 \
    -o output_multipass.gcode

# Custom machine origin and offsets
python -m laser.cli "$SVG_FILE" \
    --machine-origin center \
    --horizontal-offset 10 \
    --vertical-offset 20 \
    --scaling-factor 1.5 \
    -o output_transformed.gcode

# Custom header and footer files
python -m laser.cli "$SVG_FILE" \
    --header-file custom_header.gcode \
    --footer-file custom_footer.gcode \
    -o output_custom.gcode

# Zero machine coordinates
python -m laser.cli "$SVG_FILE" \
    --zero-machine \
    --move-to-origin-end \
    -o output_zeroed.gcode
