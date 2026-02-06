return {
  source = "LuxVim/nvim-luxterm",
  cmd = { "LuxtermToggle", "LuxtermNew", "LuxtermList", "LuxtermNext", "LuxtermPrev" },
  actions = {
    toggle = function()
      vim.cmd("LuxtermToggle")
    end,
    toggle_from_terminal = function()
      local esc = vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, true, true)
      vim.api.nvim_feedkeys(esc, "n", false)
      vim.schedule(function()
        vim.cmd("LuxtermToggle")
      end)
    end,
    exit_terminal_mode = function()
      local esc = vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, true, true)
      vim.api.nvim_feedkeys(esc, "n", false)
    end,
  },
  opts = {
    manager_width = 0.8,
    manager_height = 0.8,
    preview_enabled = true,
    focus_on_create = false,
    auto_hide = true,
    keymaps = {
      toggle_manager = "<C-/>",
      next_session = "<C-k>",
      prev_session = "<C-j>",
      global_session_nav = false,
    },
  },
}
