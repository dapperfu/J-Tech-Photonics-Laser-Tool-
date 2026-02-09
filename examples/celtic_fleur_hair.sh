#!/bin/bash
# Generate G-code files for CelticFleurHair SVG
# Creates separate files for cut and engrave layers
#
# This script can be run from either:
#   - Top level: ./examples/celtic_fleur_hair.sh
#   - Examples directory: cd examples && ./celtic_fleur_hair.sh

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get the project root (parent of examples directory)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Determine SVG file path - check if we're in examples directory or top level
if [ -f "CelticFleurHair.svg" ]; then
    SVG_FILE="CelticFleurHair.svg"
elif [ -f "$SCRIPT_DIR/CelticFleurHair.svg" ]; then
    SVG_FILE="$SCRIPT_DIR/CelticFleurHair.svg"
elif [ -f "$PROJECT_ROOT/CelticFleurHair.svg" ]; then
    SVG_FILE="$PROJECT_ROOT/CelticFleurHair.svg"
else
    echo "Error: CelticFleurHair.svg not found"
    exit 1
fi

echo "Processing $SVG_FILE..."

# Generate cut layer G-code
# Travel speed: 200, Cutting speed: 750 (default), Tool power: M3 S255
echo "Generating cut layer G-code..."
python -m laser.cli "$SVG_FILE" \
    --layer "cut" \
    --travel-speed 200 \
    --cutting-speed 750 \
    --tool-power-command "M3 S255;" \
    --output "CelticFleurHair_cut.gcode"

if [ $? -eq 0 ]; then
    echo "✓ Created CelticFleurHair_cut.gcode"
else
    echo "✗ Failed to create cut layer G-code"
    exit 1
fi

# Generate engrave layer G-code
# Travel speed: 500, Cutting speed: 750 (default), Tool power: M3 S255
echo "Generating engrave layer G-code..."
python -m laser.cli "$SVG_FILE" \
    --layer "engrave" \
    --travel-speed 500 \
    --cutting-speed 750 \
    --tool-power-command "M3 S255;" \
    --output "CelticFleurHair_engrave.gcode"

if [ $? -eq 0 ]; then
    echo "✓ Created CelticFleurHair_engrave.gcode"
else
    echo "✗ Failed to create engrave layer G-code"
    exit 1
fi

echo ""
echo "Successfully generated both G-code files:"
echo "  - CelticFleurHair_cut.gcode (travel speed: 200)"
echo "  - CelticFleurHair_engrave.gcode (travel speed: 500)"
