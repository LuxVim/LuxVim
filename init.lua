local source = debug.getinfo(1, "S").source or ""
if source:sub(1, 1) == "@" then
  source = source:sub(2)
end
local this_dir = vim.fn.fnamemodify(source, ":p:h"):gsub("\\", "/")
dofile(this_dir .. "/packages/luxvim/init.lua")
