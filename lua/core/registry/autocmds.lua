return {
  FileType = {
    action = "core.filetype_setup",
    pattern = { "fzf", "qf" },
  },
  BufLeave = {
    action = "core.fzf_bufleave",
  },
  VimEnter = {
    action = "core.ensure_diagnostic_virtual_text",
  },
}
