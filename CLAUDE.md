# CLAUDE.md

## Project Overview

emacs-libgterm is a terminal emulator for Emacs using libghostty-vt (from the Ghostty terminal emulator) as the backend. It follows the same three-layer architecture as emacs-libvterm: terminal library (Zig) → dynamic module (Zig/C ABI) → Elisp interface.

## Build & Test

```bash
# Build the dynamic module
zig build

# Run Zig unit tests
zig build test

# Run integration test in batch Emacs
/Applications/Emacs.app/Contents/MacOS/Emacs --batch --eval '
(progn
  (module-load "zig-out/lib/libgterm-module.dylib")
  (let ((term (gterm-new 80 24)))
    (gterm-feed term "Hello\r\n")
    (message "%s" (gterm-content term))
    (gterm-free term)))'
```

After rebuilding the `.dylib`, Emacs must be restarted — dynamic modules cannot be reloaded at runtime.

## Project Structure

```
├── build.zig          # Zig build system, ghostty dependency config
├── build.zig.zon      # Package manifest
├── src/
│   ├── gterm.zig      # Main module: ghostty-vt ↔ Emacs bridge
│   │                  #   GtermInstance wrapper, cell-by-cell renderer,
│   │                  #   Emacs module functions (gterm-new, gterm-feed, etc.)
│   └── emacs_env.zig  # Emacs module API via @cImport of emacs-module.h
├── gterm.el           # Elisp: major mode, PTY, keybindings, display
└── vendor/ghostty/    # Ghostty source (git-ignored, cloned separately)
```

## Key Technical Details

### Ghostty Build Patch
Ghostty's `build.zig` must be patched to guard XCFramework/macOS app initialization behind `emit-xcframework` flag. Without this, builds fail on systems without full Xcode. Our `build.zig` passes `emit-xcframework=false`, `emit-macos-app=false`, `emit-exe=false` via `lazyDependency`.

### Emacs Module API
Bindings use `@cImport` of the real `emacs-module.h` header (from `/Applications/Emacs.app/Contents/Resources/include/`) for guaranteed ABI correctness. The include path is configurable via `-Demacs-include=`.

### Cell-by-Cell Rendering
The renderer (`GtermInstance.renderContent`) iterates ghostty-vt's page grid cell-by-cell:
- Empty cells mid-line → spaces
- Trailing empty cells → trimmed (EOL detection)
- Wide characters → skip spacer_tail cells
- Grapheme clusters → append combining codepoints
- Column tracking: compares terminal column position with estimated Emacs display column (via `emacsCharWidth`), inserting padding spaces to compensate for width mismatches

### Terminal Access Pattern
```zig
const screen = self.terminal.screens.active;  // *Screen pointer
const page_list = &screen.pages;
const pin = page_list.pin(.{ .viewport = .{ .x = 0, .y = row } });
const page = &pin.node.data;
const page_row = page.getRow(pin.y);
const page_cells = page.getCells(page_row);
// cell.codepoint(), cell.wide, cell.content_tag, page.lookupGrapheme(cell)
```

### Shell Configuration
The user's Emacs `SHELL` env var resolves to bare `bash` which launches Node.js. Default shell is hardcoded to `/bin/zsh`.

## Conventions

- Zig 0.15.2 API: use `std.array_list.Managed(T)` not `std.ArrayList(T).init()`
- Emacs env function pointers are optional in @cImport: unwrap with `.?` (e.g., `env.intern.?(env, "nil")`)
- Export `plugin_is_GPL_compatible` as a mutable `var` for Emacs GPL check
- Export `emacs_module_init` with `callconv(.c)` for the module entry point
