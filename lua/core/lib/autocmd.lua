local actions = require("core.lib.actions")

local M = {}

local augroup = vim.api.nvim_create_augroup("LuxVimCore", { clear = true })

function M.register_autocmds(registry)
  for event, config in pairs(registry) do
    if event == "extends" or event == "replaces" then
      goto continue
    end

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

    ::continue::
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
  local data = require("core.lib.data")
  local paths = require("core.lib.paths")

  local ok_autocmds, autocmds = pcall(require, "core.registry.autocmds")
  if ok_autocmds then
    local user_path = paths.join(data.user_config_path(), "registry", "autocmds.lua")
    if vim.uv.fs_stat(user_path) then
      local uok, user_autocmds = pcall(dofile, user_path)
      if uok and type(user_autocmds) == "table" then
        if user_autocmds.replaces then
          user_autocmds.replaces = nil
          autocmds = user_autocmds
        elseif user_autocmds.extends then
          user_autocmds.extends = nil
          autocmds = vim.tbl_deep_extend("force", autocmds, user_autocmds)
        end
      end
    end
    M.register_autocmds(autocmds)
  end

  local ok_filetypes, filetypes = pcall(require, "core.registry.filetypes")
  if ok_filetypes then
    local user_ft_path = paths.join(data.user_config_path(), "registry", "filetypes.lua")
    if vim.uv.fs_stat(user_ft_path) then
      local uok, user_ft = pcall(dofile, user_ft_path)
      if uok and type(user_ft) == "table" then
        if user_ft.replaces then
          user_ft.replaces = nil
          filetypes = user_ft
        elseif user_ft.extends then
          user_ft.extends = nil
          filetypes = vim.tbl_deep_extend("force", filetypes, user_ft)
        end
      end
    end
    M.register_filetypes(filetypes)
  end
end

return M
