# LuxVim Installer — Full Spectacle Redesign

## Goal

Transform the `install.sh` script from a functional installer into a visually striking, branded experience. The installer should feel like part of the LuxVim product — matching the dashboard's orange-to-purple gradient identity with animated reveals and clear progress feedback.

## Design

### Section 1: Logo Reveal

- Render the full 29-line Braille logo from `lua/plugins/ui/config/luxdash.lua` (lines 85–113)
- Apply a **truecolor gradient** from orange (`#ff7801`, top) to purple (`#db2dee`, bottom) using `\033[38;2;R;G;Bm` escapes
- **Animated reveal**: print each line with ~30ms delay for a cascade effect
- **Center** the logo horizontally based on terminal width (`tput cols`)
- **Truecolor detection**: check `$COLORTERM` for `truecolor` or `24bit`. If unsupported, fall back to static bold white text (no gradient, no animation)
- Hide cursor during reveal, restore after

### Section 2: System Info Panel

Displayed immediately after the logo. A box-drawn panel showing the install environment:

```
  ┌─ System ──────────────────────┐
  │  Neovim    v0.11.1            │
  │  OS        Linux 6.19.10      │
  │  Shell     fish               │
  │  Path      ~/Development/...  │
  └───────────────────────────────┘
```

- Box-drawing characters (`┌ ─ ┐ │ └ ┘`) for the border
- Border rendered in dim white
- Labels left-aligned, values right-padded
- **Neovim version**: from `nvim --version | head -1`
- **OS**: `uname -sr`, truncated to kernel + major version
- **Shell**: basename of `$SHELL`
- **Path**: `$LUXVIM_DIR`, shortened with `~` substitution, truncated if wider than the box

### Section 3: Installation Steps

Prerequisite checks use the existing checkmark style:

```
  ✓ Neovim found
  ✓ Git found
  ✓ Created lux command
  ✓ Created data directories
```

The two slow operations (cloning lazy.nvim, syncing plugins) use **progress bars**:

```
  ████████████░░░░░░░░░░░░░░░░░░░  Installing plugins (6/14)...
```

Progress bar details:

- **Bar width**: 32 characters
- **Fill character**: `█` (full block)
- **Empty character**: `░` (light shade)
- **Gradient fill**: filled portion transitions from orange (left) to purple (right), matching the logo gradient — each filled cell gets its own truecolor escape
- **Lazy.nvim clone**: indeterminate (bouncing/filling animation) since there's no progress signal from git clone — or use spinner if simpler. The operation is fast (~1-2s), so a spinner is acceptable here.
- **Plugin sync**: semi-determinate. Tail the log file in a loop, count `Finished task clone` lines as they appear. Display `(N installed)` with the bar filling based on elapsed time (pulse/fill animation). On completion, replace with checkmark showing final count.
- On completion, the progress bar line is **replaced** (via `\r`) with a green checkmark line: `✓ Installed 14 plugins`
- Hide cursor during progress, restore after

**Fallback** (no truecolor): plain `█` and `░` without gradient coloring.

### Section 4: Completion Summary

A boxed summary matching the system info panel style:

```
  ┌─ Install Complete ────────────┐
  │  Plugins    14 installed      │
  │  Time       4.2s              │
  └───────────────────────────────┘

  LuxVim is ready! Run lux to start.
```

- **Plugins**: count from the sync step
- **Time**: wall-clock duration from script start (`$SECONDS` or `date +%s.%N` delta), displayed as `X.Xs`
- **Closing line**: "LuxVim is ready!" in bold green, "lux" in cyan
- Empty line before and after the box for breathing room

### Error Handling

- If any step fails, the progress bar or spinner is replaced with a red `✗` line and the error message
- For plugin sync failure: dump the full log file contents so the user can debug
- `set -e` remains active; the `trap` should restore the cursor on unexpected exit

### Truecolor Fallback Strategy

Detection: `[[ "$COLORTERM" == "truecolor" || "$COLORTERM" == "24bit" ]]`

| Feature | Truecolor | Fallback |
|---|---|---|
| Logo | Orange→purple gradient, animated | Bold white, no animation |
| Progress bar fill | Gradient fill | Plain green `█` |
| Boxes & checkmarks | Same | Same |

### PATH Warning

Same as current: if `~/.local/bin` is not in `$PATH`, show a yellow warning with instructions. Placed after the `lux` command creation step, before the progress bars.

## Files Modified

- `install.sh` — full rewrite of the installer script

## Out of Scope

- Windows installer (`install.ps1`) — separate effort
- Uninstall script — not part of this design
- Changes to the dashboard logo itself
