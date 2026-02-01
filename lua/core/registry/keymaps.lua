return {
  editor = {
    ["<leader>fs"] = { action = "core.save", desc = "Save file" },
    ["<leader>fq"] = { action = "core.quit", desc = "Quit" },
    ["<leader>FQ"] = { action = "core.force_quit", desc = "Force quit" },
    ["<leader>bye"] = { action = "core.quit_all", desc = "Quit all" },
  },

  navigation = {
    ["<leader>wv"] = { action = "core.vsplit", desc = "Vertical split" },
    ["<leader>wh"] = { action = "core.hsplit", desc = "Horizontal split" },
    ["<leader>1"] = { action = "core.win1", desc = "Go to window 1" },
    ["<leader>2"] = { action = "core.win2", desc = "Go to window 2" },
    ["<leader>3"] = { action = "core.win3", desc = "Go to window 3" },
    ["<leader>4"] = { action = "core.win4", desc = "Go to window 4" },
    ["<leader>5"] = { action = "core.win5", desc = "Go to window 5" },
    ["<leader>6"] = { action = "core.win6", desc = "Go to window 6" },
  },

  ui = {
    ["<leader>e"] = { action = "nvim-tree.toggle", desc = "File explorer" },
  },
}
