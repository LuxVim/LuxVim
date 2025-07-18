return {
  -- LuxVim specific plugins
  {
    "LuxVim/vim-luxpane",
    optional = true,
    config = function()
      vim.g.luxpane_protected_bt = { 'quickfix', 'help', 'nofile', 'terminal' }
      vim.g.luxpane_protected_ft = { 'NvimTree'}
    end,
  },

  {
    dir = "/home/josstei/Development/workspace/nvim-plugins/luxdash.nvim",
    name = "luxdash.nvim",
    -- optional = true,
    config = function()
      require("luxdash").setup({
        name = 'LuxVim',
        logo_color = {
            preset = nil,
            gradient = nil,
        },
        logo = {
          ' ',
          ' █████                              █████   █████  ███                 ',
          '░░███                              ░░███   ░░███  ░░░                  ',
          ' ░███        █████ ████ █████ █████ ░███    ░███  ████  █████████████  ',
          ' ░███       ░░███ ░███ ░░███ ░░███  ░███    ░███ ░░███ ░░███░░███░░███ ',
          ' ░███        ░███ ░███  ░░░█████░   ░░███   ███   ░███  ░███ ░███ ░███ ',
          ' ░███      █ ░███ ░███   ███░░░███   ░░░█████░    ░███  ░███ ░███ ░███ ',
          ' ███████████ ░░████████ █████ █████    ░░███      █████ █████░███ █████',
          '░░░░░░░░░░░   ░░░░░░░░ ░░░░░ ░░░░░      ░░░      ░░░░░ ░░░░░ ░░░ ░░░░░ ',
          ' '
        },
        options = { 'newfile', 'backtrack', 'fzf', 'closelux' },
        extras = { vim.fn.strftime('%c'), '' }
      })
    end,
  },
}
