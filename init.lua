-- **********************************************************
-- ********************* LUXVIM *****************************
-- **********************************************************

local current_dir = vim.fn.expand("<sfile>:p:h")
current_dir = current_dir:gsub("\\", "/")
vim.opt.runtimepath:prepend(current_dir)

local lua_dir = current_dir .. "/lua"
package.path = lua_dir .. "/?.lua;" .. lua_dir .. "/?/init.lua;" .. package.path

vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")

local core = require("core")
core.setup()
