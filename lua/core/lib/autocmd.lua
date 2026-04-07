local actions = require("core.lib.actions")
local registry = require("core.lib.registry")

local M = {}

local augroup = vim.api.nvim_create_augroup("LuxVimCore", { clear = true })

local function invalid_autocmd_error(event, message)
  return string.format("Invalid autocmd '%s': %s", event, message)
end

local function unresolved_action_error(event, action)
  return string.format(
    "Autocmd '%s' references unsupported action '%s'. Actions must be registered explicitly; module-backed require() fallback is no longer supported.",
    event,
    action
  )
end

local function validate_autocmd_entries(entries)
  for event, config in pairs(entries) do
    if type(config) ~= "table" then
      return nil, invalid_autocmd_error(event, "expected a table entry")
    end

    if config.action ~= nil then
      if type(config.action) ~= "string" or config.action == "" then
        return nil, invalid_autocmd_error(event, "action must be a non-empty string")
      end

      local _, err = actions.resolve(config.action)
      if err then
        return nil, unresolved_action_error(event, config.action)
      end
    end
  end

  return true
end

local function register_autocmds(entries)
  for event, config in pairs(entries) do
    local pattern = config.pattern or "*"
    local once = config.once or false

    local callback
    if config.callback then
      callback = config.callback
    elseif config.action then
      callback = function()
        actions.invoke(config.action)
      end
    end

    if callback then
      local ok, err = pcall(vim.api.nvim_create_autocmd, event, {
        group = augroup,
        pattern = pattern,
        once = once,
        callback = callback,
      })
      if not ok then
        return nil, string.format("Failed to register autocmd '%s': %s", event, tostring(err))
      end
    end
  end

  return true
end

local function register_filetypes(entries)
  for ft, settings in pairs(entries) do
    local ok, err = pcall(vim.api.nvim_create_autocmd, "FileType", {
      group = augroup,
      pattern = ft,
      callback = function()
        for option, value in pairs(settings) do
          vim.opt_local[option] = value
        end
      end,
    })
    if not ok then
      return nil, string.format("Failed to register filetype autocmd '%s': %s", ft, tostring(err))
    end
  end

  return true
end

local autocmd_registry = registry.new({
  name = "autocmds",
  framework_module = "core.registry.autocmds",
  user_file = "registry/autocmds.lua",
  validate_entries = validate_autocmd_entries,
  register = register_autocmds,
})

local filetype_registry = registry.new({
  name = "filetypes",
  framework_module = "core.registry.filetypes",
  user_file = "registry/filetypes.lua",
  register = register_filetypes,
})

function M.setup()
  local ok, err = autocmd_registry:setup()
  if not ok then
    return nil, err
  end

  return filetype_registry:setup()
end

return M
