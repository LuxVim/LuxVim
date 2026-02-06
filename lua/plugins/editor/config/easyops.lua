return {
  easyops_commands_main = {
    { label = "Git", command = "menu:git" },
    { label = "Window", command = "menu:window" },
    { label = "File", command = "menu:file" },
    { label = "Code", command = "menu:code" },
    { label = "Misc", command = "menu:misc" },
  },

  easyops_commands_code = {
    { label = "Maven", command = "menu:springboot|maven" },
    { label = "Vim", command = "menu:vim" },
  },

  easyops_commands_misc = {
    { label = "Create EasyEnv", command = ":EasyEnvCreate" },
  },
}
