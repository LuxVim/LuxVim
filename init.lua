local this_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
dofile(this_dir .. "/packages/luxvim/init.lua")
