#!/bin/bash
# Basic usage example for SVG to G-code conversion
#
# This script can be run from either:
#   - Top level: ./examples/basic_usage.sh
#   - Examples directory: cd examples && ./basic_usage.sh

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

# Simple conversion with default settings
python -m laser.cli "$SVG_FILE" -o output.gcode

# Conversion with custom output filename
python -m laser.cli "$SVG_FILE" --output my_output.gcode

# Conversion with different units
python -m laser.cli "$SVG_FILE" --unit in -o output_inches.gcode
