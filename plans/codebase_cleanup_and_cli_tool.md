---
name: Codebase Cleanup and CLI Tool
overview: Clean up the codebase by removing the redundant 251/ directory, merge svg_to_gcode/ from 251/ into the main codebase (removing submodule dependency for single clone command), add layer selection feature for processing specific SVG layers, create a standalone CLI tool for SVG to G-code conversion with automatic Inkscape path detection, provide examples, and merge to main branch while removing master branch.
todos:
  - id: save-plan
    content: Save plan to plans/ directory
    status: in_progress
  - id: remove-submodule
    content: "Remove svg_to_gcode submodule: remove from git index, delete .git file, update .gitmodules"
    status: pending
  - id: verify-code-completeness
    content: Verify all code from 251/svg_to_gcode/ is present in laser/svg_to_gcode/
    status: pending
  - id: cleanup-251
    content: Remove 251/ directory and update .gitignore for Python artifacts
    status: pending
  - id: inkscape-paths
    content: Create inkscape_paths.py module for auto-detecting Inkscape Python paths on all platforms
    status: pending
  - id: add-layer-filtering
    content: Add layer filtering to parse_root() and parser functions in svg_to_gcode/svg_parser/_parser_methods.py
    status: pending
  - id: add-layer-extension
    content: Add layer parameter support to laser.py extension and laser.inx UI
    status: pending
  - id: extract-converter
    content: Extract core conversion logic from laser.py into reusable converter module
    status: pending
  - id: create-cli
    content: Create cli.py with Click commands for standalone SVG to G-code conversion (including --layer option)
    status: pending
  - id: update-requirements
    content: Update requirements.txt with Click and TOML dependencies, remove svg-to-gcode note
    status: pending
  - id: create-examples
    content: Create examples/ directory with basic and advanced usage examples
    status: pending
  - id: update-readme
    content: Update README.md with CLI tool documentation and self-contained codebase note
    status: pending
  - id: git-main-merge
    content: Merge current branch into main and remove master branch (local and remote)
    status: pending
---

# Codebase Cleanup and CLI Tool Implementation with Submodule Removal

## Analysis Summary

### What was added from 251/ to laser/:

1. **New functions/methods**:

   - `extract_number()` - Extracts numeric values from strings (for document width/height parsing)
   - `get_bed_size()` - Method to get bed size from document or user input

2. **New features**:

   - `use_document_size` checkbox option - Uses document dimensions as bed size
   - `zero_machine` checkbox option - Adds G92 command to zero machine coordinates
   - Travel speed in move-to-origin footer command

3. **Code improvements**:

   - Better code formatting (ruff formatted)
   - Improved import organization
   - README.md added to svg_to_gcode/ directory

4. **UI changes**:

   - Added `zero_machine` parameter to laser.inx (line 51)
   - Added `use_document_size` parameter to laser.inx (line 53)

### Submodule Status:

- `laser/svg_to_gcode/` is currently a git submodule (has `.git` file, referenced in `.gitmodules`)
- `251/svg_to_gcode/` is a regular directory (not a submodule)
- Both directories contain the same 26 Python files
- The codebase should be self-contained without submodule dependencies for single clone command

## Implementation Plan

### 1. Submodule Removal and Code Merge

**Remove submodule status from `laser/svg_to_gcode/`:**

- Remove `.git` file from `laser/svg_to_gcode/` (this makes it a regular directory)
- Remove submodule entry from `.gitmodules`:
  ```
  [submodule "laser/svg_to_gcode"]
  	path = laser/svg_to_gcode
  	url = git@github.com:dapperfu/svg_to_gcode.git
  ```

- Remove submodule from git index: `git rm --cached laser/svg_to_gcode`
- Verify all code from `251/svg_to_gcode/` is present in `laser/svg_to_gcode/` (they appear identical)
- Keep `.gitignore` in `laser/svg_to_gcode/` (contains `__pycache__/`)
- Keep `README.md` in `laser/svg_to_gcode/` (documentation)

**Result:** `laser/svg_to_gcode/` becomes a regular directory in the repository, making the codebase fully self-contained and cloneable with a single `git clone` command - no `git submodule update --init` needed.

### 2. Codebase Cleanup

**Files to remove:**

- `251/` directory (entire directory is redundant, all changes are in `laser/`)
- Any `__pycache__/` directories (should be in .gitignore)

**Files to update:**

- `.gitignore` - Ensure `__pycache__/` and other Python artifacts are ignored
- `README.md` - Update to reflect CLI tool availability, self-contained codebase (single clone command)
- `requirements.txt` - Remove `svg-to-gcode` dependency note (it's now in the codebase)

### 3. Layer Selection Feature

**Add layer filtering capability:**

- Modify `parse_root()` in `svg_to_gcode/svg_parser/_parser_methods.py` to accept optional `layer_name` parameter
- Filter SVG elements by Inkscape layer label (`inkscape:label` attribute)
- Layers are identified by `inkscape:groupmode="layer"` and `inkscape:label` attributes
- When `layer_name` is specified, only process paths within that layer
- Support both Inkscape extension and CLI tool

**Implementation details:**

- Add `layer_name` parameter to `parse_root()`, `parse_string()`, and `parse_file()` functions
- Check if element has `inkscape:groupmode="layer"` and `inkscape:label` matches specified layer
- Only recurse into matching layers or their children
- Generate separate G-code files per layer when multiple layers are processed
- Add `--layer` option to CLI tool
- Add `layer` parameter to Inkscape extension UI (optional dropdown or text input)

**File updates:**

- `laser/svg_to_gcode/svg_parser/_parser_methods.py` - Add layer filtering logic
- `laser/laser.py` - Add layer parameter support
- `laser/laser.inx` - Add layer selection UI element
- `laser/cli.py` - Add `--layer` Click option

### 4. CLI Tool Implementation

**Create standalone CLI tool** (`cli.py` or `laser_cli.py`):

- Use Click library (per `.cursor/rules/python/click-required.mdc`)
- Extract core conversion logic from `laser.py` into reusable functions
- Support all parameters from the Inkscape extension
- Auto-detect Inkscape Python paths for `inkex` import
- Support TOML configuration (per `.cursor/rules/python/toml-config.mdc`)
- Support layer selection via `--layer` option

**Key components:**

- `InkscapePathDetector` class - Auto-detect Inkscape installation paths
  - Linux: `/usr/share/inkscape/extensions/`, `~/.config/inkscape/extensions/`
  - macOS: `/Applications/Inkscape.app/Contents/Resources/extensions/`, `~/Library/Application Support/Inkscape/extensions/`
  - Windows: `C:\Program Files\Inkscape\share\inkscape\extensions\`, `%APPDATA%\inkscape\extensions\`
- `SVGToGcodeConverter` class - Core conversion logic extracted from `GcodeExtension`
- Click command structure with options matching extension parameters
- Layer selection support: `--layer "cut"` generates `output_cut.gcode`, `--layer "engrave"` generates `output_engrave.gcode`

**File structure:**

```
laser/
├── laser.py (existing - Inkscape extension)
├── laser.inx (existing)
├── cli.py (new - standalone CLI tool)
├── inkscape_paths.py (new - path detection)
└── svg_to_gcode/ (existing - now regular directory, not submodule)
```

### 5. Inkscape Path Auto-Detection

**Implementation:**

- Create `inkscape_paths.py` module
- Detect Inkscape installation paths on all platforms
- Add detected paths to `sys.path` before importing `inkex`
- Fallback to environment variable `INKSCAPE_PATH` if auto-detection fails
- Provide clear error messages if `inkex` cannot be found

**Path detection logic:**

```python
def detect_inkscape_paths() -> List[str]:
    """Detect Inkscape Python paths across platforms."""
    paths = []
    # Platform-specific detection
    # Return list of paths to add to sys.path
```

### 6. Examples

**Create `examples/` directory:**

- `examples/basic_usage.sh` - Simple SVG to G-code conversion
- `examples/advanced_usage.sh` - Custom headers, multiple passes, offsets
- `examples/README.md` - Documentation for examples
- `examples/sample.svg` - Sample SVG file for testing

**Example content:**

- Basic: Simple conversion with default settings
- Advanced: Custom headers/footers, coordinate transformations, multiple passes
- Layer selection: Process specific layers (e.g., `--layer "cut"` for cutting layer only)

### 7. Git Operations

**Branch management:**

1. Checkout `main` branch (create if doesn't exist)
2. Merge current branch into `main`
3. Delete `master` branch locally
4. Push changes to remote
5. Delete `master` branch on remote (if exists)

**Submodule removal steps:**

1. Remove submodule from git: `git rm --cached laser/svg_to_gcode`
2. Remove `.git` file from `laser/svg_to_gcode/`
3. Update `.gitmodules` to remove submodule entry
4. Commit submodule removal
5. Add `laser/svg_to_gcode/` as regular directory: `git add laser/svg_to_gcode/`
6. Commit the merged code

**Follow git rules:**

- Use commit format from `.cursor/rules/git/commit-format.mdc`
- Atomic commits per file (per `.cursor/rules/git/commit-atomicity.mdc`)
- Include technical attribution in commits

### 8. Project Structure Updates

**Files to create:**

- `laser/cli.py` - CLI tool implementation
- `laser/inkscape_paths.py` - Inkscape path detection
- `examples/basic_usage.sh` - Basic example
- `examples/advanced_usage.sh` - Advanced example
- `examples/README.md` - Examples documentation
- `examples/sample.svg` - Sample SVG (optional)
- `pyproject.toml` - Python project configuration (if needed)
- `Makefile` - Build/install targets (optional but recommended)

**Files to update:**

- `.gitignore` - Add Python artifacts
- `.gitmodules` - Remove `laser/svg_to_gcode` submodule entry
- `README.md` - Add CLI tool documentation, note about self-contained codebase (single clone command), layer selection feature
- `requirements.txt` - Add Click dependency, update notes
- `laser/svg_to_gcode/svg_parser/_parser_methods.py` - Add layer filtering
- `laser/laser.py` - Add layer parameter support
- `laser/laser.inx` - Add layer selection UI element

**Files to remove:**

- `251/` directory (entire directory)
- `laser/svg_to_gcode/.git` file (submodule marker)

### 9. Dependencies

**Update `requirements.txt`:**

- Add `click` for CLI
- Add `tomli` for Python < 3.11 (TOML support)
- Remove or update note about `svg-to-gcode` (now in codebase)

### 10. Testing Considerations

**CLI tool should:**

- Work without Inkscape GUI (standalone)
- Handle missing `inkex` gracefully with clear errors
- Support all extension parameters via command-line options
- Validate input files and parameters
- Provide helpful error messages

**Submodule removal verification:**

- Repository should clone without `git submodule update --init`
- All `svg_to_gcode` code should be present in `laser/svg_to_gcode/`
- No `.git` file should exist in `laser/svg_to_gcode/`

## Implementation Order

1. **Submodule removal phase:**

   - Remove submodule from git index
   - Remove `.git` file from `laser/svg_to_gcode/`
   - Update `.gitmodules`
   - Verify code completeness
   - Commit submodule removal

2. **Cleanup phase:**

   - Remove `251/` directory
   - Update `.gitignore`
   - Commit cleanup changes

3. **Layer selection phase:**

   - Add layer filtering to `parse_root()` function
   - Update parser functions to support layer parameter
   - Add layer parameter to `laser.py` extension
   - Add layer UI element to `laser.inx`
   - Add `--layer` option to CLI tool

4. **CLI tool phase:**

   - Create `inkscape_paths.py` for path detection
   - Extract conversion logic from `laser.py` into reusable functions
   - Create `cli.py` with Click commands (including layer support)
   - Update `requirements.txt`

5. **Examples phase:**

   - Create `examples/` directory
   - Add example scripts and documentation

6. **Documentation phase:**

   - Update `README.md` with CLI usage, self-contained codebase note (single clone command)
   - Add examples documentation

7. **Git operations phase:**

   - Merge to `main`
   - Remove `master` branch
   - Push changes

## Notes

- The CLI tool will reuse the existing `svg_to_gcode` library (now in the codebase)
- `inkex` is only needed for SVG parsing - we may need to create a minimal SVG parser or use `lxml` directly
- Consider creating a `converter.py` module that both `laser.py` and `cli.py` can use
- Layer selection uses Inkscape layer labels (`inkscape:label` attribute) to identify layers
- When a layer is specified, only paths within that layer are processed
- Separate G-code files are generated per layer (e.g., `output_cut.gcode`, `output_engrave.gcode`)
- Follow all Python rules from `.cursor/rules/python/`
- Follow all git rules from `.cursor/rules/git/`
- The codebase will be fully self-contained after submodule removal - single `git clone` command works, no `git submodule update --init` needed