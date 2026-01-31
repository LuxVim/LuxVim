return {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
        local ok, configs = pcall(require, "nvim-treesitter.configs")
        if not ok then
            return
        end
        configs.setup({
            ensure_installed = {
                "bash", "c", "cpp", "css", "go", "html", "java",
                "javascript", "json", "lua", "markdown", "markdown_inline",
                "python", "rust", "swift", "tsx", "typescript", "vim", "vimdoc", "yaml",
            },
            auto_install = true,
            highlight = { enable = true },
            indent = { enable = true },
        })
    end,
}
