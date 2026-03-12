-- lua/sfml/format.lua
-- Keyword normalization: uppercase SFML keywords in-place.
-- Preserves strings, comments, and resource ID namespaces.

local M = {}

local KEYWORDS = {
	NAME = true,
	EVERY = true,
	DO = true,
	END = true,
	REDSTONE = true,
	PULSE = true,
	TICKS = true,
	TICK = true,
	SECONDS = true,
	SECOND = true,
	GLOBAL = true,
	PLUS = true,
	INPUT = true,
	OUTPUT = true,
	FROM = true,
	TO = true,
	EACH = true,
	RETAIN = true,
	FORGET = true,
	EXCEPT = true,
	EMPTY = true,
	SLOTS = true,
	SLOT = true,
	IN = true,
	WITH = true,
	WITHOUT = true,
	TAG = true,
	IF = true,
	THEN = true,
	ELSE = true,
	HAS = true,
	NOT = true,
	AND = true,
	OR = true,
	TRUE = true,
	FALSE = true,
	OVERALL = true,
	SOME = true,
	ONE = true,
	LONE = true,
	GT = true,
	LT = true,
	EQ = true,
	LE = true,
	GE = true,
	ROUND = true,
	ROBIN = true,
	BY = true,
	LABEL = true,
	BLOCK = true,
	TOP = true,
	BOTTOM = true,
	NORTH = true,
	EAST = true,
	SOUTH = true,
	WEST = true,
	SIDE = true,
	LEFT = true,
	RIGHT = true,
	FRONT = true,
	BACK = true,
	NULL = true,
	WHERE = true,
}

---@param bufnr integer
function M.format_buffer(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local source = table.concat(lines, "\n")

	local p = require("sfml.parser")
	local tokens = p.tokenize(source)
	local TT = p.TT

	-- Build line → byte offset map
	local line_starts = { 1 }
	for i = 1, #source do
		if source:sub(i, i) == "\n" then
			table.insert(line_starts, i + 1)
		end
	end
	local function byte_offset(line1, col0)
		return (line_starts[line1] or 1) + col0
	end

	local new_source = {}
	local prev_byte = 1
	local prev_non_ws = nil

	for _, tok in ipairs(tokens) do
		if tok.type == TT.IDENT then
			local upper = tok.upper
			if KEYWORDS[upper] and prev_non_ws ~= TT.COLON then
				if tok.value ~= upper then
					local start_b = byte_offset(tok.line, tok.col)
					local end_b = start_b + #tok.value
					if start_b >= prev_byte then
						table.insert(new_source, source:sub(prev_byte, start_b - 1))
						table.insert(new_source, upper)
						prev_byte = end_b
					end
				end
			end
			prev_non_ws = TT.IDENT
		elseif tok.type ~= TT.COMMENT and tok.type ~= TT.EOF then
			prev_non_ws = tok.type
		end
	end

	table.insert(new_source, source:sub(prev_byte))
	local formatted = table.concat(new_source)

	if formatted == source then
		vim.notify("[sfml] Already formatted.", vim.log.levels.INFO)
		return
	end

	local new_lines = vim.split(formatted, "\n", { plain = true })
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
	vim.notify("[sfml] Keywords normalized to uppercase.", vim.log.levels.INFO)
end

return M
