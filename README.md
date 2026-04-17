  ![InDevelopment](https://img.shields.io/badge/status-in_development-orange) ![License](https://img.shields.io/badge/license-Apache_2.0-blue)
<p align="center">
  <img src="https://github.com/user-attachments/assets/546ee0e5-30fd-4e37-b219-e390be8b1c6e" alt="LuxVim Logo" style="width: 50%; height: auto;" />
</p>

LuxVim is a self-contained Neovim distribution with a focused plugin set, a pipeline-based core, and a complete user-config override layer. It installs in one command, runs in its own data directory, and stays out of the way of any existing Neovim setup.

## Quick start

```bash
git clone https://github.com/LuxVim/LuxVim.git
cd LuxVim && ./install.sh
lux
```

The installer creates a `lux` launcher in `~/.local/bin/`, bootstraps `lazy.nvim`, and syncs every plugin. If `~/.local/bin` isn't on your `PATH`, add:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Features

- **Isolated** — runs with `NVIM_APPNAME=LuxVim` and `LUXVIM_ROOT` set to the repo's `data/` directory, so LuxVim never touches your existing Neovim config or data.
- **Declarative plugin specs** — every plugin is a small Lua table under `lua/plugins/<category>/`. A 5-stage pipeline discovers, loads, validates, merges, and transforms them into `lazy.nvim` specs.
- **User config layer** — drop files under `~/.config/luxvim/` (or set `LUXVIM_CONFIG`) to add plugins, override keymaps and autocmds, or extend the schema. Use `extends = "name"` to deep-merge, `replaces = "name"` to swap.
- **Action-based keymaps** — keymaps resolve through a central action registry (`namespace.method`), so the same action can be bound from multiple keys or reused from user config.
- **Debug plugin system** — symlink or clone a plugin under `debug/<name>/` and LuxVim auto-prefers that local copy over the remote source.
- **First-class diagnostics** — `:LuxVimErrors`, `:LuxVimValidate`, `:LuxDevStatus` for inspecting pipeline output, validating config without applying it, and seeing which debug plugins are active.
- **Factory-based core** — `schema`, `actions`, and `pipeline` are explicit classes (`M.new()` + lazy `M.default()`) so tests can build isolated instances without touching production state.
- **Test harness + CI** — 105 plenary-busted cases across 11 suites, runnable via `./scripts/test.sh`. GitHub Actions matrix runs on Neovim `v0.10.0`, `stable`, and `nightly`.

## Requirements

- Neovim 0.10+
- Git
- macOS, Linux, or WSL
- `bash` for the installer and scripts

## Usage

```bash
lux                 # open LuxVim (no file)
lux path/to/file    # open a file
lux path/to/dir     # open a directory
lux --headless "+Lazy! sync" +qa   # headless plugin sync
```

### Commands

| Command | What it does |
|---|---|
| `:LuxVimErrors` | Show errors and warnings from the current session's pipeline run. |
| `:LuxVimValidate` | Run the pipeline through the validate stage only (no bootstrap, no keymaps) and report issues. Safe to run anywhere, any time. |
| `:LuxDevStatus` | List active debug plugins (from `debug/`). |
| `:LuxVimGenerateTypes` | Regenerate `lua/types/plugin.lua` from the schema. |
| `:Themes` | Open the theme picker to browse, preview, install, and apply colorschemes. |
| `:LuxLsp` | Open the LuxLSP manager (if the debug plugin is installed). |

### Key bindings

Leader is `<Space>`.

| Keys | Action |
|---|---|
| `<leader>fs` | Save file (`:write`) |
| `<leader>fq` | Quit (`:quit`) |
| `<leader>FQ` | Force quit (`:quit!`) |
| `<leader>bye` | Quit all, no save (`:quitall!`) |
| `<leader><leader>` | Fuzzy find files (`:Files`) |
| `<leader>st` | Search text across project (`:Rg`) |
| `<leader>e` | Toggle file explorer (nvim-tree) |
| `<leader>1` … `<leader>6` | Jump to window N |
| `<leader>wv` | Vertical split |
| `<leader>wh` | Horizontal split |
| `<C-/>`, `<C-_>`, `` <C-`> `` | Toggle terminal (works in terminal mode too) |
| `<C-n>` (terminal mode) | Exit terminal mode |
| `jk` (insert mode) | Leave insert mode |

Every action is declared in `lua/core/registry/keymaps.lua` and resolved through the action registry; override any of them from your user config.

## Installation detail

`install.sh`:

1. Checks for `nvim` and `git`.
2. Writes `~/.local/bin/lux` — a launcher that invokes Neovim with `LUXVIM_ROOT="$(repo dir)"`, `NVIM_APPNAME=LuxVim`, `XDG_DATA_HOME="$(repo dir)/data"`.
3. Creates `data/lazy/`, `data/luxlsp/`, `data/site/`.
4. Clones `lazy.nvim` into `data/lazy/lazy.nvim`.
5. Runs `lux --headless "+Lazy! sync" +qa` to install all plugin specs.

Everything lives inside the repo's `data/` directory; deleting it resets LuxVim to a clean state.

## Architecture overview

```
init.lua
  └── core/init.lua
        ├── pipeline (5 stages: discover → load → merge → validate → transform)
        ├── bootstrap (lazy.nvim)
        ├── actions (namespace.method registry)
        ├── keymap + autocmd (from registry/)
        └── user commands (:LuxVimErrors, :LuxVimValidate, ...)
```

- **`lua/core/lib/`** — factory modules (`pipeline`, `schema`, `actions`, `registry`) and utilities (`paths`, `data`, `debug`, `notify`, `platform`, `bootstrap`, `keymap`, `autocmd`, `typegen`, `validate`).
- **`lua/core/registry/`** — central definitions for keymaps, autocmds, conditions, filetypes.
- **`lua/plugins/<category>/`** — plugin specs grouped by purpose: `editor/`, `lib/`, `lsp/`, `navigation/`, `terminal/`, `ui/`. Each category's `_defaults.lua` applies to every spec in that directory.
- **`data/`** — plugin installs, LSP servers, lockfiles, dynamic specs written by the theme picker.
- **`debug/`** — local plugin development directory. Any subdirectory with a `lua/` or `plugin/` child auto-overrides the remote source.

Every plugin spec follows the same shape:

```lua
return {
  source = "author/repo",                -- required
  debug_name = "override-folder-name",   -- optional
  opts = { ... },                        -- passed to setup()
  config = function(_, opts) ... end,    -- optional
  dependencies = { "plenary.nvim" },     -- by source or debug name
  event = { "BufReadPost" },             -- lazy-load trigger
  cmd = { "Command" },                   -- lazy-load trigger
  ft = "lua",                            -- lazy-load trigger
  cond = "has_git",                      -- from registry/conditions.lua
  actions = { toggle = function() ... end, open = ":Command" },
  globals = { some_flag = 1 },           -- sets vim.g before load
}
```

See `lua/core/lib/schema.lua` for the full contract.

## Customization

LuxVim reads user files from `$LUXVIM_CONFIG` (or `$XDG_CONFIG_HOME/luxvim`). The user layer can:

### Override keymaps

```lua
-- ~/.config/luxvim/registry/keymaps.lua
return {
  extends = true,
  editor = {
    { lhs = "<leader>w", action = "core.save", desc = "Save file" },
  },
}
```

Use `extends = true` to deep-merge into the framework registry, or `replaces = true` to swap it entirely.

### Add or override plugins

```lua
-- ~/.config/luxvim/plugins/editor/my-plugin.lua
return {
  source = "author/my-plugin",
  event = "VeryLazy",
}
```

Target a framework plugin:

```lua
-- ~/.config/luxvim/plugins/ui/nvim-tree.lua
return {
  extends = "nvim-tree",
  opts = { view = { width = 40 } },
}
```

### Pipeline hooks and schema extensions

```lua
-- ~/.config/luxvim/init.lua (runs before the pipeline executes)
local pipeline = require("core.lib.pipeline")
local schema = require("core.lib.schema")

schema.extend("plugin_spec", {
  my_custom_field = { type = "string", desc = "…" },
})

pipeline.on("post_load", function(ctx)
  -- inspect or mutate ctx.specs here
  return ctx
end)
```

## Included plugins

**Editor**
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) — syntax
- [fzf](https://github.com/junegunn/fzf) + [fzf.vim](https://github.com/junegunn/fzf.vim) — fuzzy finding
- [quill.nvim](https://github.com/josstei/quill.nvim) — text editing helpers

**Navigation & UI**
- [nvim-tree.lua](https://github.com/nvim-tree/nvim-tree.lua) — file explorer
- [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) — icons
- [nvim-luxdash](https://github.com/LuxVim/nvim-luxdash) — startup dashboard
- [nvim-luxline](https://github.com/LuxVim/nvim-luxline) — statusline
- [nvim-luxterm](https://github.com/LuxVim/nvim-luxterm) — terminal manager
- [vim-luxpane](https://github.com/LuxVim/vim-luxpane) — window management
- [whisk.nvim](https://github.com/josstei/whisk.nvim) — UI utilities

**Colorscheme**
- Default: [fathom.nvim](https://github.com/josstei/fathom.nvim)
- Additional themes browsable and installable through `:Themes`.

**LSP**
- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) — LSP client setup
- Optional integration with [nvim-luxlsp](https://github.com/josstei/nvim-luxlsp) (a LuxVim-focused LSP manager) when present under `debug/nvim-luxlsp`.

## Development

```bash
./scripts/test.sh        # run the plenary-busted suite (105 cases)
./scripts/validate.sh    # headless config validator; exits 1 on critical errors
lux                      # interactive sanity check
```

See `CLAUDE.md` for the full architectural contract (spec fields, registry lifecycle, debug plugin system, test harness layout).

## Troubleshooting

| Symptom | Fix |
|---|---|
| `lux` not found | Add `~/.local/bin` to `PATH`. |
| Plugin fails to load | `:LuxVimErrors` — shows every error and warning from the session's pipeline run. |
| Config change doesn't apply | `:LuxVimValidate` — runs the pipeline through validate only, shows which file errors. |
| Debug plugin not picked up | `:LuxDevStatus`. Ensure `debug/<name>/` has a `lua/` or `plugin/` subdirectory. |
| Need a full reset | Delete `data/` and run `./install.sh` again. |
| Tests fail in CI | Run `./scripts/test.sh` locally; CI uses the same command. Nightly Neovim may regress — `fail-fast: false` is set so stable is the gate. |

## License

Apache License 2.0. See [LICENSE](LICENSE).

## Credits

- [Neovim](https://neovim.io) — the editor.
- [folke/lazy.nvim](https://github.com/folke/lazy.nvim) — plugin manager.
- [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim) — test harness + shared utilities.
- [junegunn/fzf](https://github.com/junegunn/fzf) and [junegunn/fzf.vim](https://github.com/junegunn/fzf.vim) — fuzzy finding.
- [nvim-tree](https://github.com/nvim-tree) — file explorer + icons.
- [nvim-treesitter](https://github.com/nvim-treesitter) — syntax.
- Theme catalog authors: catppuccin, folke (tokyonight), rebelot (kanagawa), EdenEast (nightfox), rose-pine, sainnhe (everforest, sonokai, edge), nyoom-engineering (oxocarbon), marko-cerovac (material), navarasu (onedark), and more.
- [josstei](https://github.com/josstei) — core framework and LuxVim plugin ecosystem.
