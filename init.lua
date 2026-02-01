-- **********************************************************
-- ********************* LUXVIM *****************************
-- **********************************************************

local current_dir = vim.fn.expand("<sfile>:p:h")
vim.opt.runtimepath:prepend(current_dir)

package.path = current_dir .. "/lua/?.lua;" .. current_dir .. "/lua/?/init.lua;" .. package.path

vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")

local core = require("core")
core.setup()
