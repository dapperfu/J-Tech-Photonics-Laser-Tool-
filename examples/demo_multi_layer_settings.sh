#!/bin/bash
# Demonstration script showing how to process multiple layers with different settings
# This script processes each layer from demo_layers.svg with unique travel speed,
# cutting speed, and power settings to demonstrate the CLI tool's flexibility.
#
# This script can be run from either:
#   - Top level: ./examples/demo_multi_layer_settings.sh
#   - Examples directory: cd examples && ./demo_multi_layer_settings.sh

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get the project root (parent of examples directory)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Determine SVG file path - check if we're in examples directory or top level
if [ -f "demo_layers.svg" ]; then
    SVG_FILE="demo_layers.svg"
elif [ -f "$SCRIPT_DIR/demo_layers.svg" ]; then
    SVG_FILE="$SCRIPT_DIR/demo_layers.svg"
elif [ -f "$PROJECT_ROOT/examples/demo_layers.svg" ]; then
    SVG_FILE="$PROJECT_ROOT/examples/demo_layers.svg"
else
    echo "Error: demo_layers.svg not found"
    echo "Please generate it first with: python generate_demo_svg.py"
    exit 1
fi

echo "=========================================="
echo "Multi-Layer Settings Demonstration"
echo "=========================================="
echo "Processing $SVG_FILE with different settings for each layer..."
echo ""

# Layer 1: Circle - High power, slow cutting for thick materials
# Travel speed: 3000, Cutting speed: 500, Power: M3 S255 (100%)
echo "[1/8] Generating circle layer G-code..."
echo "  Settings: Travel=3000 mm/min, Cut=500 mm/min, Power=100% (S255)"
python -m laser.cli "$SVG_FILE" \
    --layer "circle" \
    --travel-speed 3000 \
    --cutting-speed 500 \
    --tool-power-command "M3 S255;" \
    --output "demo_circle.gcode"

if [ $? -eq 0 ]; then
    echo "  ✓ Created demo_circle.gcode"
else
    echo "  ✗ Failed to create circle layer G-code"
    exit 1
fi
echo ""

# Layer 2: Square - Medium power, medium speed for standard cutting
# Travel speed: 2500, Cutting speed: 750, Power: M3 S200 (78%)
echo "[2/8] Generating square layer G-code..."
echo "  Settings: Travel=2500 mm/min, Cut=750 mm/min, Power=78% (S200)"
python -m laser.cli "$SVG_FILE" \
    --layer "square" \
    --travel-speed 2500 \
    --cutting-speed 750 \
    --tool-power-command "M3 S200;" \
    --output "demo_square.gcode"

if [ $? -eq 0 ]; then
    echo "  ✓ Created demo_square.gcode"
else
    echo "  ✗ Failed to create square layer G-code"
    exit 1
fi
echo ""

# Layer 3: Triangle - Fast cutting, lower power for thin materials
# Travel speed: 4000, Cutting speed: 1000, Power: M3 S150 (59%)
echo "[3/8] Generating triangle layer G-code..."
echo "  Settings: Travel=4000 mm/min, Cut=1000 mm/min, Power=59% (S150)"
python -m laser.cli "$SVG_FILE" \
    --layer "triangle" \
    --travel-speed 4000 \
    --cutting-speed 1000 \
    --tool-power-command "M3 S150;" \
    --output "demo_triangle.gcode"

if [ $? -eq 0 ]; then
    echo "  ✓ Created demo_triangle.gcode"
else
    echo "  ✗ Failed to create triangle layer G-code"
    exit 1
fi
echo ""

# Layer 4: Ellipse - Engraving settings (low power, slow speed)
# Travel speed: 2000, Cutting speed: 300, Power: M3 S100 (39%)
echo "[4/8] Generating ellipse layer G-code..."
echo "  Settings: Travel=2000 mm/min, Cut=300 mm/min, Power=39% (S100) - Engraving"
python -m laser.cli "$SVG_FILE" \
    --layer "ellipse" \
    --travel-speed 2000 \
    --cutting-speed 300 \
    --tool-power-command "M3 S100;" \
    --output "demo_ellipse.gcode"

if [ $? -eq 0 ]; then
    echo "  ✓ Created demo_ellipse.gcode"
else
    echo "  ✗ Failed to create ellipse layer G-code"
    exit 1
fi
echo ""

# Layer 5: Star - High precision cutting (multiple passes)
# Travel speed: 2000, Cutting speed: 600, Power: M3 S180 (71%), Passes: 3
echo "[5/8] Generating star layer G-code..."
echo "  Settings: Travel=2000 mm/min, Cut=600 mm/min, Power=71% (S180), Passes=3"
python -m laser.cli "$SVG_FILE" \
    --layer "star" \
    --travel-speed 2000 \
    --cutting-speed 600 \
    --tool-power-command "M3 S180;" \
    --passes 3 \
    --output "demo_star.gcode"

if [ $? -eq 0 ]; then
    echo "  ✓ Created demo_star.gcode"
else
    echo "  ✗ Failed to create star layer G-code"
    exit 1
fi
echo ""

# Layer 6: Hexagon - Medium settings with dwell time
# Travel speed: 3000, Cutting speed: 800, Power: M3 S220 (86%), Dwell: 100ms
echo "[6/8] Generating hexagon layer G-code..."
echo "  Settings: Travel=3000 mm/min, Cut=800 mm/min, Power=86% (S220), Dwell=100ms"
python -m laser.cli "$SVG_FILE" \
    --layer "hexagon" \
    --travel-speed 3000 \
    --cutting-speed 800 \
    --tool-power-command "M3 S220;" \
    --dwell-time 100 \
    --output "demo_hexagon.gcode"

if [ $? -eq 0 ]; then
    echo "  ✓ Created demo_hexagon.gcode"
else
    echo "  ✗ Failed to create hexagon layer G-code"
    exit 1
fi
echo ""

# Layer 7: Line - Very fast travel, low power for scoring
# Travel speed: 5000, Cutting speed: 1200, Power: M3 S80 (31%)
echo "[7/8] Generating line layer G-code..."
echo "  Settings: Travel=5000 mm/min, Cut=1200 mm/min, Power=31% (S80) - Scoring"
python -m laser.cli "$SVG_FILE" \
    --layer "line" \
    --travel-speed 5000 \
    --cutting-speed 1200 \
    --tool-power-command "M3 S80;" \
    --output "demo_line.gcode"

if [ $? -eq 0 ]; then
    echo "  ✓ Created demo_line.gcode"
else
    echo "  ✗ Failed to create line layer G-code"
    exit 1
fi
echo ""

# Layer 8: Polyline - Custom settings for decorative work
# Travel speed: 3500, Cutting speed: 900, Power: M3 S120 (47%)
echo "[8/8] Generating polyline layer G-code..."
echo "  Settings: Travel=3500 mm/min, Cut=900 mm/min, Power=47% (S120)"
python -m laser.cli "$SVG_FILE" \
    --layer "polyline" \
    --travel-speed 3500 \
    --cutting-speed 900 \
    --tool-power-command "M3 S120;" \
    --output "demo_polyline.gcode"

if [ $? -eq 0 ]; then
    echo "  ✓ Created demo_polyline.gcode"
else
    echo "  ✗ Failed to create polyline layer G-code"
    exit 1
fi
echo ""

echo "=========================================="
echo "Summary: Successfully generated 8 G-code files"
echo "=========================================="
echo ""
echo "Layer-specific settings used:"
echo "  circle:    Travel=3000, Cut=500,  Power=100% (S255) - Thick material cutting"
echo "  square:    Travel=2500, Cut=750,  Power=78%  (S200) - Standard cutting"
echo "  triangle:  Travel=4000, Cut=1000, Power=59%  (S150) - Thin material cutting"
echo "  ellipse:   Travel=2000, Cut=300,  Power=39%  (S100) - Engraving"
echo "  star:      Travel=2000, Cut=600,  Power=71%  (S180) - High precision (3 passes)"
echo "  hexagon:   Travel=3000, Cut=800,  Power=86%  (S220) - With dwell time (100ms)"
echo "  line:      Travel=5000, Cut=1200, Power=31%  (S80)  - Scoring"
echo "  polyline:  Travel=3500, Cut=900,  Power=47%  (S120) - Decorative work"
echo ""
echo "Power settings reference:"
echo "  S0-S63:    Very low power (0-25%)   - Light engraving, scoring"
echo "  S64-S127:  Low power (25-50%)       - Engraving, thin materials"
echo "  S128-S191: Medium power (50-75%)    - Standard cutting"
echo "  S192-S255: High power (75-100%)     - Thick materials, deep cuts"
echo ""
echo "All G-code files are ready for use with your laser cutter!"
