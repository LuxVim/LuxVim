local platform = require("core.lib.platform")
local notify = require("core.lib.notify")

local cmd = {
  save = ":write",
  quit = ":quit",
  force_quit = ":quit!",
  quit_all = ":quitall!",
  save_quit = ":wq",
  vsplit = ":rightbelow vs new",
  hsplit = ":rightbelow split new",
}

local function goto_win(n)
  if n <= vim.fn.winnr("$") then
    vim.cmd(n .. "wincmd w")
  end
end

local window = {}
for i = 1, 6 do
  window["win" .. i] = function()
    goto_win(i)
  end
end

local search = {
  search_text = function()
    local search_text = vim.fn.input("Search For Text (Current Directory): ")
    if search_text == "" then
      notify.info("Cancelled.")
      return
    end

    local cmd_str
    if platform.is_windows then
      cmd_str = "findstr /S /N /I /P /C:" .. vim.fn.shellescape(search_text) .. " *"
    else
      cmd_str = "grep -rniI --exclude-dir=.git " .. vim.fn.shellescape(search_text) .. " ."
    end

    local results = vim.fn.systemlist(cmd_str)
    if #results == 0 then
      notify.info("No matches found.")
      return
    end

    vim.fn.setqflist({}, "r", { lines = results, title = "Search Results" })
    vim.cmd("copen")
  end,
}

local filetype = {
  filetype_setup = function()
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
  end,

  fzf_bufleave = function()
    if vim.bo.filetype == "fzf" then
      vim.opt.laststatus = 3
      vim.opt.showmode = true
      vim.opt.ruler = true
    end
  end,
}

local diagnostic = {
  ensure_diagnostic_virtual_text = function()
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
  end,
}

return {
  cmd = cmd,
  window = window,
  search = search,
  filetype = filetype,
  diagnostic = diagnostic,
}
