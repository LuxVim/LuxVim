local M = {}
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

  local debug_mod = require("core.lib.debug")
  local plugin_name = debug_mod.resolve_debug_name(spec)
  for action_name, fn in pairs(spec.actions) do
    if type(fn) == "string" and fn:sub(1, 1) == ":" then
      local cmd = fn:sub(2)
      fn = function()
        vim.cmd(cmd)
      end
    elseif type(fn) ~= "function" then
      notify.warn("Invalid action type for " .. plugin_name .. "." .. action_name .. ": expected function or :command string")
      fn = nil
    end
    if fn then
      M.register(plugin_name, action_name, fn)
    end
  end
end

local function split_action(action_string)
  for ns, _ in pairs(M._registry) do
    if action_string:sub(1, #ns + 1) == ns .. "." then
      return ns, action_string:sub(#ns + 2)
    end
  end

  local namespace, method = action_string:match("^([^.]+)%.(.+)$")
  return namespace, method
end

function M.resolve(action_string)
  if M._cache[action_string] then
    return M._cache[action_string]
  end

  local namespace, method = split_action(action_string)
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

local function register_cmd_actions()
  local cmd_actions = {
    save = "write",
    quit = "quit",
    force_quit = "quit!",
    quit_all = "quitall!",
    save_quit = "wq",
    vsplit = "rightbelow vs new",
    hsplit = "rightbelow split new",
  }

  for name, cmd in pairs(cmd_actions) do
    M.register("core", name, function()
      vim.cmd(cmd)
    end)
  end
end

local function register_window_actions()
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
end

local function register_search_actions()
  M.register("core", "search_text", function()
    local search_text = vim.fn.input("Search For Text (Current Directory): ")
    if search_text == "" then
      notify.info("Cancelled.")
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
      notify.info("No matches found.")
      return
    end

    vim.fn.setqflist({}, "r", { lines = results, title = "Search Results" })
    vim.cmd("copen")
  end)
end

local function register_filetype_actions()
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
end

local function register_diagnostic_actions()
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

function M.register_core_actions()
  register_cmd_actions()
  register_window_actions()
  register_search_actions()
  register_filetype_actions()
  register_diagnostic_actions()
end

return M
