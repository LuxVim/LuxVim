-- Usage (from repo root):
--   nvim --headless -c 'luafile scripts/helpers/enumerate-specs.lua' -c 'qa!'
-- Output (stdout, last line):
--   JSON array of { name, source, build } for every LuxVim plugin spec
--   (excludes virtual specs — those have no upstream source).

local here = vim.fn.getcwd()
local pkg = here .. "/packages/luxvim"

vim.env.LUXVIM_ROOT = pkg

local lua_dir = pkg .. "/lua"
package.path = lua_dir .. "/?.lua;" .. lua_dir .. "/?/init.lua;" .. package.path
vim.opt.runtimepath:prepend(pkg)

local pipeline = require("core.lib.pipeline")
local discover = require("core.lib.pipeline.discover")
local load_stage = require("core.lib.pipeline.load")
local merge = require("core.lib.pipeline.merge")
local debug_mod = require("core.lib.debug")
local paths_mod = require("core.lib.paths")

pipeline.reset()
pipeline.register_stage("discover", discover.run)
pipeline.register_stage("load", load_stage.run)
pipeline.register_stage("merge", merge.run)

local result = pipeline.run()

local rows = {}
for _, spec in ipairs(result.specs or {}) do
  if spec.source and spec.source ~= "" and spec.source ~= "virtual" then
    table.insert(rows, {
      name = debug_mod.resolve_debug_name(spec),
      lockfile_name = paths_mod.basename(spec.source),
      source = spec.source,
      build = spec.build or vim.NIL,
    })
  end
end

io.write(vim.fn.json_encode(rows))
io.write("\n")
