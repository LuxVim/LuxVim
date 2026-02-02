local actions = require("core.lib.actions")

local M = {}

local augroup = vim.api.nvim_create_augroup("LuxVimCore", { clear = true })

function M.register_autocmds(registry)
  for event, config in pairs(registry) do
    local pattern = config.pattern or "*"
    local once = config.once or false

    vim.api.nvim_create_autocmd(event, {
      group = augroup,
      pattern = pattern,
      once = once,
      callback = function()
        actions.invoke(config.action)
      end,
    })
  end
end

function M.register_filetypes(filetypes)
  for ft, settings in pairs(filetypes) do
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

function M.setup()
  local ok_autocmds, autocmds = pcall(require, "core.registry.autocmds")
  if ok_autocmds then
    M.register_autocmds(autocmds)
  end

  local ok_filetypes, filetypes = pcall(require, "core.registry.filetypes")
  if ok_filetypes then
    M.register_filetypes(filetypes)
  end
end

return M
