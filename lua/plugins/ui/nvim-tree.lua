return {
  source = "nvim-tree/nvim-tree.lua",
  debug_name = "nvim-tree",
  dependencies = { "nvim-web-devicons" },
  cmd = { "NvimTreeToggle", "NvimTreeFocus", "NvimTreeOpen" },
  actions = {
    toggle = function()
      require("nvim-tree.api").tree.toggle()
    end,
    focus = function()
      require("nvim-tree.api").tree.focus()
    end,
  },
  opts = {
    disable_netrw = true,
    hijack_netrw = true,
    sync_root_with_cwd = true,
    respect_buf_cwd = true,
    update_focused_file = {
      enable = true,
      update_root = false,
      ignore_list = {},
    },
    view = {
      width = 30,
      side = "left",
      preserve_window_proportions = false,
      number = false,
      relativenumber = false,
      signcolumn = "yes",
    },
    renderer = {
      group_empty = true,
      full_name = false,
      highlight_git = false,
      highlight_opened_files = "icon",
      highlight_modified = "none",
      highlight_bookmarks = "icon",
      root_folder_label = ":~:s?$?/..?",
      indent_width = 2,
      indent_markers = {
        enable = true,
        inline_arrows = true,
        icons = {
          corner = "└",
          edge = "│",
          item = "│",
          bottom = "─",
          none = " ",
        },
      },
      icons = {
        show = {
          file = true,
          folder = true,
          folder_arrow = true,
          git = false,
          modified = false,
          bookmarks = true,
        },
        glyphs = {
          default = "",
          symlink = "",
          bookmark = "󰆤",
          folder = {
            arrow_closed = "",
            arrow_open = "",
            default = "",
            open = "",
            empty = "",
            empty_open = "",
            symlink = "",
            symlink_open = "",
          },
        },
      },
    },
    filters = {
      dotfiles = false,
      git_ignored = true,
      custom = { "^.git$", "^node_modules$", "^.cache$" },
      exclude = {},
    },
    git = {
      enable = true,
      show_on_dirs = false,
      show_on_open_dirs = false,
      timeout = 400,
    },
    filesystem_watchers = {
      enable = true,
      debounce_delay = 50,
      ignore_dirs = {
        "node_modules",
        ".git",
        ".cache",
        "target",
        "build",
        "dist",
      },
    },
    actions = {
      use_system_clipboard = true,
      change_dir = {
        enable = true,
        global = false,
      },
      open_file = {
        quit_on_open = false,
        resize_window = true,
        window_picker = {
          enable = true,
          picker = "default",
          chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
          exclude = {
            filetype = { "notify", "packer", "qf", "diff", "fugitive", "fugitiveblame" },
            buftype = { "nofile", "terminal", "help" },
          },
        },
      },
      expand_all = {
        max_folder_discovery = 300,
        exclude = { ".git", "target", "build", "node_modules" },
      },
      remove_file = {
        close_window = true,
      },
    },
    diagnostics = {
      enable = false,
    },
    modified = {
      enable = false,
    },
    live_filter = {
      prefix = "[FILTER]: ",
      always_show_folders = false,
    },
    trash = {
      cmd = "trash",
      require_confirm = true,
    },
    tab = {
      sync = {
        open = false,
        close = false,
      },
    },
    ui = {
      confirm = {
        remove = true,
        trash = true,
      },
    },
    log = {
      enable = false,
      truncate = true,
      types = {
        diagnostics = false,
        git = false,
        profile = false,
        watcher = false,
      },
    },
  },
}
