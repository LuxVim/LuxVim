local M = {}

M.original_colorscheme = nil

function M.save_current()
    M.original_colorscheme = vim.g.colors_name
end

function M.apply(colorscheme)
    local ok, _ = pcall(vim.cmd, "colorscheme " .. colorscheme)
    if not ok then
        vim.notify("Failed to preview: " .. colorscheme, vim.log.levels.WARN)
        return false
    end
    return true
end

function M.restore()
    if M.original_colorscheme then
        pcall(vim.cmd, "colorscheme " .. M.original_colorscheme)
    end
end

function M.confirm()
    M.original_colorscheme = vim.g.colors_name
end

return M
