#!/bin/bash
# Combine cut and engrave layers from SVG into a single G-code file
# Processes engrave layer first, then cut layer, and combines them
#
# This script can be run from either:
#   - Top level: ./examples/combine_cut_engrave.sh <input.svg>
#   - Examples directory: cd examples && ./combine_cut_engrave.sh <input.svg>
#
# Usage:
#   ./examples/combine_cut_engrave.sh input.svg
#   ./examples/combine_cut_engrave.sh input.svg output.gcode

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get the project root (parent of examples directory)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check for input file
if [ $# -lt 1 ]; then
    echo "Usage: $0 <input.svg> [output.gcode]"
    echo ""
    echo "This script processes an SVG file with 'cut' and 'engrave' layers,"
    echo "generates G-code for each layer with specific settings, and combines"
    echo "them into a single file with engrave first, then cut."
    echo ""
    echo "Settings:"
    echo "  Engrave: speed 1000 mm/min, power S75 (29%)"
    echo "  Cut:     speed 250 mm/min, power S255 (100%)"
    exit 1
fi

SVG_FILE="$1"

# Determine SVG file path - check if we're in examples directory or top level
if [ ! -f "$SVG_FILE" ]; then
    # Try relative to current directory
    if [ -f "$SCRIPT_DIR/$SVG_FILE" ]; then
        SVG_FILE="$SCRIPT_DIR/$SVG_FILE"
    elif [ -f "$PROJECT_ROOT/$SVG_FILE" ]; then
        SVG_FILE="$PROJECT_ROOT/$SVG_FILE"
    else
        echo "Error: SVG file '$1' not found"
        exit 1
    fi
fi

# Get absolute path
SVG_FILE="$(cd "$(dirname "$SVG_FILE")" && pwd)/$(basename "$SVG_FILE")"

# Determine output filename
if [ -n "$2" ]; then
    OUTPUT_FILE="$2"
else
    # Use input filename with .gcode extension
    BASE_NAME=$(basename "$SVG_FILE" .svg)
    OUTPUT_FILE="${BASE_NAME}.gcode"
fi

# Get absolute path for output
OUTPUT_FILE="$(cd "$(dirname "$OUTPUT_FILE" 2>/dev/null || echo ".")" && pwd)/$(basename "$OUTPUT_FILE")"

# Create temporary files in the same directory as output
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
TEMP_ENGRAVE="${OUTPUT_DIR}/.tmp_engrave_$$.gcode"
TEMP_CUT="${OUTPUT_DIR}/.tmp_cut_$$.gcode"

# Cleanup function
cleanup() {
    rm -f "$TEMP_ENGRAVE" "$TEMP_CUT"
}
trap cleanup EXIT

echo "=========================================="
echo "Combining Cut and Engrave Layers"
echo "=========================================="
echo "Input SVG:  $SVG_FILE"
echo "Output:     $OUTPUT_FILE"
echo ""

# Function to check if G-code file is essentially empty (only header/footer, no actual cutting)
is_empty_gcode() {
    local file="$1"
    # Count lines that are actual cutting commands (G1, G2, G3, M3 with movement)
    # Exclude header (G90, M5, G21) and footer (M5, G0 X0 Y0)
    local cutting_lines=$(grep -E '^(G1|G2|G3|M3 S)' "$file" 2>/dev/null | grep -v '^G1 F[0-9]' | wc -l)
    [ "$cutting_lines" -eq 0 ]
}

# Generate engrave layer G-code
# Speed: 1000 mm/min, Power: S75 (29%)
echo "[1/3] Generating engrave layer G-code..."
echo "  Settings: Cutting speed=1000 mm/min, Power=S75 (29%)"
python -m laser.cli "$SVG_FILE" \
    --layer "engrave" \
    --cutting-speed 1000 \
    --tool-power-command "M3 S75;" \
    --output "$TEMP_ENGRAVE" \
    --do-laser-off-end 2>&1 | grep -v "UserWarning" || true

if [ $? -ne 0 ]; then
    echo "  ✗ Failed to generate engrave layer G-code"
    echo "  Warning: Engrave layer may not exist in SVG, continuing with cut only..."
    TEMP_ENGRAVE=""
elif [ -f "$TEMP_ENGRAVE" ] && is_empty_gcode "$TEMP_ENGRAVE"; then
    echo "  ⚠ Warning: Engrave layer found but contains no paths to process"
    echo "  Hint: Make sure objects in the 'engrave' layer are converted to paths"
    echo "        (In Inkscape: Select objects → Path → Object to Path)"
    echo "  Continuing with cut only..."
    TEMP_ENGRAVE=""
fi
echo ""

# Generate cut layer G-code
# Speed: 250 mm/min, Power: S255 (100%)
echo "[2/3] Generating cut layer G-code..."
echo "  Settings: Cutting speed=250 mm/min, Power=S255 (100%)"
python -m laser.cli "$SVG_FILE" \
    --layer "cut" \
    --cutting-speed 250 \
    --tool-power-command "M3 S255;" \
    --output "$TEMP_CUT" \
    --do-laser-off-end 2>&1 | grep -v "UserWarning" || true

if [ $? -ne 0 ]; then
    echo "  ✗ Failed to generate cut layer G-code"
    echo "  Error: Cut layer is required but not found in SVG"
    exit 1
elif [ -f "$TEMP_CUT" ] && is_empty_gcode "$TEMP_CUT"; then
    echo "  ✗ Error: Cut layer found but contains no paths to process"
    echo ""
    echo "  Troubleshooting:"
    echo "  1. Make sure the 'cut' layer exists in your SVG file"
    echo "  2. Convert all objects in the 'cut' layer to paths:"
    echo "     - In Inkscape: Select objects → Path → Object to Path"
    echo "  3. Verify layer names match exactly (case-sensitive): 'cut' and 'engrave'"
    echo "  4. Check that the layers contain actual path elements, not just shapes"
    exit 1
fi
echo ""

# Combine G-code files (engrave first, then cut)
echo "[3/3] Combining G-code files..."
echo "  Order: Engrave first, then Cut"

# Function to remove footer from G-code (last M5 and move commands)
remove_footer() {
    local file="$1"
    # Remove trailing M5, G0 X0 Y0, and empty lines
    awk '
        BEGIN { in_footer = 0 }
        /^M5;?$/ { in_footer = 1; next }
        /^G0 X0 Y0/ && in_footer { next }
        /^G0 X0 Y0 Z0/ && in_footer { next }
        /^$/ && in_footer { next }
        { in_footer = 0; print }
    ' "$file"
}

# Function to get body from G-code (skip header, keep body and footer)
get_body_and_footer() {
    local file="$1"
    # Skip header lines until we find the unit command (G21/G20), then output everything after
    awk '/^G2[01];?$/ { found_unit = 1; next } found_unit { print }' "$file"
}

# Combine: full engrave (without footer), separator, cut (body + footer only, no header)
SEPARATOR="; =========================================="
LAYER_SEP="; Layer transition: Engrave -> Cut"
SEPARATOR_END="; =========================================="

# Write combined output
{
    # Full engrave file without footer
    if [ -n "$TEMP_ENGRAVE" ] && [ -f "$TEMP_ENGRAVE" ]; then
        remove_footer "$TEMP_ENGRAVE"
        echo ""
        echo "$SEPARATOR"
        echo "$LAYER_SEP"
        echo "$SEPARATOR_END"
        echo ""
    fi
    
    # Cut file body and footer (skip header to avoid duplicates)
    get_body_and_footer "$TEMP_CUT"
} > "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
    echo "  ✓ Successfully created combined G-code file"
    echo ""
    echo "=========================================="
    echo "Summary"
    echo "=========================================="
    echo "Output file: $OUTPUT_FILE"
    if [ -n "$TEMP_ENGRAVE" ] && [ -f "$TEMP_ENGRAVE" ]; then
        ENGRAVE_LINES=$(wc -l < "$TEMP_ENGRAVE" | tr -d ' ')
        echo "Engrave layer: $ENGRAVE_LINES lines (speed: 1000 mm/min, power: S75)"
    fi
    CUT_LINES=$(wc -l < "$TEMP_CUT" | tr -d ' ')
    echo "Cut layer:    $CUT_LINES lines (speed: 250 mm/min, power: S255)"
    TOTAL_LINES=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')
    echo "Total:        $TOTAL_LINES lines"
    echo ""
    echo "The G-code file is ready for use with your laser cutter!"
else
    echo "  ✗ Failed to create combined G-code file"
    exit 1
fi
