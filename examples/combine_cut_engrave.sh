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
#
# Environment Variables:
#   All settings can be overridden via environment variables:
#   TRAVEL_SPEED, ENGRAVE_CUTTING_SPEED, ENGRAVE_POWER, CUT_CUTTING_SPEED, CUT_POWER, etc.

# ============================================================================
# Configuration Variables (can be overridden by environment variables)
# ============================================================================

# Travel speed (mm/min) - used for both engrave and cut
TRAVEL_SPEED="${TRAVEL_SPEED:-3000}"

# Engrave layer settings
ENGRAVE_CUTTING_SPEED="${ENGRAVE_CUTTING_SPEED:-1000}"
ENGRAVE_POWER="${ENGRAVE_POWER:-75}"

# Cut layer settings
CUT_CUTTING_SPEED="${CUT_CUTTING_SPEED:-250}"
CUT_POWER="${CUT_POWER:-255}"

# Bed size settings
USE_DOCUMENT_SIZE="${USE_DOCUMENT_SIZE:-true}"

# Other settings (with defaults matching CLI defaults)
UNIT="${UNIT:-mm}"
PASSES="${PASSES:-1}"
PASS_DEPTH="${PASS_DEPTH:-1}"
DWELL_TIME="${DWELL_TIME:-0}"
APPROXIMATION_TOLERANCE="${APPROXIMATION_TOLERANCE:-0.01}"
TOOL_OFF_COMMAND="${TOOL_OFF_COMMAND:-M5;}"
MACHINE_ORIGIN="${MACHINE_ORIGIN:-bottom-left}"
ZERO_MACHINE="${ZERO_MACHINE:-false}"
INVERT_Y_AXIS="${INVERT_Y_AXIS:-false}"
BED_WIDTH="${BED_WIDTH:-200}"
BED_HEIGHT="${BED_HEIGHT:-200}"
HORIZONTAL_OFFSET="${HORIZONTAL_OFFSET:-0}"
VERTICAL_OFFSET="${VERTICAL_OFFSET:-0}"
SCALING_FACTOR="${SCALING_FACTOR:-1}"

# ============================================================================

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
    echo "Current Settings:"
    echo "  Travel speed:        ${TRAVEL_SPEED} mm/min"
    echo "  Engrave:             speed ${ENGRAVE_CUTTING_SPEED} mm/min, power S${ENGRAVE_POWER} ($((ENGRAVE_POWER * 100 / 255))%)"
    echo "  Cut:                 speed ${CUT_CUTTING_SPEED} mm/min, power S${CUT_POWER} ($((CUT_POWER * 100 / 255))%)"
    echo "  Use document size:   ${USE_DOCUMENT_SIZE}"
    echo ""
    echo "Environment Variables:"
    echo "  All settings can be overridden via environment variables:"
    echo "  TRAVEL_SPEED, ENGRAVE_CUTTING_SPEED, ENGRAVE_POWER, CUT_CUTTING_SPEED, CUT_POWER,"
    echo "  USE_DOCUMENT_SIZE, UNIT, PASSES, PASS_DEPTH, DWELL_TIME, etc."
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
echo "[1/3] Generating engrave layer G-code..."
echo "  Settings: Travel speed=${TRAVEL_SPEED} mm/min, Cutting speed=${ENGRAVE_CUTTING_SPEED} mm/min, Power=S${ENGRAVE_POWER} ($((ENGRAVE_POWER * 100 / 255))%)"

# Build command arguments
ENGRAVE_ARGS=(
    "$SVG_FILE"
    --layer "engrave"
    --unit "$UNIT"
    --travel-speed "$TRAVEL_SPEED"
    --cutting-speed "$ENGRAVE_CUTTING_SPEED"
    --passes "$PASSES"
    --pass-depth "$PASS_DEPTH"
    --dwell-time "$DWELL_TIME"
    --approximation-tolerance "$APPROXIMATION_TOLERANCE"
    --tool-power-command "M3 S${ENGRAVE_POWER};"
    --tool-off-command "$TOOL_OFF_COMMAND"
    --machine-origin "$MACHINE_ORIGIN"
    --bed-width "$BED_WIDTH"
    --bed-height "$BED_HEIGHT"
    --horizontal-offset "$HORIZONTAL_OFFSET"
    --vertical-offset "$VERTICAL_OFFSET"
    --scaling-factor "$SCALING_FACTOR"
    --output "$TEMP_ENGRAVE"
    --do-laser-off-end
)

# Add boolean flags
[ "$ZERO_MACHINE" = "true" ] && ENGRAVE_ARGS+=(--zero-machine) || ENGRAVE_ARGS+=(--no-zero-machine)
[ "$INVERT_Y_AXIS" = "true" ] && ENGRAVE_ARGS+=(--invert-y-axis) || ENGRAVE_ARGS+=(--no-invert-y-axis)
[ "$USE_DOCUMENT_SIZE" = "true" ] && ENGRAVE_ARGS+=(--use-document-size) || ENGRAVE_ARGS+=(--no-use-document-size)

python -m laser.cli "${ENGRAVE_ARGS[@]}" 2>&1 | grep -v "UserWarning" || true

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
echo "[2/3] Generating cut layer G-code..."
echo "  Settings: Travel speed=${TRAVEL_SPEED} mm/min, Cutting speed=${CUT_CUTTING_SPEED} mm/min, Power=S${CUT_POWER} ($((CUT_POWER * 100 / 255))%)"

# Build command arguments
CUT_ARGS=(
    "$SVG_FILE"
    --layer "cut"
    --unit "$UNIT"
    --travel-speed "$TRAVEL_SPEED"
    --cutting-speed "$CUT_CUTTING_SPEED"
    --passes "$PASSES"
    --pass-depth "$PASS_DEPTH"
    --dwell-time "$DWELL_TIME"
    --approximation-tolerance "$APPROXIMATION_TOLERANCE"
    --tool-power-command "M3 S${CUT_POWER};"
    --tool-off-command "$TOOL_OFF_COMMAND"
    --machine-origin "$MACHINE_ORIGIN"
    --bed-width "$BED_WIDTH"
    --bed-height "$BED_HEIGHT"
    --horizontal-offset "$HORIZONTAL_OFFSET"
    --vertical-offset "$VERTICAL_OFFSET"
    --scaling-factor "$SCALING_FACTOR"
    --output "$TEMP_CUT"
    --do-laser-off-end
)

# Add boolean flags
[ "$ZERO_MACHINE" = "true" ] && CUT_ARGS+=(--zero-machine) || CUT_ARGS+=(--no-zero-machine)
[ "$INVERT_Y_AXIS" = "true" ] && CUT_ARGS+=(--invert-y-axis) || CUT_ARGS+=(--no-invert-y-axis)
[ "$USE_DOCUMENT_SIZE" = "true" ] && CUT_ARGS+=(--use-document-size) || CUT_ARGS+=(--no-use-document-size)

python -m laser.cli "${CUT_ARGS[@]}" 2>&1 | grep -v "UserWarning" || true

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
        echo "Engrave layer: $ENGRAVE_LINES lines (speed: ${ENGRAVE_CUTTING_SPEED} mm/min, power: S${ENGRAVE_POWER})"
    fi
    CUT_LINES=$(wc -l < "$TEMP_CUT" | tr -d ' ')
    echo "Cut layer:    $CUT_LINES lines (speed: ${CUT_CUTTING_SPEED} mm/min, power: S${CUT_POWER})"
    TOTAL_LINES=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')
    echo "Total:        $TOTAL_LINES lines"
    echo ""
    echo "The G-code file is ready for use with your laser cutter!"
else
    echo "  ✗ Failed to create combined G-code file"
    exit 1
fi
