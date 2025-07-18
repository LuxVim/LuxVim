return {
  -- Editor enhancement plugins
  {
    "josstei/vim-easyline",
    config = function()
      vim.g.easyline_left_active_items_NvimTree = { 'windownumber' }
      vim.g.easyline_left_inactive_items_NvimTree = { 'windownumber' }
      vim.g.easyline_right_active_items_NvimTree = {}
      vim.g.easyline_right_inactive_items_NvimTree = {}

      vim.g.easyline_left_active_items_tidyterm = { 'windownumber', 'git' }
      vim.g.easyline_left_inactive_items_tidyterm = { 'windownumber' }
      vim.g.easyline_right_active_items_tidyterm = { 'filetype' }
      vim.g.easyline_right_inactive_items_tidyterm = { 'filetype' }

      vim.g.easyline_left_active_items_luxdash = { 'windownumber', 'git' }
      vim.g.easyline_left_inactive_items_luxdash = { 'windownumber' }
      vim.g.easyline_right_active_items_luxdash = {}
      vim.g.easyline_right_inactive_items_luxdash = {}

      vim.g.easyline_left_active_items = { 'windownumber', 'git', 'filename', 'modified' }
      vim.g.easyline_left_inactive_items = { 'windownumber' }
      vim.g.easyline_right_active_items = { 'position', 'filetype', 'encoding' }
      vim.g.easyline_right_inactive_items = { 'filename' }

      vim.g.easyline_left_separator = ''
      vim.g.easyline_right_separator = ''
    end,
  },

  {
    "josstei/vim-easycomment",
  },

  {
    "josstei/vim-easyops",
    config = function()
      vim.g.easyops_commands_main = {
        { label = 'Git',    command = 'menu:git' },
        { label = 'Window', command = 'menu:window' },
        { label = 'File',   command = 'menu:file' },
        { label = 'Code',   command = 'menu:code' },
        { label = 'Misc',   command = 'menu:misc' }
      }

      vim.g.easyops_commands_code = {
        { label = 'Maven', command = 'menu:springboot|maven' },
        { label = 'Vim',   command = 'menu:vim' }
      }

      vim.g.easyops_commands_misc = {
        { label = 'Create EasyEnv', command = ':EasyEnvCreate' }
      }
      vim.g.easyops_menu_misc = { commands = vim.g.easyops_commands_misc }
    end,
  },

  {
    "josstei/vim-easyenv",
  },

  {
    "josstei/vim-tidyterm",
  },

  {
    "josstei/vim-backtrack",
    config = function()
      vim.g.backtrack_split = 'botright vsplit'
      vim.g.backtrack_max_count = 10
      vim.g.backtrack_alternate_split_types = { 'easydash' }
      vim.g.backtrack_alternate_split = ''
    end,
  },
}
