-- Parser ships with Neovim; declared so the registry is the complete picture
-- of what LuxVim supports, not just what it has to install.
return {
  lsp_servers = { "lua_ls" },
  options = { tabstop = 2, shiftwidth = 2, expandtab = true },
}
