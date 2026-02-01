local M = {}

M.build_spec = {
  cmd = { type = "string", required = true, desc = "Build command" },
  platforms = {
    type = "table",
    keys = { "linux", "mac", "windows" },
    values = "string",
    desc = "Platform-specific build commands",
  },
  requires = { type = "list", of = "string", desc = "Required executables" },
  cond = { type = "string", desc = "Condition from registry" },
  on_fail = { type = "enum", values = { "warn", "error", "ignore" }, default = "warn" },
  outputs = { type = "list", of = "string", desc = "Expected output files" },
}

M.plugin_spec = {
  source = { type = "string", required = true, desc = "GitHub repo (author/name)" },
  debug_name = { type = "string", desc = "Override debug folder name" },
  opts = { type = "table", default = {}, desc = "Options passed to setup()" },
  config = { type = "function", desc = "Custom config function" },
  build = { type = { "string", "table" }, desc = "Build configuration" },
  actions = { type = "table", desc = "Action overrides for keymap resolution" },
  dependencies = { type = "list", of = "string", desc = "References to other plugin specs" },
  cond = { type = { "string", "function" }, desc = "Load condition" },
  event = { type = { "string", "list" }, desc = "Lazy-load on event" },
  cmd = { type = { "string", "list" }, desc = "Lazy-load on command" },
  ft = { type = { "string", "list" }, desc = "Lazy-load on filetype" },
  enabled = { type = "boolean", default = true, desc = "Enable/disable plugin" },
  lazy = { type = "table", passthrough = true, desc = "Lazy.nvim native fields" },
}

M.keymap_entry = {
  action = { type = "string", required = true, desc = "Action to invoke" },
  desc = { type = "string", desc = "Description for which-key" },
  mode = { type = { "string", "list" }, default = "n", desc = "Vim mode(s)" },
}

M.autocmd_entry = {
  action = { type = "string", required = true, desc = "Action to invoke" },
  pattern = { type = { "string", "list" }, default = "*", desc = "File pattern" },
  once = { type = "boolean", default = false, desc = "Run only once" },
}

return M
