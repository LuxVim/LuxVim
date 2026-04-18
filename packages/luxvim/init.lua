-- **********************************************************
-- ********************* LUXVIM *****************************
-- **********************************************************

local function script_dir()
  local info = debug.getinfo(1, "S")
  local source = info and info.source or ""
  if source:sub(1, 1) == "@" then
    source = source:sub(2)
  end
  local dir = source:match("(.*[/\\])")
  if not dir then
    return "."
  end
  dir = dir:gsub("\\", "/")
  if dir:sub(-1) == "/" then
    dir = dir:sub(1, -2)
  end
  return dir
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
