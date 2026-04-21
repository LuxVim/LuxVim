-- lua/types/plugin.lua
-- GENERATED FILE - DO NOT EDIT
-- Run :LuxVimGenerateTypes to regenerate

---@class BuildSpec
---@field cmd string Build command
---@field cond? string Condition from registry
---@field on_fail? enum 
---@field outputs? any[] Expected output files
---@field platforms? table Platform-specific build commands
---@field requires? any[] Required executables

---@class PluginSpec
---@field actions? table Action overrides for keymap resolution
---@field build? string|table Build configuration
---@field cmd? string|any[] Lazy-load on command
---@field cond? string|function Load condition
---@field config? function Custom config function
---@field debug_name? string Override debug folder name
---@field dependencies? any[] References to other plugin specs
---@field enabled? boolean Enable/disable plugin
---@field event? string|any[] Lazy-load on event
---@field ft? string|any[] Lazy-load on filetype
---@field lazy? table Lazy.nvim native fields
---@field opts? table Options passed to setup()
---@field source string GitHub repo (author/name)

---@class KeymapEntry
---@field action string Action to invoke
---@field desc? string Description for which-key
---@field mode? string|any[] Vim mode(s)

---@class AutocmdEntry
---@field action string Action to invoke
---@field once? boolean Run only once
---@field pattern? string|any[] File pattern