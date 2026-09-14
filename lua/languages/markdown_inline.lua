-- Parser-only: no buffer ever has this filetype. markdown/injections.scm
-- injects it for emphasis, links, and code spans, so markdown highlighting is
-- half-dead without it.
return {
  filetypes = {},
}
