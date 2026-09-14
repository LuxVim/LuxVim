-- tests/unit/core/lib/languages_spec.lua
-- Tests the language abstraction: normalization of a declaration file into a
-- language row, and the three derivations every consumer reads off it —
-- the parser set (provisioning + health), the filetype->options map (editor
-- settings), and the filetype->language map (runtime failure reporting).

local languages = require("core.lib.languages")
local tmpdir = require("tests.helpers.tmpdir")

describe("core.lib.languages", function()
  local cleanups = {}

  local function tmp(tree)
    local root, cleanup = tmpdir.new(tree)
    table.insert(cleanups, cleanup)
    return root
  end

  local function load(tree)
    local rows, errors = languages.load({ dirs = { { path = tmp(tree), source = "framework" } } })
    return rows, errors
  end

  local function by_name(rows, name)
    for _, row in ipairs(rows) do
      if row.name == name then
        return row
      end
    end
  end

  after_each(function()
    for _, cleanup in ipairs(cleanups) do
      cleanup()
    end
    cleanups = {}
  end)

  describe("normalization", function()
    it("defaults the parser name to the declaration's filename", function()
      local rows = load({ ["go.lua"] = "return {}" })

      assert.equal("go", by_name(rows, "go").parser)
    end)

    it("honors an explicit parser name that differs from the filename", function()
      local rows = load({ ["shell.lua"] = "return { parser = 'bash' }" })

      assert.equal("bash", by_name(rows, "shell").parser)
    end)

    it("defaults filetypes to the declaration's filename", function()
      local rows = load({ ["go.lua"] = "return {}" })

      assert.same({ "go" }, by_name(rows, "go").filetypes)
    end)

    it("honors an explicit filetypes list", function()
      local rows = load({ ["tsx.lua"] = "return { filetypes = { 'typescriptreact' } }" })

      assert.same({ "typescriptreact" }, by_name(rows, "tsx").filetypes)
    end)

    it("allows a parser-only language to declare no filetypes", function()
      local rows = load({ ["markdown_inline.lua"] = "return { filetypes = {} }" })

      assert.same({}, by_name(rows, "markdown_inline").filetypes)
    end)

    it("defaults options to an empty table", function()
      local rows = load({ ["go.lua"] = "return {}" })

      assert.same({}, by_name(rows, "go").options)
    end)

    it("returns rows sorted by name so every consumer sees a stable order", function()
      local rows = load({
        ["rust.lua"] = "return {}",
        ["go.lua"] = "return {}",
        ["css.lua"] = "return {}",
      })

      assert.same(
        { "css", "go", "rust" },
        vim.tbl_map(function(r)
          return r.name
        end, rows)
      )
    end)

    it("surfaces loader errors rather than swallowing a broken declaration", function()
      local _, errors = load({ ["broken.lua"] = "not lua at all (" })

      assert.equal(1, #errors)
    end)
  end)

  describe("parsers", function()
    it("collects the parser of every declared language, sorted", function()
      local rows = load({
        ["rust.lua"] = "return {}",
        ["go.lua"] = "return {}",
      })

      assert.same({ "go", "rust" }, languages.parsers(rows))
    end)

    it("dedupes when two languages share one parser", function()
      local rows = load({
        ["javascript.lua"] = "return { parser = 'javascript' }",
        ["jsx.lua"] = "return { parser = 'javascript' }",
      })

      assert.same({ "javascript" }, languages.parsers(rows))
    end)

    it("omits a language that declares parser = false", function()
      local rows = load({
        ["go.lua"] = "return {}",
        ["text.lua"] = "return { parser = false }",
      })

      assert.same({ "go" }, languages.parsers(rows))
    end)
  end)

  describe("filetype_options", function()
    it("maps each declared filetype to that language's options", function()
      local rows = load({
        ["python.lua"] = "return { options = { tabstop = 4, colorcolumn = '88' } }",
      })

      assert.same({ tabstop = 4, colorcolumn = "88" }, languages.filetype_options(rows).python)
    end)

    it("maps every filetype of a multi-filetype language to the same options", function()
      local rows = load({
        ["bash.lua"] = "return { filetypes = { 'sh', 'bash' }, options = { tabstop = 2 } }",
      })

      local opts = languages.filetype_options(rows)
      assert.same({ tabstop = 2 }, opts.sh)
      assert.same({ tabstop = 2 }, opts.bash)
    end)

    it("omits languages that declare no options so no empty autocmd is registered", function()
      local rows = load({ ["go.lua"] = "return {}" })

      assert.same({}, languages.filetype_options(rows))
    end)
  end)

  describe("by_filetype", function()
    it("maps each declared filetype to its language row", function()
      local rows = load({ ["bash.lua"] = "return { filetypes = { 'sh', 'bash' } }" })

      local index = languages.by_filetype(rows)
      assert.equal("bash", index.sh.name)
      assert.equal("bash", index.bash.name)
    end)

    it("does not index a language that declares no filetypes", function()
      local rows = load({ ["markdown_inline.lua"] = "return { filetypes = {} }" })

      assert.same({}, languages.by_filetype(rows))
    end)
  end)

  describe("missing_parsers", function()
    it("reports a declared parser the resolver cannot find", function()
      local rows = load({
        ["go.lua"] = "return {}",
        ["rust.lua"] = "return {}",
      })

      local missing = languages.missing_parsers(rows, function(lang)
        return lang == "rust"
      end)

      assert.same({ "go" }, missing)
    end)

    -- Negative partner to the test above: with the resolver satisfied the
    -- report must be empty. A missing_parsers that always returned {} would
    -- pass this one and fail the one above, and vice versa.
    it("reports nothing when the resolver finds every declared parser", function()
      local rows = load({
        ["go.lua"] = "return {}",
        ["rust.lua"] = "return {}",
      })

      local missing = languages.missing_parsers(rows, function()
        return true
      end)

      assert.same({}, missing)
    end)

    it("never reports a language that declares parser = false", function()
      local rows = load({ ["text.lua"] = "return { parser = false }" })

      local missing = languages.missing_parsers(rows, function()
        return false
      end)

      assert.same({}, missing)
    end)

    it("resolves against the runtimepath by default, so bundled parsers are not missing", function()
      -- lua ships with Neovim; nothing installs it and it must never be
      -- reported as a gap. This is the regression that commit 4b64584 fixed
      -- for query gaps, asserted here for the parser set.
      local rows = load({ ["lua.lua"] = "return {}" })

      assert.same({}, languages.missing_parsers(rows))
    end)
  end)

  describe("default_dirs", function()
    it("puts the user language directory after the framework one so users win", function()
      local dirs = languages.default_dirs()

      assert.equal(2, #dirs)
      assert.equal("framework", dirs[1].source)
      assert.equal("user", dirs[2].source)
      assert.is_not_nil(dirs[1].path:find("lua/languages", 1, true))
      assert.is_not_nil(dirs[2].path:find("languages", 1, true))
    end)
  end)
  describe("rows", function()
    -- load() returns (rows, errors). Threading that straight into another
    -- function silently passes `errors` as the second argument — which is
    -- exactly how missing_parsers() once received a table where it wanted a
    -- resolver. rows() exists so the common case cannot make that mistake.
    it("returns exactly one value, never the error list alongside it", function()
      local root = tmp({ ["go.lua"] = "return {}" })

      assert.equal(1, select("#", languages.rows({ dirs = { { path = root } } })))
    end)

    it("returns the same declarations load() does", function()
      local root = tmp({ ["go.lua"] = "return {}", ["rust.lua"] = "return {}" })
      local opts = { dirs = { { path = root } } }

      assert.same((languages.load(opts)), languages.rows(opts))
    end)
  end)
end)
