local globals = require("plugins.editor.config.easyops")

return {
  source = "josstei/vim-easyops",
  cmd = { "EasyOps" },
  actions = {
    open = ":EasyOps",
  },
  globals = globals,
  config = function()
    vim.g.easyops_menu_misc = { commands = vim.g.easyops_commands_misc }
  end,
}
