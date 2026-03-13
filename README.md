# emacs-libgterm

Terminal emulator for Emacs built on [libghostty-vt](https://github.com/ghostty-org/ghostty), the terminal emulation library from the [Ghostty](https://ghostty.org/) terminal emulator.

This project follows the same architecture as [emacs-libvterm](https://github.com/akermu/emacs-libvterm) but uses Ghostty's terminal engine, which offers:

- SIMD-optimized VT escape sequence parsing
- Better Unicode and grapheme cluster support
- Text reflow on resize
- Kitty graphics protocol support
- Active development and maintenance

> **Status:** Early prototype. Basic terminal functionality works (shell, commands, output), but color rendering and full key handling are not yet implemented.

## Requirements

- **Emacs 25.1+** compiled with `--with-modules` (dynamic module support)
- **Zig 0.15.2+** (install via `asdf install zig 0.15.2`)
- **Git** (to clone the Ghostty source)

## Building for Development

### 1. Clone this repository

```bash
git clone https://github.com/rwc9u/emacs-libgterm.git
cd emacs-libgterm
```

### 2. Clone Ghostty as a vendor dependency

```bash
git clone --depth 1 https://github.com/ghostty-org/ghostty.git vendor/ghostty
```

### 3. Patch Ghostty's build.zig

Ghostty's `build.zig` eagerly initializes XCFramework/macOS app builds, which requires full Xcode. On systems with only CommandLineTools, apply this patch to guard those behind the `emit-xcframework` flag:

In `vendor/ghostty/build.zig`, find the three places where `GhosttyXCFramework.init` and `GhosttyLib.initShared/initStatic` are called, and guard them:

- Wrap `GhosttyLib.initShared/initStatic` (lines ~95-102) in `if (config.app_runtime == .none and !config.target.result.os.tag.isDarwin())`
- Wrap the first `GhosttyXCFramework.init` block (lines ~150-180) in `if (config.emit_xcframework)`
- Wrap the second `GhosttyXCFramework.init` in the `run:` block (line ~212) by adding `and config.emit_xcframework` to the existing Darwin check

### 4. Build

```bash
zig build
```

This produces `zig-out/lib/libgterm-module.dylib` (macOS) or `zig-out/lib/libgterm-module.so` (Linux).

### 5. Run tests

```bash
zig build test
```

### 6. Load in Emacs

Add to your `init.el`:

```elisp
(add-to-list 'load-path "/path/to/emacs-libgterm")
(require 'gterm)
```

Then `M-x gterm` to open a terminal.

> **Note:** After rebuilding the `.dylib`, you must restart Emacs — dynamic modules cannot be reloaded.

## Build Options

```bash
# Specify custom Emacs include path (for emacs-module.h)
zig build -Demacs-include=/path/to/emacs/include

# Build with optimizations
zig build -Doptimize=ReleaseFast
```

## Architecture

```
┌──────────────┐     ┌───────────────────┐     ┌─────────────┐
│   gterm.el   │────▶│  gterm-module.so  │────▶│ ghostty-vt  │
│  (Elisp)     │     │  (Zig → C ABI)    │     │ (Zig lib)   │
│              │     │                   │     │             │
│ • PTY mgmt  │     │ • Terminal create │     │ • VT parse  │
│ • Keybinds  │     │ • Feed bytes     │     │ • Screen    │
│ • Display   │     │ • Cell rendering │     │ • Cursor    │
│ • Mode      │     │ • Cursor pos     │     │ • Reflow    │
└──────────────┘     └───────────────────┘     └─────────────┘
```

## Known Issues

- **No color rendering** — terminal output is plain text without ANSI color faces
- **Limited key handling** — missing arrow keys, function keys, alt combinations
- **No scrollback** — only the visible viewport is rendered
- **Character width mismatches** — some Unicode characters (Powerline glyphs, NerdFont icons) may render at different widths in Emacs vs the terminal, causing alignment issues. Column-aware rendering compensates for most cases.

## License

GPL-3.0 (required for Emacs dynamic modules)
