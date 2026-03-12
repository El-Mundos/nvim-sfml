-- ftplugin/sfml.lua
-- Buffer-local settings for SFML files
if vim.b.did_ftplugin_sfml then
	return
end
vim.b.did_ftplugin_sfml = true

local buf = vim.api.nvim_get_current_buf()

-- Indentation
vim.bo.expandtab = true
vim.bo.shiftwidth = 4
vim.bo.tabstop = 4
vim.bo.softtabstop = 4

-- Comments
vim.bo.commentstring = "-- %s"

-- Folding
vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr = "v:lua.require('sfml.fold').foldexpr(v:lnum)"
vim.opt_local.foldlevel = 99

-- Omnifunc for completion
vim.bo.omnifunc = "v:lua.require('sfml.complete').omnifunc"

-- Buffer commands
vim.api.nvim_buf_create_user_command(buf, "SFMLLint", function()
	require("sfml.lint").run_and_populate_qf(buf)
end, { desc = "Run SFML linter and populate quickfix" })

vim.api.nvim_buf_create_user_command(buf, "SFMLFormat", function()
	require("sfml.format").format_buffer(buf)
end, { desc = "Normalize SFML keywords to uppercase" })

-- Auto-lint on save
local group = vim.api.nvim_create_augroup("sfml_ftplugin_" .. buf, { clear = true })

vim.api.nvim_create_autocmd("BufWritePost", {
	group = group,
	buffer = buf,
	callback = function()
		require("sfml.lint").run_and_set_diagnostics(buf)
	end,
})

-- Lint on open
vim.api.nvim_create_autocmd({ "BufEnter", "BufRead" }, {
	group = group,
	buffer = buf,
	once = true,
	callback = function()
		require("sfml.lint").run_and_set_diagnostics(buf)
	end,
})

-- Live lint (debounced)
local lint_timer = nil
vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
	group = group,
	buffer = buf,
	callback = function()
		local cfg = vim.g.sfml_config or {}
		local delay = cfg.lint_delay_ms or 400
		if lint_timer then
			lint_timer:stop()
		end
		lint_timer = vim.defer_fn(function()
			if vim.api.nvim_buf_is_valid(buf) then
				require("sfml.lint").run_and_set_diagnostics(buf)
			end
		end, delay)
	end,
})

-- Optional: format on save
vim.api.nvim_create_autocmd("BufWritePre", {
	group = group,
	buffer = buf,
	callback = function()
		local cfg = vim.g.sfml_config or {}
		if cfg.format_on_save then
			require("sfml.format").format_buffer(buf)
		end
	end,
})
