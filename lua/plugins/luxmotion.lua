return {
    "LuxVim/nvim-luxmotion",
    config = function()
        require("luxmotion").setup({
            cursor = {
                duration = 10,
                easing = "ease-out",
                enabled = true,
            },
            scroll = {
                duration = 380,
                easing = "ease-out", 
                enabled = true,
            },
            keymaps = {
                cursor = true,
                scroll = true,
                experimental = false,
            },
        })
    end,
}