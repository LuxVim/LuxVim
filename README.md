# LuxVim New

A modern Neovim distribution built with lazy.nvim, following optimal project structure patterns.

## Features

- **Modern Plugin Management**: Uses lazy.nvim for efficient plugin loading
- **Modular Configuration**: Clean separation of concerns with dedicated config modules
- **LazyVim-inspired Structure**: Follows proven patterns from the LazyVim ecosystem
- **Extensive Theme Support**: Pre-configured with many popular colorschemes
- **LuxVim Ecosystem**: Full integration with LuxVim plugins and utilities

## Structure

```
LuxVim_New/
├── init.lua                 # Entry point
├── lua/
│   ├── config/             # Core configuration
│   │   ├── lazy.lua        # Plugin manager setup
│   │   ├── options.lua     # Neovim options
│   │   ├── keymaps.lua     # Key mappings
│   │   └── autocmds.lua    # Auto commands
│   ├── plugins/            # Plugin specifications
│   │   ├── core.lua        # Core plugins (fzf, nerdtree, etc.)
│   │   ├── luxvim.lua      # LuxVim specific plugins
│   │   ├── editor.lua      # Editor enhancement plugins
│   │   └── colorschemes.lua # Theme configurations
│   └── utils.lua           # Utility functions
├── LICENSE
└── README.md
```

## Installation

1. Backup your existing Neovim configuration
2. Copy LuxVim_New to your Neovim config directory:
   ```bash
   cp -r LuxVim_New ~/.config/nvim
   ```
3. Start Neovim - lazy.nvim will automatically install plugins

## Key Mappings

- `<Space>` - Leader key
- `<leader>fs` - Save file
- `<leader>fq` - Quit
- `<leader>e` - Toggle NERDTree
- `<leader><leader>` - Open file finder
- `<leader>t` - Search text in project
- `<leader>m` - EasyOps menu
- `Ctrl+_` - Toggle terminal

## Themes

LuxVim New comes with extensive theme support including:
- **LuxVim themes**: lux.nvim, voidpulse.nvim
- **Popular themes**: Catppuccin, Tokyo Night, Gruvbox, Nord, and many more
- **Conditional loading**: Neovim-only themes load conditionally

## Plugins

### Core Plugins
- **fzf**: Fuzzy file finding
- **NERDTree**: File explorer
- **vim-smoothie**: Smooth scrolling

### LuxVim Ecosystem
- **vim-luxpane**: Advanced window management
- **vim-luxdash**: Beautiful dashboard
- **luxdash.nvim**: Modern dashboard implementation

### Editor Enhancements
- **vim-easyline**: Customizable statusline
- **vim-easycomment**: Smart commenting
- **vim-easyops**: Operation menu system
- **vim-tidyterm**: Terminal management
- **vim-backtrack**: File history tracking

## Configuration

All configuration is modular and located in `lua/config/`. Plugin specifications are in `lua/plugins/` and automatically loaded by lazy.nvim.

## Migration from Original LuxVim

LuxVim New maintains backward compatibility with original LuxVim while providing a modern, optimized structure. All original functionality is preserved but organized following current Neovim best practices.