-- The parser is 'bash'; Neovim sets 'sh' for shell scripts and 'bash' only
-- when the shebang or b:is_bash says so, so claim both.
return {
  lsp_servers = { "bashls" },
  filetypes = { "sh", "bash" },
}
