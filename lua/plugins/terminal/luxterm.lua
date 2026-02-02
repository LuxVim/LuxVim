return {
  source = "LuxVim/nvim-luxterm",
  debug_name = "nvim-luxterm",
  cmd = { "LuxtermToggle", "LuxtermNew", "LuxtermList", "LuxtermNext", "LuxtermPrev" },
  lazy = {
    keys = {
      { "<C-/>", "<cmd>LuxtermToggle<CR>", desc = "Toggle terminal" },
      { "<C-_>", "<cmd>LuxtermToggle<CR>", desc = "Toggle terminal" },
      { "<C-`>", "<cmd>LuxtermToggle<CR>", desc = "Toggle terminal" },
      { "<C-/>", "<C-\\><C-n><cmd>LuxtermToggle<CR>", mode = "t", desc = "Toggle terminal" },
      { "<C-_>", "<C-\\><C-n><cmd>LuxtermToggle<CR>", mode = "t", desc = "Toggle terminal" },
      { "<C-`>", "<C-\\><C-n><cmd>LuxtermToggle<CR>", mode = "t", desc = "Toggle terminal" },
      { "<C-n>", "<C-\\><C-n>", mode = "t", desc = "Exit terminal mode" },
    },
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
