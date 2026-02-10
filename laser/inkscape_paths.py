"""
Auto-detect Inkscape Python paths for importing inkex module.

This module detects Inkscape installation paths across different platforms
and adds them to sys.path to enable importing the inkex module.
"""

import os
import sys
from pathlib import Path
from typing import List


def detect_inkscape_paths() -> List[str]:
    """
    Detect Inkscape Python paths across platforms.

    Returns:
        List of paths to add to sys.path for importing inkex
    """
    paths = []

    # Check environment variable first
    inkscape_path = os.environ.get("INKSCAPE_PATH")
    if inkscape_path:
        paths.append(inkscape_path)

    # Platform-specific detection
    if sys.platform == "linux":
        # Linux paths
        linux_paths = [
            "/usr/share/inkscape/extensions",
            os.path.expanduser("~/.config/inkscape/extensions"),
            "/usr/local/share/inkscape/extensions",
        ]
        paths.extend([p for p in linux_paths if os.path.isdir(p)])

    elif sys.platform == "darwin":
        # macOS paths
        macos_paths = [
            "/Applications/Inkscape.app/Contents/Resources/extensions",
            os.path.expanduser("~/Library/Application Support/Inkscape/extensions"),
            "/opt/local/share/inkscape/extensions",  # MacPorts
            "/usr/local/share/inkscape/extensions",  # Homebrew
        ]
        paths.extend([p for p in macos_paths if os.path.isdir(p)])

    elif sys.platform == "win32":
        # Windows paths
        program_files = os.environ.get("ProgramFiles", "C:\\Program Files")
        program_files_x86 = os.environ.get("ProgramFiles(x86)", "C:\\Program Files (x86)")
        appdata = os.environ.get("APPDATA", os.path.expanduser("~\\AppData\\Roaming"))

        windows_paths = [
            os.path.join(program_files, "Inkscape", "share", "inkscape", "extensions"),
            os.path.join(program_files_x86, "Inkscape", "share", "inkscape", "extensions"),
            os.path.join(appdata, "inkscape", "extensions"),
        ]
        paths.extend([p for p in windows_paths if os.path.isdir(p)])

    return paths


def add_inkscape_paths():
    """
    Add detected Inkscape paths to sys.path.

    This function should be called before importing inkex.
    """
    paths = detect_inkscape_paths()
    for path in paths:
        if path not in sys.path:
            sys.path.insert(0, path)


def find_inkex():
    """
    Try to find and import inkex module.

    Returns:
        The inkex module if found, None otherwise
    """
    add_inkscape_paths()
    try:
        import inkex
        return inkex
    except ImportError:
        return None
