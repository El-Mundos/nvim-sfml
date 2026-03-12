-- lua/sfml/init.lua
-- nvim-sfml entry point

local M = {}

---@class SFMLConfig
---@field auto_lint boolean         Enable auto-lint on save/change (default: true)
---@field lint_delay_ms integer     Debounce delay for live linting in ms (default: 400)
---@field format_on_save boolean    Auto-format keywords on save (default: false)
---@field register_cmp boolean      Register nvim-cmp source if available (default: true)

local defaults = {
	auto_lint = true,
	lint_delay_ms = 400,
	format_on_save = false,
	register_cmp = true,
}

M.config = vim.deepcopy(defaults)

---Setup the plugin
---@param opts SFMLConfig|nil
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", defaults, opts or {})

	-- Expose config to ftplugin
	vim.g.sfml_config = M.config

	-- Register cmp source (deferred so cmp has time to load)
	if M.config.register_cmp then
		vim.defer_fn(function()
			require("sfml.complete").setup_cmp()
		end, 0)
	end
end

return M
