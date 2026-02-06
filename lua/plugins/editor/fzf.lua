return {
  source = "junegunn/fzf.vim",
  dependencies = { "fzf" },
  cmd = { "Files", "GFiles", "Buffers", "Rg", "Lines", "History", "Commits", "Commands" },
  actions = {
    files = ":Files",
    search_text = ":SearchText",
  },
  globals = {
    fzf_layout = { down = "20%" },
  },
}
