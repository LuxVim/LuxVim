local two_space = { tabstop = 2, shiftwidth = 2, expandtab = true }
local four_space = { tabstop = 4, shiftwidth = 4, expandtab = true }

return {
  lua = two_space,
  json = two_space,
  yaml = two_space,
  javascript = two_space,
  typescript = two_space,

  python = vim.tbl_extend("force", four_space, { colorcolumn = "88" }),

  markdown = {
    wrap = true,
    spell = true,
    conceallevel = 2,
  },
}
