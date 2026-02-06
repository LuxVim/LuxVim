local navigation = {
  ["<leader>wv"] = { action = "core.vsplit", desc = "Vertical split" },
  ["<leader>wh"] = { action = "core.hsplit", desc = "Horizontal split" },
}

for i = 1, 6 do
  navigation["<leader>" .. i] = { action = "core.win" .. i, desc = "Go to window " .. i }
end

return {
  editor = {
    ["<leader>fs"] = { action = "core.save", desc = "Save file" },
    ["<leader>fq"] = { action = "core.quit", desc = "Quit" },
    ["<leader>FQ"] = { action = "core.force_quit", desc = "Force quit" },
    ["<leader>bye"] = { action = "core.quit_all", desc = "Quit all" },
    ["<leader>m"] = { action = "vim-easyops.open", desc = "Command palette" },
    ["<leader><leader>"] = { action = "fzf.vim.files", desc = "Find files" },
    ["<leader>st"] = { action = "fzf.vim.search_text", desc = "Search text" },
  },

  navigation = navigation,

  ui = {
    ["<leader>e"] = { action = "nvim-tree.toggle", desc = "File explorer" },
  },

  terminal = {
    { lhs = "<C-/>", action = "nvim-luxterm.toggle", desc = "Toggle terminal" },
    { lhs = "<C-_>", action = "nvim-luxterm.toggle", desc = "Toggle terminal" },
    { lhs = "<C-`>", action = "nvim-luxterm.toggle", desc = "Toggle terminal" },
    { lhs = "<C-/>", action = "nvim-luxterm.toggle_from_terminal", desc = "Toggle terminal", mode = "t" },
    { lhs = "<C-_>", action = "nvim-luxterm.toggle_from_terminal", desc = "Toggle terminal", mode = "t" },
    { lhs = "<C-`>", action = "nvim-luxterm.toggle_from_terminal", desc = "Toggle terminal", mode = "t" },
    { lhs = "<C-n>", action = "nvim-luxterm.exit_terminal_mode", desc = "Exit terminal mode", mode = "t" },
  },
}
