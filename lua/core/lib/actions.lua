local M = {}
local paths = require("core.lib.paths")
local notify = require("core.lib.notify")
local platform = require("core.lib.platform")

M._registry = {}
M._cache = {}

function M.register(namespace, name, fn)
  M._registry[namespace] = M._registry[namespace] or {}
  M._registry[namespace][name] = fn
  M._cache[namespace .. "." .. name] = fn
end

function M.register_from_spec(spec)
  if not spec.actions then
    return
  end

  local plugin_name = spec.debug_name or paths.basename(spec.source)
  for action_name, fn in pairs(spec.actions) do
    M.register(plugin_name, action_name, fn)
  end
end

function M.resolve(action_string)
  if M._cache[action_string] then
    return M._cache[action_string]
  end

  local namespace, method = action_string:match("^([^.]+)%.(.+)$")
  if not namespace or not method then
    return nil, "invalid action format: " .. action_string
  end

  if M._registry[namespace] and M._registry[namespace][method] then
    local fn = M._registry[namespace][method]
    M._cache[action_string] = fn
    return fn
  end

  local ok, module = pcall(require, namespace)
  if ok and type(module) == "table" and type(module[method]) == "function" then
    M._cache[action_string] = function()
      module[method]()
    end
    return M._cache[action_string]
  end

  return nil, "could not resolve action: " .. action_string
end

function M.invoke(action_string)
  local fn, err = M.resolve(action_string)
  if not fn then
    notify.warn(err)
    return false
  end

  local ok, result = pcall(fn)
  if not ok then
    notify.error("Action error: " .. tostring(result))
    return false
  end
  return true
end

function M.register_core_actions()
  M.register("core", "save", function()
    vim.cmd("write")
  end)

  M.register("core", "quit", function()
    vim.cmd("quit")
  end)

  M.register("core", "force_quit", function()
    vim.cmd("quit!")
  end)

  M.register("core", "quit_all", function()
    vim.cmd("quitall!")
  end)

  M.register("core", "save_quit", function()
    vim.cmd("wq")
  end)

  M.register("core", "vsplit", function()
    vim.cmd("rightbelow vs new")
  end)

  M.register("core", "hsplit", function()
    vim.cmd("rightbelow split new")
  end)

  local function goto_win(n)
    if n <= vim.fn.winnr("$") then
      vim.cmd(n .. "wincmd w")
    end
  end

  for i = 1, 6 do
    M.register("core", "win" .. i, function()
      goto_win(i)
    end)
  end

  M.register("core", "search_text", function()
    local search_text = vim.fn.input("Search For Text (Current Directory): ")
    if search_text == "" then
      print("Cancelled.")
      return
    end

    local cmd
    if platform.is_windows then
      cmd = "findstr /S /N /I /P /C:" .. vim.fn.shellescape(search_text) .. " *"
    else
      cmd = "grep -rniI --exclude-dir=.git " .. vim.fn.shellescape(search_text) .. " ."
    end

    local results = vim.fn.systemlist(cmd)
    if #results == 0 then
      print("  - No Matches Found - ")
      return
    end

    vim.fn.setqflist({}, "r", { lines = results, title = "Search Results" })
    vim.cmd("copen")
  end)

  M.register("core", "filetype_setup", function()
    local ft = vim.bo.filetype
    if ft == "fzf" then
      vim.opt_local.laststatus = 0
      vim.opt_local.showmode = false
      vim.opt_local.ruler = false
      return
    end

    if ft == "qf" then
      vim.keymap.set("n", "<CR>", "<CR>:cclose<CR>", { buffer = true })
    end
  end)

  M.register("core", "fzf_bufleave", function()
    if vim.bo.filetype == "fzf" then
      vim.opt.laststatus = 3
      vim.opt.showmode = true
      vim.opt.ruler = true
    end
  end)

  M.register("core", "ensure_diagnostic_virtual_text", function()
    vim.defer_fn(function()
      local current_config = vim.diagnostic.config()
      if current_config.virtual_text == false then
        local bullet = vim.fn.nr2char(0x25CF)
        vim.diagnostic.config({
          virtual_text = {
            prefix = bullet,
            spacing = 4,
          },
          signs = current_config.signs,
          underline = current_config.underline,
          update_in_insert = current_config.update_in_insert,
          severity_sort = current_config.severity_sort,
          float = current_config.float,
        })
      end
    end, 100)
  end)
end

return M
