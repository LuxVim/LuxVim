return {
  source = "junegunn/fzf",
  build = {
    cmd = "./install --bin",
    requires = { "git" },
  },
}
