-- lua/sfml/fold.lua
-- Fold expressions for SFML: EVERY...END and IF...END blocks.

local M = {}

---@param lnum integer  (1-based)
---@return string  vim foldexpr result
function M.foldexpr(lnum)
	local line = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1] or ""
	local trimmed = line:match("^%s*(.-)%s*$"):upper()

	-- EVERY ... DO opens a fold
	if trimmed:match("^EVERY%s") and trimmed:match("%sDO%s*$") then
		return ">1"
	end
	if trimmed == "EVERY REDSTONE PULSE DO" then
		return ">1"
	end

	-- IF ... THEN opens a nested fold
	if trimmed:match("^IF%s") and trimmed:match("%sTHEN%s*$") then
		return ">2"
	end

	-- ELSE is at same level as IF body
	if trimmed == "ELSE" or trimmed:match("^ELSE%s+IF%s") then
		return "=2"
	end

	-- END closes
	if trimmed == "END" then
		return "<1"
	end

	return "="
end

return M
