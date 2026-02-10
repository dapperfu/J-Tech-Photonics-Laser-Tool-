from xml.etree import ElementTree
from typing import List, Optional
from copy import deepcopy
import math

from svg_to_gcode.svg_parser import Path, Transformation
from svg_to_gcode.geometry import Curve

NAMESPACES = {'svg': 'http://www.w3.org/2000/svg'}


def _has_style(element: ElementTree.Element, key: str, value: str) -> bool:
    """
    Check if an element contains a specific key and value either as an independent attribute or in the style attribute.
    """
    return element.get(key) == value or (element.get("style") and f"{key}:{value}" in element.get("style"))


def _get_float_attr(element: ElementTree.Element, attr: str, default: float = 0.0) -> float:
    """Get a float attribute value, handling units."""
    value = element.get(attr)
    if value is None:
        return default
    # Remove units if present
    if value.endswith('px') or value.endswith('pt') or value.endswith('mm') or value.endswith('in'):
        value = value[:-2]
    try:
        return float(value)
    except ValueError:
        return default


def _shape_to_path_data(element: ElementTree.Element) -> Optional[str]:
    """
    Convert SVG shape elements (circle, rect, ellipse, line, polyline, polygon) to path data.
    Returns path data string or None if element is not a supported shape.
    """
    tag = element.tag.split('}')[-1] if '}' in element.tag else element.tag
    svg_ns = NAMESPACES['svg']
    
    if tag == 'circle':
        cx = _get_float_attr(element, 'cx', 0)
        cy = _get_float_attr(element, 'cy', 0)
        r = _get_float_attr(element, 'r', 0)
        if r <= 0:
            return None
        # Circle as path: M cx-r,cy A r,r 0 1,1 cx+r,cy A r,r 0 1,1 cx-r,cy
        return f"M {cx-r},{cy} A {r},{r} 0 1,1 {cx+r},{cy} A {r},{r} 0 1,1 {cx-r},{cy} Z"
    
    elif tag == 'ellipse':
        cx = _get_float_attr(element, 'cx', 0)
        cy = _get_float_attr(element, 'cy', 0)
        rx = _get_float_attr(element, 'rx', 0)
        ry = _get_float_attr(element, 'ry', 0)
        if rx <= 0 or ry <= 0:
            return None
        # Ellipse as path: M cx-rx,cy A rx,ry 0 1,1 cx+rx,cy A rx,ry 0 1,1 cx-rx,cy
        return f"M {cx-rx},{cy} A {rx},{ry} 0 1,1 {cx+rx},{cy} A {rx},{ry} 0 1,1 {cx-rx},{cy} Z"
    
    elif tag == 'rect':
        x = _get_float_attr(element, 'x', 0)
        y = _get_float_attr(element, 'y', 0)
        width = _get_float_attr(element, 'width', 0)
        height = _get_float_attr(element, 'height', 0)
        rx = _get_float_attr(element, 'rx', 0)
        ry = _get_float_attr(element, 'ry', 0)
        
        if width <= 0 or height <= 0:
            return None
        
        # Handle rounded rectangles
        if rx > 0 or ry > 0:
            if ry == 0:
                ry = rx
            if rx == 0:
                rx = ry
            rx = min(rx, width / 2)
            ry = min(ry, height / 2)
            # Rounded rectangle path
            return (f"M {x+rx},{y} "
                   f"L {x+width-rx},{y} "
                   f"A {rx},{ry} 0 0,1 {x+width},{y+ry} "
                   f"L {x+width},{y+height-ry} "
                   f"A {rx},{ry} 0 0,1 {x+width-rx},{y+height} "
                   f"L {x+rx},{y+height} "
                   f"A {rx},{ry} 0 0,1 {x},{y+height-ry} "
                   f"L {x},{y+ry} "
                   f"A {rx},{ry} 0 0,1 {x+rx},{y} Z")
        else:
            # Simple rectangle
            return f"M {x},{y} L {x+width},{y} L {x+width},{y+height} L {x},{y+height} Z"
    
    elif tag == 'line':
        x1 = _get_float_attr(element, 'x1', 0)
        y1 = _get_float_attr(element, 'y1', 0)
        x2 = _get_float_attr(element, 'x2', 0)
        y2 = _get_float_attr(element, 'y2', 0)
        return f"M {x1},{y1} L {x2},{y2}"
    
    elif tag == 'polyline':
        points = element.get('points', '')
        if not points:
            return None
        # Parse points and create path
        coords = []
        for part in points.replace(',', ' ').split():
            try:
                coords.append(float(part))
            except ValueError:
                continue
        if len(coords) < 4:
            return None
        path_data = f"M {coords[0]},{coords[1]}"
        for i in range(2, len(coords), 2):
            path_data += f" L {coords[i]},{coords[i+1]}"
        return path_data
    
    elif tag == 'polygon':
        points = element.get('points', '')
        if not points:
            return None
        # Parse points and create closed path
        coords = []
        for part in points.replace(',', ' ').split():
            try:
                coords.append(float(part))
            except ValueError:
                continue
        if len(coords) < 4:
            return None
        path_data = f"M {coords[0]},{coords[1]}"
        for i in range(2, len(coords), 2):
            path_data += f" L {coords[i]},{coords[i+1]}"
        path_data += " Z"
        return path_data
    
    return None


# Todo deal with viewBoxes
def parse_root(root: ElementTree.Element, transform_origin=True, canvas_height=None, draw_hidden=False,
               visible_root=True, root_transformation=None, layer_name=None) -> List[Curve]:

    """
    Recursively parse an etree root's children into geometric curves.

    :param root: The etree element who's children should be recursively parsed. The root will not be drawn.
    :param canvas_height: The height of the canvas. By default the height attribute of the root is used. If the root
    does not contain the height attribute, it must be either manually specified or transform must be False.
    :param transform_origin: Whether or not to transform input coordinates from the svg coordinate system to standard
    cartesian system. Depends on canvas_height for calculations.
    :param draw_hidden: Whether or not to draw hidden elements based on their display, visibility and opacity attributes.
    :param visible_root: Specifies whether or the root is visible. (Inheritance can be overridden)
    :param root_transformation: Specifies whether the root's transformation. (Transformations are inheritable)
    :param layer_name: Optional layer name to filter by. If specified, only process paths within layers matching this name.
    :return: A list of geometric curves describing the svg. Use the Compiler sub-module to compile them to gcode.
    """

    if canvas_height is None:
        height_str = root.get("height")
        canvas_height = float(height_str) if height_str.isnumeric() else float(height_str[:-2])

    curves = []

    # Check if this element is a layer and if we should process it
    inkscape_ns = "http://www.inkscape.org/namespaces/inkscape"
    is_layer = root.get(f"{{{inkscape_ns}}}groupmode") == "layer"
    layer_label = root.get(f"{{{inkscape_ns}}}label")
    
    # Track if we're inside the target layer (for recursive calls)
    inside_target_layer = False
    should_recurse = True
    
    if layer_name is not None:
        # If this is a layer
        if is_layer:
            # If it matches the target layer, we're now inside it
            if layer_label == layer_name:
                inside_target_layer = True
                should_recurse = True  # Process this layer and its children
            else:
                # This layer doesn't match, skip it and all its children
                return curves
        else:
            # We're not in a layer yet, but layer_name is specified
            # We need to recurse to find matching layers
            # Don't process paths at this level, but do recurse
            inside_target_layer = False
            should_recurse = True
    else:
        # No layer filtering, process everything
        inside_target_layer = True
        should_recurse = True

    # Draw visible elements (Depth-first search)
    for element in list(root):

        # display cannot be overridden by inheritance. Just skip the element
        display = _has_style(element, "display", "none")

        if display or element.tag == "{%s}defs" % NAMESPACES["svg"]:
            continue

        transformation = deepcopy(root_transformation) if root_transformation else None

        transform = element.get('transform')
        if transform:
            transformation = Transformation() if transformation is None else transformation
            transformation.add_transform(transform)

        # Is the element and it's root not hidden?
        visible = visible_root and not (_has_style(element, "visibility", "hidden")
                                        or _has_style(element, "visibility", "collapse"))
        # Override inherited visibility
        visible = visible or (_has_style(element, "visibility", "visible"))

        # If the current element is opaque and visible, draw it
        # Only process paths if we're inside the target layer (or no layer filtering)
        if (draw_hidden or visible) and (inside_target_layer or layer_name is None):
            if element.tag == "{%s}path" % NAMESPACES["svg"]:
                path = Path(element.attrib['d'], canvas_height, transform_origin, transformation)
                curves.extend(path.curves)
            else:
                # Try to convert shape elements (circle, rect, ellipse, etc.) to path data
                path_data = _shape_to_path_data(element)
                if path_data:
                    path = Path(path_data, canvas_height, transform_origin, transformation)
                    curves.extend(path.curves)

        # Continue the recursion
        # Recurse if we should (either inside target layer, or searching for target layer)
        if should_recurse:
            # When inside the target layer, we need to process all nested elements (groups, paths, etc.)
            # But we need to be careful: if we encounter another layer inside, we should skip it
            # unless it's also the target layer (which shouldn't happen in normal SVG structure)
            # The solution: when inside_target_layer is True, pass None to process all nested elements
            # When still searching, pass layer_name to continue the search
            if inside_target_layer:
                # We're inside the target layer - process all nested elements by passing None
                # This allows nested groups to be processed without layer filtering
                curves.extend(parse_root(element, transform_origin, canvas_height, draw_hidden, visible, transformation, None))
            else:
                # Still searching for the target layer, continue with layer_name
                curves.extend(parse_root(element, transform_origin, canvas_height, draw_hidden, visible, transformation, layer_name))

    # ToDo implement shapes class
    return curves


def parse_string(svg_string: str, transform_origin=True, canvas_height=None, draw_hidden=False, layer_name=None) -> List[Curve]:
    """
        Recursively parse an svg string into geometric curves. (Wrapper for parse_root)

        :param svg_string: The etree element who's children should be recursively parsed. The root will not be drawn.
        :param canvas_height: The height of the canvas. By default the height attribute of the root is used. If the root
        does not contain the height attribute, it must be either manually specified or transform_origin must be False.
        :param transform_origin: Whether or not to transform input coordinates from the svg coordinate system to standard cartesian
         system. Depends on canvas_height for calculations.
        :param draw_hidden: Whether or not to draw hidden elements based on their display, visibility and opacity attributes.
        :param layer_name: Optional layer name to filter by. If specified, only process paths within layers matching this name.
        :return: A list of geometric curves describing the svg. Use the Compiler sub-module to compile them to gcode.
    """
    root = ElementTree.fromstring(svg_string)
    return parse_root(root, transform_origin, canvas_height, draw_hidden, layer_name=layer_name)


def parse_file(file_path: str, transform_origin=True, canvas_height=None, draw_hidden=False, layer_name=None) -> List[Curve]:
    """
            Recursively parse an svg file into geometric curves. (Wrapper for parse_root)

            :param file_path: The etree element who's children should be recursively parsed. The root will not be drawn.
            :param canvas_height: The height of the canvas. By default the height attribute of the root is used. If the root
            does not contain the height attribute, it must be either manually specified or transform_origin must be False.
            :param transform_origin: Whether or not to transform input coordinates from the svg coordinate system to standard cartesian
             system. Depends on canvas_height for calculations.
            :param draw_hidden: Whether or not to draw hidden elements based on their display, visibility and opacity attributes.
            :param layer_name: Optional layer name to filter by. If specified, only process paths within layers matching this name.
            :return: A list of geometric curves describing the svg. Use the Compiler sub-module to compile them to gcode.
        """
    root = ElementTree.parse(file_path).getroot()
    return parse_root(root, transform_origin, canvas_height, draw_hidden, layer_name=layer_name)
