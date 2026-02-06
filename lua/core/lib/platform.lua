local M = {}

M.os = vim.fn.has("mac") == 1 and "mac"
    or vim.fn.has("win32") == 1 and "windows"
    or "linux"

M.is_mac = M.os == "mac"
M.is_windows = M.os == "windows"
M.is_linux = M.os == "linux"

return M
