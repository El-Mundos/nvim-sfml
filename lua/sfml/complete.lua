-- lua/sfml/complete.lua
-- Context-aware completion for SFML.

local parser = require("sfml.parser")
local M = {}

local RESOURCE_PREFIXES = {
	{ word = "item::", menu = "resource type (default)" },
	{ word = "fluid::", menu = "resource type" },
	{ word = "forge_energy::", menu = "resource type (RF/FE)" },
	{ word = "fe::", menu = "alias → forge_energy" },
	{ word = "rf::", menu = "alias → forge_energy" },
	{ word = "energy::", menu = "alias → forge_energy" },
	{ word = "power::", menu = "alias → forge_energy" },
	{ word = "chemical::", menu = "resource type (Mekanism)" },
	{ word = "gas::", menu = "alias → chemical" },
	{ word = "infusion::", menu = "alias → chemical" },
	{ word = "mekanism_energy::", menu = "resource type (Mekanism energy)" },
}

local COMMON_NAMESPACES = { "minecraft:", "forge:", "create:", "thermal:", "mekanism:" }

local SIDES = {
	"TOP",
	"BOTTOM",
	"NORTH",
	"EAST",
	"SOUTH",
	"WEST",
	"LEFT",
	"RIGHT",
	"FRONT",
	"BACK",
	"NULL",
	"EACH SIDE",
}

local IO_KEYWORDS = {
	"INPUT",
	"OUTPUT",
	"FROM",
	"TO",
	"EACH",
	"RETAIN",
	"FORGET",
	"EXCEPT",
	"EMPTY SLOTS IN",
	"ROUND ROBIN BY LABEL",
	"ROUND ROBIN BY BLOCK",
}

local COND_KEYWORDS = {
	"IF",
	"THEN",
	"ELSE",
	"END",
	"HAS",
	"NOT",
	"AND",
	"OR",
	"TRUE",
	"FALSE",
	"OVERALL",
	"SOME",
	"EVERY",
	"ONE",
	"LONE",
	"GT",
	"LT",
	"EQ",
	"LE",
	"GE",
}

local WITH_KEYWORDS = { "WITH", "WITHOUT", "TAG", "WITH TAG", "WITHOUT TAG" }

-- ─── Context detection ───────────────────────────────────────────────────────

local function detect_context(line, col)
	local left = line:sub(1, col)

	-- After FROM/TO: label context (unless typing a resource)
	if left:match("%f[%a][Ff][Rr][Oo][Mm]%s+") or left:match("%f[%a][Tt][Oo]%s+") then
		local word = left:match("[%w_*:]+$") or ""
		if word:find(":") then
			return "resource"
		end
		return "label"
	end

	-- After INPUT before FROM: resource context
	if left:match("%f[%a][Ii][Nn][Pp][Uu][Tt]%s+") and not left:match("%f[%a][Ff][Rr][Oo][Mm]%s*") then
		return "resource"
	end
	if left:match("%f[%a][Oo][Uu][Tt][Pp][Uu][Tt]%s+") and not left:match("%f[%a][Tt][Oo]%s*") then
		return "resource"
	end

	-- After WITH/WITHOUT
	if left:match("%f[%a][Ww][Ii][Tt][Hh][Oo][Uu][Tt]?%s+$") then
		return "with"
	end

	-- After EVERY: interval context
	if left:match("%f[%a][Ee][Vv][Ee][Rr][Yy]%s+[%dg]*%s*$") then
		return "interval"
	end

	-- Side context
	if left:match("%f[%a][Ss][Ii][Dd][Ee]%s*$") then
		return "side"
	end

	-- Resource if current word contains ::
	local word = left:match("[%w_*.:]+$") or ""
	if word:find("::") or (word:find(":") and #word > 2) then
		return "resource"
	end

	return "keyword"
end

-- ─── Omnifunc ────────────────────────────────────────────────────────────────

function M.omnifunc(findstart, base)
	if findstart == 1 then
		local line = vim.api.nvim_get_current_line()
		local col = vim.api.nvim_win_get_cursor(0)[2]
		local i = col
		while i > 0 do
			local c = line:sub(i, i)
			if c:match("[%w_*:.]") then
				i = i - 1
			else
				break
			end
		end
		return i
	end

	local line = vim.api.nvim_get_current_line()
	local col = vim.api.nvim_win_get_cursor(0)[2]
	local ctx = detect_context(line, col)

	local bufnr = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local ok, parsed = pcall(parser.parse, table.concat(lines, "\n"))
	local buf_labels = ok and parsed.labels or {}

	local items = {}
	local base_lower = base:lower()

	local function add(word, kind, menu, info)
		if word:lower():find(base_lower, 1, true) == 1 then
			table.insert(items, { word = word, kind = kind or "", menu = menu or "", info = info or "" })
		end
	end

	if ctx == "resource" then
		for _, rp in ipairs(RESOURCE_PREFIXES) do
			add(rp.word, "[type]", rp.menu)
		end
		for _, ns in ipairs(COMMON_NAMESPACES) do
			add(ns, "[ns]", "namespace")
		end
	elseif ctx == "label" then
		for _, lbl in ipairs(buf_labels) do
			add(lbl, "[lbl]", "label in buffer")
		end
		add('"', "[str]", "quoted label")
	elseif ctx == "interval" then
		for _, u in ipairs({ "TICKS", "TICK", "SECONDS", "SECOND", "GLOBAL" }) do
			add(u, "[kw]", "interval unit")
		end
	elseif ctx == "with" then
		add("TAG", "[kw]", "with-clause")
		add("NOT", "[kw]", "negation")
	elseif ctx == "side" then
		for _, s in ipairs(SIDES) do
			add(s, "[kw]", "side")
		end
	else
		add("EVERY", "[kw]", "timer trigger", "EVERY <n> TICKS DO\n    \nEND")
		add("EVERY REDSTONE PULSE DO", "[kw]", "redstone trigger", "EVERY REDSTONE PULSE DO\n    \nEND")
		add('NAME ""', "[kw]", "program name")
		for _, kw in ipairs(IO_KEYWORDS) do
			add(kw, "[kw]", "io")
		end
		for _, kw in ipairs(COND_KEYWORDS) do
			add(kw, "[kw]", "condition")
		end
		for _, kw in ipairs(WITH_KEYWORDS) do
			add(kw, "[kw]", "with")
		end
		for _, rp in ipairs(RESOURCE_PREFIXES) do
			add(rp.word, "[type]", rp.menu)
		end
		for _, lbl in ipairs(buf_labels) do
			add(lbl, "[lbl]", "label")
		end
	end

	return items
end

-- ─── nvim-cmp source ─────────────────────────────────────────────────────────

M.cmp_source = {}

function M.cmp_source.new()
	return setmetatable({}, { __index = M.cmp_source })
end

function M.cmp_source:is_available()
	return vim.bo.filetype == "sfml"
end

function M.cmp_source:get_trigger_characters()
	return { ":", " ", '"' }
end

function M.cmp_source:get_debug_name()
	return "sfml"
end

function M.cmp_source:complete(params, callback)
	local ok_cmp, cmp = pcall(require, "cmp")
	if not ok_cmp then
		callback({ items = {}, isIncomplete = false })
		return
	end

	local line = params.context.cursor_before_line
	local col = params.context.cursor.col
	local ctx = detect_context(line, col)

	local bufnr = params.context.bufnr
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local ok, parsed = pcall(parser.parse, table.concat(lines, "\n"))
	local buf_labels = ok and parsed.labels or {}

	local items = {}

	local function kw(word, detail, doc, insert_text)
		table.insert(items, {
			label = word,
			kind = cmp.lsp.CompletionItemKind.Keyword,
			detail = detail,
			documentation = doc,
			insertText = insert_text or word,
			insertTextFormat = insert_text and 2 or 1,
		})
	end

	local function tp(word, detail)
		table.insert(items, {
			label = word,
			kind = cmp.lsp.CompletionItemKind.TypeParameter,
			detail = detail,
		})
	end

	local function lbl(word)
		table.insert(items, {
			label = word,
			kind = cmp.lsp.CompletionItemKind.Variable,
			detail = "label",
		})
	end

	if ctx == "resource" then
		for _, rp in ipairs(RESOURCE_PREFIXES) do
			tp(rp.word, rp.menu)
		end
		for _, ns in ipairs(COMMON_NAMESPACES) do
			tp(ns, "namespace")
		end
	elseif ctx == "label" then
		for _, l in ipairs(buf_labels) do
			lbl(l)
		end
	elseif ctx == "interval" then
		for _, u in ipairs({ "TICKS", "TICK", "SECONDS", "SECOND", "GLOBAL" }) do
			kw(u, "interval unit")
		end
	elseif ctx == "with" then
		kw("TAG", "tag matcher")
		kw("NOT", "negation")
	elseif ctx == "side" then
		for _, s in ipairs(SIDES) do
			kw(s, "side")
		end
	else
		kw("EVERY", "timer trigger", "Runs block on a timer", "EVERY ${1:20} TICKS DO\n    $0\nEND")
		kw(
			"EVERY REDSTONE PULSE DO",
			"redstone trigger",
			"Runs block on redstone pulse",
			"EVERY REDSTONE PULSE DO\n    $0\nEND"
		)
		kw('NAME ""', "program name", nil, 'NAME "$1"')
		for _, k in ipairs({ "INPUT", "OUTPUT", "FROM", "TO", "EACH", "RETAIN", "FORGET", "EXCEPT" }) do
			kw(k, "io keyword")
		end
		kw("EMPTY SLOTS IN", "output to empty slots only")
		kw("ROUND ROBIN BY LABEL", "round robin by label")
		kw("ROUND ROBIN BY BLOCK", "round robin by block")
		kw("IF", "conditional", "Conditional block", "IF ${1:condition} THEN\n    $0\nEND")
		for _, k in ipairs({ "THEN", "ELSE", "END", "HAS", "NOT", "AND", "OR", "TRUE", "FALSE" }) do
			kw(k, "condition")
		end
		for _, k in ipairs({ "OVERALL", "SOME", "EVERY", "ONE", "LONE" }) do
			kw(k, "set operator")
		end
		for _, k in ipairs({ "GT", "LT", "EQ", "LE", "GE", ">", "<", "=", "<=", ">=" }) do
			kw(k, "comparison")
		end
		kw("REDSTONE", "redstone signal strength")
		for _, k in ipairs(WITH_KEYWORDS) do
			kw(k, "with-clause")
		end
		for _, rp in ipairs(RESOURCE_PREFIXES) do
			tp(rp.word, rp.menu)
		end
		for _, l in ipairs(buf_labels) do
			lbl(l)
		end
	end

	callback({ items = items, isIncomplete = false })
end

function M.setup_cmp()
	local ok, cmp = pcall(require, "cmp")
	if not ok then
		return
	end
	cmp.register_source("sfml", M.cmp_source.new())
end

return M
