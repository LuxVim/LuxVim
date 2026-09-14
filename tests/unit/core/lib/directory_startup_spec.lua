local startup = require("core.lib.directory_startup")

describe("directory startup", function()
  local root
  before_each(function()
    root = vim.fn.tempname() .. " directory with spaces"
    vim.fn.mkdir(root, "p")
    vim.fn.writefile({ "file" }, root .. "/file.txt")
  end)
  after_each(function()
    vim.cmd("%argdelete")
    vim.fn.delete(root, "rf")
  end)

  it("recognizes one directory argument with spaces", function()
    vim.cmd("argadd " .. vim.fn.fnameescape(root))
    assert.equal(vim.fn.fnamemodify(root, ":p"), startup.directory_argument())
  end)
  it("leaves file and multiple-argument launches alone", function()
    vim.cmd("argadd " .. vim.fn.fnameescape(root .. "/file.txt"))
    assert.is_nil(startup.directory_argument())
    vim.cmd("argadd " .. vim.fn.fnameescape(root))
    assert.is_nil(startup.directory_argument())
  end)
  it("leaves an editing buffer intact if startup commands changed it", function()
    local buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].modified = true
    startup.open(root)
    assert.equal(buf, vim.api.nvim_get_current_buf())
    assert.is_true(vim.bo[buf].modified)
    vim.bo[buf].modified = false
  end)
end)
