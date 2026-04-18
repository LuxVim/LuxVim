-- **********************************************************
-- ********************* LUXVIM *****************************
-- **********************************************************

local function script_dir()
  local source = debug.getinfo(1, "S").source or ""
  if source:sub(1, 1) == "@" then
    source = source:sub(2)
  end
  return (vim.fn.fnamemodify(source, ":p:h"):gsub("\\", "/"))
end

local current_dir = script_dir()
vim.opt.runtimepath:prepend(current_dir)

local lua_dir = current_dir .. "/lua"
package.path = lua_dir .. "/?.lua;" .. lua_dir .. "/?/init.lua;" .. package.path

vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")

local core = require("core")
core.setup()
