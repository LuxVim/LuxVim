return {
    "LuxVim/nvim-luxterm",
    config = function()
        require('luxterm').setup({
            autostart = false,
            position = 'bottom',
            size = 20,
            filetype = 'sh',
            session_persistence = true,
            floating_window = true,
            floating_width = 0.8,
            floating_height = 0.6,
            floating_border = 'rounded',
            smart_position = true,
            focus_on_toggle = true,
            remember_size = true,
            statusline_integration = true,
            history_size = 100,
            shell_integration = true,
            auto_cd = true,
            terminal_title = true,
            quick_commands = {}
        })
        
    end,
}