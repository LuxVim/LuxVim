# Theme Picker Design

## Problem

All colorschemes are downloaded during LuxVim install, even though users typically only use one or two. This wastes bandwidth and disk space.

## Solution

Ship a minimal default bundle and provide an in-editor picker for discovering and installing optional themes.

## Default Bundle (5 themes)

- **nami** - LuxVim default, priority loaded
- **catppuccin** - Popular, 4 variants, excellent plugin support
- **tokyonight** - Popular, multiple variants, great Treesitter support
- **gruvbox** - Classic, huge community
- **dracula** - Popular dark theme

## Architecture

### File Structure

```
lua/
├── core/
│   └── theme-picker/
│       ├── init.lua        # Entry point, :Themes command
│       ├── catalog.lua     # Theme definitions (data only)
│       ├── ui.lua          # Floating window
│       └── preview.lua     # Live preview logic
├── plugins/
│   └── colorschemes.lua    # Default bundle + loads installed
```

### Theme Catalog Format

`lua/core/theme-picker/catalog.lua`:

```lua
return {
  {
    repo = "rose-pine/neovim",
    name = "rose-pine",
    description = "Minimal, dark and light variants",
    variants = { "rose-pine", "rose-pine-moon", "rose-pine-dawn" },
    nvim_only = true,
  },
  {
    repo = "sainnhe/everforest",
    name = "everforest",
    description = "Green-based, easy on eyes",
  },
  -- ... additional optional themes
}
```

Fields:
- **repo** - GitHub path for Lazy
- **name** - Display name and Lazy plugin name
- **description** - One-liner for picker
- **variants** (optional) - Colorscheme names if theme has multiple
- **nvim_only** (optional) - Skip on Vim

## Picker UI

### Layout

```
┌─────────────── Themes ───────────────┐
│                                      │
│  INSTALLED                           │
│  ● nami (active)                     │
│    catppuccin                        │
│    tokyonight                        │
│    gruvbox                           │
│    dracula                           │
│                                      │
│  ─────────────────────────────────   │
│                                      │
│  AVAILABLE                           │
│    rose-pine    Minimal, dark/light  │
│    everforest   Green-based, easy... │
│    nightfox     Multiple fox-themed  │
│    kanagawa     Wave-inspired, dark  │
│    ...                               │
│                                      │
│  [Enter] Apply  [i] Install  [q] Close│
└──────────────────────────────────────┘
```

### Keybindings

- `j/k` or arrows - Navigate
- `Enter` - Apply (installed) or Install+Apply (available)
- `x` - Uninstall optional theme
- `q` / `Esc` - Close, revert to original theme

### Live Preview

Theme applies as cursor moves through installed themes. Original theme restored on close without selection.

## Installation Mechanics

### Runtime Installation

Use Lazy's programmatic API:
```lua
require("lazy").install({ plugins = { spec } })
```

### Persistence

User-installed themes saved to `data/installed-themes.lua`:

```lua
return {
  "rose-pine",
  "everforest",
}
```

### Startup Loading

`colorschemes.lua` reads persistence file and appends specs to default bundle.

## Error Handling

### Preview on unavailable theme
Cannot preview uninstalled themes. Show description + "Press Enter to install and preview".

### Installation failure
Show error in picker status line. Keep picker open for retry.

### Theme removed from catalog
Silently skip themes in persistence file that no longer exist in catalog.

### Uninstall constraints
Cannot uninstall default bundle themes. Show message: "Default theme, cannot remove".

## Commands

- `:Themes` - Open theme picker

## Files to Create

1. `lua/core/theme-picker/init.lua` - Entry point, command registration
2. `lua/core/theme-picker/catalog.lua` - Optional theme definitions
3. `lua/core/theme-picker/ui.lua` - Floating window rendering
4. `lua/core/theme-picker/preview.lua` - Live preview logic

## Files to Modify

1. `lua/plugins/colorschemes.lua` - Reduce to default bundle, integrate with picker
