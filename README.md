# LuxVim

LuxVim is a high-performance Neovim distribution built for developers who want powerful features, responsive editing, and a sleek interface — without the setup overhead.

## Features

- **Self-Contained**: LuxVim maintains its own data directory and doesn't interfere with your existing Neovim configuration
- **Beautiful Themes**: Comprehensive collection of 30+ colorschemes including custom LuxVim themes
- **Modern Plugins**: Curated selection of essential plugins for enhanced productivity
- **Custom Tools**: Integrated terminal, dashboard, and utility plugins built specifically for LuxVim
- **Easy Installation**: One-command installation with automatic plugin management

## Requirements

- **Neovim 0.8+** (recommended 0.9+)
- **Git** for plugin management
- **Unix-like system** (Linux, macOS, WSL)

## Quick Installation

```bash
# Clone LuxVim
git clone https://github.com/LuxVim/LuxVim.git ~/.config/LuxVim

# Run the installer
cd ~/.config/LuxVim && ./install.sh

# Start LuxVim
lux
```

## Installation Details

The installer will:
1. Create a `lux` command in `~/.local/bin/`
2. Set up data directories within the LuxVim folder
3. Bootstrap [lazy.nvim](https://github.com/folke/lazy.nvim) plugin manager
4. Install all plugins automatically

If `~/.local/bin` is not in your PATH, add this to your shell profile:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Usage

Launch LuxVim using the `lux` command:

```bash
# Open LuxVim
lux

# Open a specific file
lux myfile.txt

# Open in a directory
lux /path/to/project
```

## Core Plugins & Features

### Plugin Management
- **[lazy.nvim](https://github.com/folke/lazy.nvim)** by [folke](https://github.com/folke) - Modern plugin manager with lazy loading, lockfile support, and beautiful UI

### File Management & Navigation

#### File Explorer
- **[nvim-tree.lua](https://github.com/nvim-tree/nvim-tree.lua)** by [nvim-tree](https://github.com/nvim-tree)
  - Tree-style file explorer with git integration
  - Custom icons and folder management
  - Configured with 30-character width and left-side placement
  - Git status indicators and file operations

#### File Icons
- **[nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons)** by [nvim-tree](https://github.com/nvim-tree)
  - Provides file type icons throughout the interface
  - Supports hundreds of file types with appropriate icons

#### Fuzzy Finding
- **[fzf](https://github.com/junegunn/fzf)** by [Junegunn Choi](https://github.com/junegunn)
  - Blazing fast fuzzy finder for files
- **[fzf.vim](https://github.com/junegunn/fzf.vim)** by [Junegunn Choi](https://github.com/junegunn)
  - Vim integration for fzf with additional commands

#### Smooth Navigation
- **[nvim-luxmotion](https://github.com/LuxVim/nvim-luxmotion)** by [LuxVim](https://github.com/LuxVim)
  - Smooth cursor and scroll animations with customizable easing
  - Configurable duration (10ms cursor, 380ms scroll) with ease-out easing
  - Enhanced visual feedback for cursor movement and scrolling

### Colorschemes & Themes

LuxVim includes an extensive collection of 30+ carefully curated colorschemes:

#### Custom LuxVim Themes
- **[lux.nvim](https://github.com/LuxVim/lux.nvim)** by [LuxVim](https://github.com/LuxVim) - Custom vesper theme (default)

#### Modern Neovim Themes
- **[voidpulse.nvim](https://github.com/josstei/voidpulse.nvim)** by [josstei](https://github.com/josstei) - Dark theme with purple accents
- **[catppuccin/nvim](https://github.com/catppuccin/nvim)** by [Catppuccin](https://github.com/catppuccin) - Soothing pastel theme
- **[tokyonight.nvim](https://github.com/folke/tokyonight.nvim)** by [folke](https://github.com/folke) - Dark theme inspired by Tokyo's night
- **[kanagawa.nvim](https://github.com/rebelot/kanagawa.nvim)** by [rebelot](https://github.com/rebelot) - Traditional Japanese colors
- **[onedark.nvim](https://github.com/navarasu/onedark.nvim)** by [navarasu](https://github.com/navarasu) - Atom's One Dark theme
- **[nightfox.nvim](https://github.com/EdenEast/nightfox.nvim)** by [EdenEast](https://github.com/EdenEast) - Highly customizable theme
- **[rose-pine](https://github.com/rose-pine/neovim)** by [Rose Pine](https://github.com/rose-pine) - All natural pine theme
- **[monokai.nvim](https://github.com/tanvirtin/monokai.nvim)** by [tanvirtin](https://github.com/tanvirtin) - Monokai theme for Neovim
- **[oxocarbon.nvim](https://github.com/nyoom-engineering/oxocarbon.nvim)** by [nyoom-engineering](https://github.com/nyoom-engineering) - Dark theme with carbon colors
- **[material.nvim](https://github.com/marko-cerovac/material.nvim)** by [marko-cerovac](https://github.com/marko-cerovac) - Material Design theme
- **[edge](https://github.com/sainnhe/edge)** by [sainnhe](https://github.com/sainnhe) - Clean & elegant color scheme

#### Classic Vim Themes
- **[gruvbox](https://github.com/morhetz/gruvbox)** by [Pavel Pertsev](https://github.com/morhetz) - Retro groove colors
- **[dracula/vim](https://github.com/dracula/vim)** by [Dracula Theme](https://github.com/dracula) - Dark theme with vibrant colors
- **[nord-vim](https://github.com/arcticicestudio/nord-vim)** by [Arctic Ice Studio](https://github.com/arcticicestudio) - Arctic, north-bluish theme
- **[vim-colors-solarized](https://github.com/altercation/vim-colors-solarized)** by [Ethan Schoonover](https://github.com/altercation) - Precision colors for machines and people
- **[vim-monokai](https://github.com/crusoexia/vim-monokai)** by [crusoexia](https://github.com/crusoexia) - Refined Monokai color scheme
- **[everforest](https://github.com/sainnhe/everforest)** by [sainnhe](https://github.com/sainnhe) - Green based color scheme
- **[sonokai](https://github.com/sainnhe/sonokai)** by [sainnhe](https://github.com/sainnhe) - High contrast & vivid color scheme
- **[papercolor-theme](https://github.com/NLKNguyen/papercolor-theme)** by [Nikyle Nguyen](https://github.com/NLKNguyen) - Light & dark color scheme
- **[onedark.vim](https://github.com/joshdick/onedark.vim)** by [Josh Dick](https://github.com/joshdick) - Atom's iconic One Dark theme
- **[molokai](https://github.com/tomasr/molokai)** by [Tomas Restrepo](https://github.com/tomasr) - Port of the Monokai theme
- **[oceanic-next](https://github.com/mhartington/oceanic-next)** by [Mike Hartington](https://github.com/mhartington) - Oceanic Next theme

### LuxVim Custom Plugins

#### Dashboard & Startup
- **[nvim-luxdash](https://github.com/LuxVim/nvim-luxdash)** by [LuxVim](https://github.com/LuxVim)
  - Beautiful startup dashboard with ASCII art LuxVim logo
  - Quick access menu with options: newfile, backtrack, fzf, closelux
  - Displays current date and time
  - Customizable logo colors and gradients

#### Terminal Integration
- **[nvim-luxterm](https://github.com/LuxVim/nvim-luxterm)** by [LuxVim](https://github.com/LuxVim)
  - Advanced terminal integration with session management
  - Floating window support (80% width, 60% height, rounded borders)
  - Smart positioning and focus management
  - History persistence (100 commands)
  - Shell integration with auto-cd functionality
  - Quick commands and statusline integration

#### Status & Interface Enhancements
- **[vim-easyline](https://github.com/josstei/vim-easyline)** by [josstei](https://github.com/josstei)
  - Lightweight, customizable statusline
  - Different configurations for various window types (NvimTree, terminal, dashboard)
  - Git branch integration, window numbers, file info
  - Custom separators and position indicators

#### Productivity Tools
- **[vim-easycomment](https://github.com/josstei/vim-easycomment)** by [josstei](https://github.com/josstei)
  - Intelligent commenting system
  - Language-aware comment toggling
  - Works in both normal and visual modes

- **[vim-easyops](https://github.com/josstei/vim-easyops)** by [josstei](https://github.com/josstei)
  - Command palette for quick operations
  - Hierarchical menu system (Main → Git/Window/File/Code/Misc)
  - Maven/Spring Boot development shortcuts
  - Vim-specific operations

- **[vim-easyenv](https://github.com/josstei/vim-easyenv)** by [josstei](https://github.com/josstei)
  - Environment management for project-specific configurations
  - Quick environment setup and switching

#### Navigation & History
- **[vim-backtrack](https://github.com/josstei/vim-backtrack)** by [josstei](https://github.com/josstei)
  - File history tracking and navigation
  - Configurable split behavior (bottom right vertical split)
  - Maximum history count (10 files)
  - Special handling for dashboard splits

#### Window Management
- **[vim-luxpane](https://github.com/LuxVim/vim-luxpane)** by [LuxVim](https://github.com/LuxVim)
  - Intelligent window pane management
  - Protected buffer types: quickfix, help, nofile, terminal
  - Protected file types: NvimTree
  - Smart window operations with context awareness

## Key Mappings

### Leader Key
- **Space** - Leader key (`vim.g.mapleader = ' '`)

### File Operations
| Key | Action | Description |
|-----|--------|-------------|
| `<leader>fs` | `:w<CR>` | Save current file |
| `<leader>fq` | `:q<CR>` | Quit current file |
| `<leader>FQ` | `:q!<CR>` | Force quit without saving |
| `<leader>bye` | `:qa!<CR>` | Quit all files without saving |

### Navigation & Search
| Key | Action | Description |
|-----|--------|-------------|
| `<leader><leader>` | `:Files` | Fuzzy find files using fzf |
| `<leader>t` | `:SearchText<CR>` | Search text in current directory |
| `<leader>e` | `:NvimTreeToggle<CR>` | Toggle file explorer |

### Window Management
| Key | Action | Description |
|-----|--------|-------------|
| `<leader>wv` | `:rightbelow vs new<CR>` | Create vertical split |
| `<leader>wh` | `:rightbelow split new<CR>` | Create horizontal split |
| `<leader>1-6` | `:1-6wincmd w<CR>` | Switch to window 1-6 |

### Terminal (LuxTerm)
| Key | Context | Action | Description |
|-----|---------|--------|-------------|
| `Ctrl+/` | Normal | `:LuxTerm<CR>` | Toggle terminal |
| `Ctrl+/` | Terminal | `<C-\><C-n>:LuxTerm<CR>` | Toggle terminal from terminal mode |
| `Ctrl+_` | Normal/Terminal | Same as `Ctrl+/` | Alternative terminal toggle |
| `Ctrl+`` | Normal/Terminal | Same as `Ctrl+/` | Backtick terminal toggle |
| `Ctrl+n` | Terminal | `<c-\><c-n>` | Enter normal mode in terminal |

### Utilities
| Key | Action | Description |
|-----|--------|-------------|
| `<leader>m` | `:EasyOps<CR>` | Open EasyOps command menu |
| `<leader>cc` | `:EasyComment<CR>` | Toggle comment (normal/visual) |
| `jk` | `<ESC>` | Exit insert mode |

## Configuration Structure

```
LuxVim/
├── init.lua              # Main configuration entry point
├── install.sh           # Installation script
├── install.ps1          # Windows PowerShell installer
├── lua/
│   ├── config/          # Core configuration
│   │   ├── lazy.lua     # Plugin manager setup
│   │   ├── options.lua  # Vim options and settings
│   │   ├── keymaps.lua  # Key mappings
│   │   └── autocmds.lua # Auto commands (FZF, quickfix)
│   ├── plugins/         # Plugin configurations
│   │   ├── colorschemes.lua # All available themes
│   │   ├── core.lua     # Essential plugins (fzf, nvim-tree)
│   │   ├── editor.lua   # Editor enhancements (easy* plugins)
│   │   └── luxvim.lua   # LuxVim-specific plugins
│   └── utils.lua        # Utility functions (search, fzf integration)
└── data/               # Plugin and cache data (auto-created)
    ├── lazy/           # Lazy.nvim plugins
    ├── mason/          # Mason LSP data
    └── nvim/           # Neovim data
```

## Advanced Configuration

### Editor Settings (lua/config/options.lua)
- **Line Numbers**: Relative numbering with absolute current line
- **Search**: Case-insensitive search with smart case
- **Indentation**: 4-space tabs with smart auto-indent
- **Performance**: Swap files disabled, fast timeout (500ms)
- **Clipboard**: System clipboard integration when available
- **Colors**: True color support (24-bit RGB)

### Auto Commands (lua/config/autocmds.lua)
- **FZF Integration**: Hides statusline and UI elements during fuzzy finding
- **Quickfix Enhancement**: Auto-close quickfix window after selection

### Utility Functions (lua/utils.lua)
- **Cross-platform text search**: Uses `grep` on Unix, `findstr` on Windows
- **FZF wrapper functions**: Seamless integration with fuzzy finding
- **Quickfix integration**: Search results displayed in quickfix window

## Customization

### Changing Themes

Edit `lua/plugins/colorschemes.lua` to modify the default theme:

```lua
-- Change the default theme
{
    "LuxVim/lux.nvim",
    priority = 1000,
    config = function()
        require('lux').setup({
            variant = 'vesper'  -- Default variant
        })
        vim.cmd('colorscheme lux')
    end,
},
```

### Adding Custom Key Mappings

Edit `lua/config/keymaps.lua`:

```lua
-- Add your custom mappings
vim.keymap.set('n', '<leader>custom', ':YourCommand<CR>')
vim.keymap.set('n', '<leader>gp', ':Git push<CR>')  -- Git push example
```

### Plugin Configuration

Each plugin configuration is modularized. You can modify settings by editing the respective files:

- `lua/plugins/core.lua` - File management plugins
- `lua/plugins/editor.lua` - Editor enhancement plugins
- `lua/plugins/luxvim.lua` - LuxVim-specific plugins
- `lua/plugins/colorschemes.lua` - Theme configurations

## LuxVim Ecosystem

LuxVim integrates several custom-built plugins designed to work together:

1. **nvim-luxdash** - Startup dashboard with LuxVim branding
2. **nvim-luxterm** - Terminal with floating window and session management  
3. **nvim-luxmotion** - Smooth cursor and scroll animations
4. **vim-luxpane** - Intelligent window pane management
5. **vim-easyline** - Minimal statusline with context awareness
6. **vim-easycomment** - Language-aware commenting system
7. **vim-easyops** - Hierarchical command palette
8. **vim-backtrack** - File navigation history
9. **vim-easyenv** - Environment management

## Troubleshooting

### Plugin Issues
If plugins aren't loading properly:
```bash
lux --headless "+Lazy! sync" +qa
```

### Reset Configuration
To reset LuxVim completely:
```bash
rm -rf ~/.config/LuxVim/data
lux  # Will reinstall all plugins
```

### PATH Issues
If `lux` command not found:
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Theme Issues
If themes aren't loading:
1. Check that the theme dependency exists in `data/lazy/`
2. Verify the colorscheme name matches the plugin documentation
3. Some themes require Neovim 0.8+ for full functionality

## Credits & Acknowledgments

LuxVim builds upon the excellent work of many open-source contributors:

### Core Infrastructure
- [Neovim](https://neovim.io/) - The extensible Vim-based text editor
- [folke](https://github.com/folke) - Creator of lazy.nvim and tokyonight.nvim
- [Junegunn Choi](https://github.com/junegunn) - Creator of fzf

### Theme Authors
- [Catppuccin Organization](https://github.com/catppuccin) - Catppuccin theme
- [rebelot](https://github.com/rebelot) - Kanagawa theme
- [EdenEast](https://github.com/EdenEast) - Nightfox theme collection
- [Rose Pine Organization](https://github.com/rose-pine) - Rose Pine theme
- [Pavel Pertsev](https://github.com/morhetz) - Gruvbox theme
- [Dracula Organization](https://github.com/dracula) - Dracula theme
- All other theme maintainers listed in the colorschemes section

### Plugin Ecosystem
- [nvim-tree](https://github.com/nvim-tree) - File explorer and icons

### LuxVim Team
- [josstei](https://github.com/josstei) - Custom plugins and LuxVim Development
- [zejzejzej3](https://github.com/zejzejzej3) - LuxVim.org Web Development

## Contributing

LuxVim is designed to be a complete, opinionated Neovim distribution. If you'd like to contribute:

1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request

## License

LuxVim is open source and available under the MIT License.

---

** Step into a brighter development experience with LuxVim!** ✨
