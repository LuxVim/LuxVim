local M = {}

local _schemas = {}

local function register_defaults()
  _schemas.build_spec = {
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

  _schemas.plugin_spec = {
    source = { type = "string", required = true, desc = "GitHub repo (author/name) or 'virtual'" },
    debug_name = { type = "string", desc = "Override debug folder name" },
    opts = { type = "table", default = {}, desc = "Options passed to setup()" },
    config = { type = "function", desc = "Custom config function" },
    build = { type = { "string", "table" }, desc = "Build configuration" },
    actions = { type = "table", desc = "Action overrides for keymap resolution" },
    globals = { type = "table", desc = "vim.g variables set before plugin loads" },
    dependencies = { type = "list", of = "string", desc = "References to other plugin specs" },
    cond = { type = { "string", "function" }, desc = "Load condition" },
    event = { type = { "string", "list" }, desc = "Lazy-load on event" },
    cmd = { type = { "string", "list" }, desc = "Lazy-load on command" },
    ft = { type = { "string", "list" }, desc = "Lazy-load on filetype" },
    keys = { type = { "string", "list", "table" }, desc = "Lazy-load on keymap" },
    enabled = { type = "boolean", default = true, desc = "Enable/disable plugin" },
    lazy = { type = "table", passthrough = true, desc = "Lazy.nvim native fields" },
    extends = { type = "string", desc = "Name of framework spec to extend (deep merge)" },
    replaces = { type = "string", desc = "Name of framework spec to replace entirely" },
  }

  _schemas.keymap_entry = {
    action = { type = "string", required = true, desc = "Action to invoke" },
    desc = { type = "string", desc = "Description for which-key" },
    mode = { type = { "string", "list" }, default = "n", desc = "Vim mode(s)" },
  }

  _schemas.autocmd_entry = {
    action = { type = "string", desc = "Action to invoke (mutually exclusive with callback)" },
    callback = { type = "function", desc = "Direct callback (mutually exclusive with action)" },
    pattern = { type = { "string", "list" }, default = "*", desc = "File pattern" },
    once = { type = "boolean", default = false, desc = "Run only once" },
  }
end

function M.get(name)
  return _schemas[name]
end

function M.extend(name, fields)
  local schema = _schemas[name]
  if not schema then
    _schemas[name] = fields
    return
  end
  for field, rules in pairs(fields) do
    schema[field] = rules
  end
end

function M.replace(name, fields)
  _schemas[name] = fields
end

register_defaults()

setmetatable(M, {
  __index = function(_, key)
    return _schemas[key]
  end,
})

return M
