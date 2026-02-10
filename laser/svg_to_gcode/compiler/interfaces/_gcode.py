import warnings
import math

from svg_to_gcode import formulas
from svg_to_gcode.compiler.interfaces import Interface
from svg_to_gcode.geometry import Vector
from svg_to_gcode import TOLERANCES

verbose = False


class Gcode(Interface):

    def __init__(self):
        self.position = None
        self._next_speed = None
        self._current_speed = None
        self._is_travel_move = False  # Track if we're in travel mode (G0) or cutting mode (G1)

        # Round outputs to the same number of significant figures as the operational tolerance.
        self.precision = abs(round(math.log(TOLERANCES["operation"], 10)))

    def set_movement_speed(self, speed):
        self._next_speed = speed
        self._is_travel_move = True  # Movement speed indicates travel mode (G0)
        return ''
    
    def set_cutting_speed(self, speed):
        """Set cutting speed and clear travel mode flag (switches to G1 mode)"""
        self._next_speed = speed
        self._is_travel_move = False  # Cutting speed indicates cutting mode (G1)
        return ''

    def linear_move(self, x=None, y=None, z=None):

        if self._next_speed is None:
            raise ValueError("Undefined movement speed. Call set_movement_speed before executing movement commands.")

        # Don't do anything if linear move was called without passing a value.
        if x is None and y is None and z is None:
            warnings.warn("linear_move command invoked without arguments.")
            return ''

        # Use G0 for travel moves (rapid positioning, laser off), G1 for cutting moves (with feedrate)
        if self._is_travel_move:
            command = "G0"  # Rapid positioning - no feedrate, laser should be off
        else:
            command = "G1"  # Linear interpolation with feedrate for cutting
            if self._current_speed != self._next_speed:
                self._current_speed = self._next_speed
                command += f" F{self._current_speed}"
        
        # Update current speed for travel moves too (for tracking, but don't output F parameter)
        if self._is_travel_move and self._current_speed != self._next_speed:
            self._current_speed = self._next_speed

        # Move if not 0 and not None
        command += f" X{x:.{self.precision}f}" if x is not None else ''
        command += f" Y{y:.{self.precision}f}" if y is not None else ''
        command += f" Z{z:.{self.precision}f}" if z is not None else ''

        if self.position is not None or (x is not None and y is not None):
            if x is None:
                x = self.position.x

            if y is None:
                y = self.position.y

            self.position = Vector(x, y)

        if verbose:
            print(f"Move to {x}, {y}, {z}")

        return command + ';'

    def laser_off(self):
        return f"M5;"

    def set_laser_power(self, power):
        if power < 0 or power > 1:
            raise ValueError(f"{power} is out of bounds. Laser power must be given between 0 and 1. "
                             f"The interface will scale it correctly.")

        return f"M3 S{formulas.linear_map(0, 255, power)};"

    def set_absolute_coordinates(self):
        return "G90;"

    def set_relative_coordinates(self):
        return "G91;"

    def dwell(self, milliseconds):
        return f"G4 P{milliseconds}"

    def set_origin_at_position(self):
        self.position = Vector(0, 0)
        return "G92 X0 Y0 Z0;"

    def set_unit(self, unit):
        if unit == "mm":
            return "G21;"

        if unit == "in":
            return "G20;"

        return ''

    def home_axes(self):
        return "G28;"
