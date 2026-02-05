return {
  source = "junegunn/fzf",
  build = {
    cmd = "./install --bin",
    platforms = {
      windows = "powershell -ExecutionPolicy Bypass -File .\\install.ps1",
    },
    requires = { "git" },
  },
}
