"""
Command-line interface for SVG to G-code conversion.

This CLI tool provides a standalone way to convert SVG files to G-code
without requiring the Inkscape GUI.
"""

import os
import sys
import warnings
from pathlib import Path
from typing import Optional

# Suppress the "empty body" warning which can be a false positive
# The warning is checked before curves are added, but the file is generated correctly
warnings.filterwarnings('ignore', message='.*Compile with an empty body.*')
warnings.filterwarnings('ignore', category=UserWarning, message='.*empty body.*')

# Add laser directory to path so svg_to_gcode can be imported
# The svg_to_gcode modules use 'from svg_to_gcode import ...' internally,
# so we need to add the laser/ directory to sys.path
laser_dir = Path(__file__).parent
if str(laser_dir) not in sys.path:
    sys.path.insert(0, str(laser_dir))

import click

# Add Inkscape paths for inkex import (optional, only needed for SVG parsing)
try:
    from laser.inkscape_paths import add_inkscape_paths
    add_inkscape_paths()
except ImportError:
    pass

from laser.converter import ConversionConfig, convert_svg_to_gcode


@click.command()
@click.argument("svg_file", type=click.Path(exists=True, readable=True))
@click.option(
    "--output", "-o",
    type=click.Path(),
    help="Output G-code file path (default: input filename with .gcode extension)"
)
@click.option(
    "--layer", "-l",
    type=str,
    help="Process only the specified layer (by Inkscape label)"
)
@click.option(
    "--unit", "-u",
    type=click.Choice(["mm", "in"], case_sensitive=False),
    default="mm",
    help="Unit of measurement (default: mm)"
)
@click.option(
    "--travel-speed", "-t",
    type=float,
    default=3000,
    help="Travel speed (unit/min, default: 3000)"
)
@click.option(
    "--cutting-speed", "-c",
    type=float,
    default=750,
    help="Cutting speed (unit/min, default: 750)"
)
@click.option(
    "--passes", "-p",
    type=int,
    default=1,
    help="Number of passes (default: 1)"
)
@click.option(
    "--pass-depth",
    type=float,
    default=1,
    help="Pass depth (unit, default: 1)"
)
@click.option(
    "--dwell-time",
    type=float,
    default=0,
    help="Dwell time before moving (ms, default: 0)"
)
@click.option(
    "--approximation-tolerance",
    type=float,
    default=0.01,
    help="Approximation tolerance (default: 0.01)"
)
@click.option(
    "--tool-power-command",
    type=str,
    default="M3 S255;",
    help="Tool power command (default: M3 S255;)"
)
@click.option(
    "--tool-off-command",
    type=str,
    default="M5;",
    help="Tool off command (default: M5;)"
)
@click.option(
    "--machine-origin",
    type=click.Choice(["bottom-left", "center", "top-left"], case_sensitive=False),
    default="bottom-left",
    help="Machine origin (default: bottom-left)"
)
@click.option(
    "--zero-machine/--no-zero-machine",
    default=False,
    help="Zero machine coordinates (G92, default: False)"
)
@click.option(
    "--invert-y-axis/--no-invert-y-axis",
    default=False,
    help="Invert Y-axis (default: False)"
)
@click.option(
    "--use-document-size/--no-use-document-size",
    default=False,
    help="Use document size as bed size (default: False)"
)
@click.option(
    "--bed-width",
    type=float,
    default=200,
    help="Bed X width (unit, default: 200)"
)
@click.option(
    "--bed-height",
    type=float,
    default=200,
    help="Bed Y length (unit, default: 200)"
)
@click.option(
    "--horizontal-offset",
    type=float,
    default=0,
    help="G-code X offset (unit, default: 0)"
)
@click.option(
    "--vertical-offset",
    type=float,
    default=0,
    help="G-code Y offset (unit, default: 0)"
)
@click.option(
    "--scaling-factor",
    type=float,
    default=1,
    help="G-code scaling factor (default: 1)"
)
@click.option(
    "--z-axis-start",
    type=float,
    default=0,
    help="Absolute Z-axis start position (unit, default: 0)"
)
@click.option(
    "--do-z-axis-start/--no-do-z-axis-start",
    default=False,
    help="Set Z-axis start position (default: False)"
)
@click.option(
    "--move-to-origin-end/--no-move-to-origin-end",
    default=False,
    help="Move to origin when done (default: False)"
)
@click.option(
    "--do-laser-off-start/--no-do-laser-off-start",
    default=True,
    help="Turn laser off before job (default: True)"
)
@click.option(
    "--do-laser-off-end/--no-do-laser-off-end",
    default=True,
    help="Turn laser off after job (default: True)"
)
@click.option(
    "--header-file",
    type=click.Path(exists=True, readable=True),
    help="Custom G-code header file"
)
@click.option(
    "--footer-file",
    type=click.Path(exists=True, readable=True),
    help="Custom G-code footer file"
)
def main(
    svg_file: str,
    output: Optional[str],
    layer: Optional[str],
    unit: str,
    travel_speed: float,
    cutting_speed: float,
    passes: int,
    pass_depth: float,
    dwell_time: float,
    approximation_tolerance: float,
    tool_power_command: str,
    tool_off_command: str,
    machine_origin: str,
    zero_machine: bool,
    invert_y_axis: bool,
    use_document_size: bool,
    bed_width: float,
    bed_height: float,
    horizontal_offset: float,
    vertical_offset: float,
    scaling_factor: float,
    z_axis_start: float,
    do_z_axis_start: bool,
    move_to_origin_end: bool,
    do_laser_off_start: bool,
    do_laser_off_end: bool,
    header_file: Optional[str],
    footer_file: Optional[str],
):
    """
    Convert SVG file to G-code.

    SVG_FILE: Path to input SVG file
    """
    # Determine output path
    if output:
        output_path = output
    else:
        svg_path = Path(svg_file)
        if layer:
            output_path = svg_path.with_suffix(f"_{layer}.gcode")
        else:
            output_path = svg_path.with_suffix(".gcode")

    # Load header and footer files
    header = []
    if header_file:
        with open(header_file, "r") as f:
            header = f.read().splitlines()

    footer = []
    if footer_file:
        with open(footer_file, "r") as f:
            footer = f.read().splitlines()

    # Create configuration
    config = ConversionConfig(
        unit=unit,
        travel_speed=travel_speed,
        cutting_speed=cutting_speed,
        passes=passes,
        pass_depth=pass_depth,
        dwell_time=dwell_time,
        approximation_tolerance=approximation_tolerance,
        tool_power_command=tool_power_command,
        tool_off_command=tool_off_command,
        machine_origin=machine_origin,
        zero_machine=zero_machine,
        invert_y_axis=invert_y_axis,
        use_document_size=use_document_size,
        bed_width=bed_width,
        bed_height=bed_height,
        horizontal_offset=horizontal_offset,
        vertical_offset=vertical_offset,
        scaling_factor=scaling_factor,
        do_z_axis_start=do_z_axis_start,
        z_axis_start=z_axis_start,
        move_to_origin_end=move_to_origin_end,
        do_laser_off_start=do_laser_off_start,
        do_laser_off_end=do_laser_off_end,
        layer_name=layer,
        header=header,
        footer=footer,
    )

    # Convert
    try:
        convert_svg_to_gcode(svg_file, str(output_path), config)
        click.echo(f"Successfully converted {svg_file} to {output_path}")
    except Exception as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
