local actions = require("core.lib.actions")
local registry = require("core.lib.registry")

local M = {}

local augroup = vim.api.nvim_create_augroup("LuxVimCore", { clear = true })

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
      vim.api.nvim_create_autocmd(event, {
        group = augroup,
        pattern = pattern,
        once = once,
        callback = callback,
      })
    end
  end
end

local function register_filetypes(entries)
  for ft, settings in pairs(entries) do
    vim.api.nvim_create_autocmd("FileType", {
      group = augroup,
      pattern = ft,
      callback = function()
        for option, value in pairs(settings) do
          vim.opt_local[option] = value
        end
      end,
    })
  end
end

local autocmd_registry = registry.new({
  name = "autocmds",
  framework_module = "core.registry.autocmds",
  user_file = "registry/autocmds.lua",
  register = register_autocmds,
})

local filetype_registry = registry.new({
  name = "filetypes",
  framework_module = "core.registry.filetypes",
  user_file = "registry/filetypes.lua",
  register = register_filetypes,
})

function M.setup()
  autocmd_registry:setup()
  filetype_registry:setup()
end

return M
