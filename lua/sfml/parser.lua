-- lua/sfml/parser.lua
-- Lightweight tokenizer + structural parser for SFML
-- Mirrors SFML.g4 (1.21.1) closely enough to support smart linting and completion
-- without needing ANTLR in Lua.

local M = {}

-- ─── Token types ─────────────────────────────────────────────────────────────

M.TT = {
	NUMBER = "NUMBER",
	NUMBER_G = "NUMBER_G",
	STRING = "STRING",
	IDENT = "IDENT",
	COLON = "COLON",
	COMMA = "COMMA",
	DASH = "DASH",
	SLASH = "SLASH",
	LPAREN = "LPAREN",
	RPAREN = "RPAREN",
	HASHTAG = "HASHTAG",
	PLUS = "PLUS",
	GTE = "GTE",
	LTE = "LTE",
	GT = "GT",
	LT = "LT",
	EQ = "EQ",
	COMMENT = "COMMENT",
	EOF = "EOF",
	UNKNOWN = "UNKNOWN",
}

M.KEYWORDS = {
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
	WHERE = true,
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
	PLUS = true,
}

M.KEYWORD_AS_IDENT = {
	REDSTONE = true,
	GLOBAL = true,
	SECOND = true,
	SECONDS = true,
	TOP = true,
	BOTTOM = true,
	LEFT = true,
	RIGHT = true,
	FRONT = true,
	BACK = true,
}

M.RESOURCE_TYPE_PREFIXES = {
	"item",
	"fluid",
	"forge_energy",
	"redstone",
	"fe",
	"rf",
	"energy",
	"power",
	"chemical",
	"gas",
	"infusion",
	"mekanism_energy",
}
M.RESOURCE_TYPE_SET = {}
for _, v in ipairs(M.RESOURCE_TYPE_PREFIXES) do
	M.RESOURCE_TYPE_SET[v] = true
end

M.ENERGY_TYPES = { forge_energy = true, fe = true, rf = true, energy = true, power = true, mekanism_energy = true }

-- ─── Tokenizer ───────────────────────────────────────────────────────────────

---@param source string
---@return SFMLToken[]
function M.tokenize(source)
	local tokens = {}
	local i = 1
	local line = 1
	local line_start = 1
	local len = #source

	local function col()
		return i - line_start
	end

	local function push(tt, value, ln, cl)
		table.insert(tokens, {
			type = tt,
			value = value,
			upper = value:upper(),
			line = ln,
			col = cl,
		})
	end

	while i <= len do
		local c = source:sub(i, i)

		if c == "\n" then
			line = line + 1
			line_start = i + 1
			i = i + 1
		elseif c:match("^%s$") then
			i = i + 1
		elseif source:sub(i, i + 1) == "--" then
			local ln, cl = line, col()
			local j = i + 2
			while j <= len and source:sub(j, j) ~= "\n" do
				j = j + 1
			end
			push(M.TT.COMMENT, source:sub(i, j - 1), ln, cl)
			i = j
		elseif c == '"' then
			local ln, cl = line, col()
			local j = i + 1
			local value = '"'
			while j <= len do
				local sc = source:sub(j, j)
				if sc == "\\" and source:sub(j + 1, j + 1) == '"' then
					value = value .. '\\"'
					j = j + 2
				elseif sc == '"' then
					value = value .. '"'
					j = j + 1
					break
				else
					if sc == "\n" then
						line = line + 1
						line_start = j + 1
					end
					value = value .. sc
					j = j + 1
				end
			end
			push(M.TT.STRING, value, ln, cl)
			i = j
		elseif c:match("^%d$") then
			local ln, cl = line, col()
			local j = i
			while j <= len and source:sub(j, j):match("^%d$") do
				j = j + 1
			end
			if j <= len and source:sub(j, j):match("^[gG]$") then
				push(M.TT.NUMBER_G, source:sub(i, j), ln, cl)
				i = j + 1
			else
				push(M.TT.NUMBER, source:sub(i, j - 1), ln, cl)
				i = j
			end
		elseif c:match("^[a-zA-Z_*]$") then
			local ln, cl = line, col()
			local j = i
			while j <= len and source:sub(j, j):match("^[a-zA-Z0-9_*]$") do
				j = j + 1
			end
			local word = source:sub(i, j - 1)
			push(M.TT.IDENT, word, ln, cl)
			i = j
		elseif source:sub(i, i + 1) == ">=" then
			push(M.TT.GTE, ">=", line, col())
			i = i + 2
		elseif source:sub(i, i + 1) == "<=" then
			push(M.TT.LTE, "<=", line, col())
			i = i + 2
		elseif c == ">" then
			push(M.TT.GT, c, line, col())
			i = i + 1
		elseif c == "<" then
			push(M.TT.LT, c, line, col())
			i = i + 1
		elseif c == "=" then
			push(M.TT.EQ, c, line, col())
			i = i + 1
		elseif c == ":" then
			push(M.TT.COLON, c, line, col())
			i = i + 1
		elseif c == "," then
			push(M.TT.COMMA, c, line, col())
			i = i + 1
		elseif c == "-" then
			push(M.TT.DASH, c, line, col())
			i = i + 1
		elseif c == "/" then
			push(M.TT.SLASH, c, line, col())
			i = i + 1
		elseif c == "(" then
			push(M.TT.LPAREN, c, line, col())
			i = i + 1
		elseif c == ")" then
			push(M.TT.RPAREN, c, line, col())
			i = i + 1
		elseif c == "#" then
			push(M.TT.HASHTAG, c, line, col())
			i = i + 1
		elseif c == "+" then
			push(M.TT.PLUS, c, line, col())
			i = i + 1
		else
			push(M.TT.UNKNOWN, c, line, col())
			i = i + 1
		end
	end

	push(M.TT.EOF, "", line, col())
	return tokens
end

-- ─── Parser ──────────────────────────────────────────────────────────────────

function M.parse(source)
	local tokens = M.tokenize(source)
	local pos = 1
	local errors = {}
	local all_labels = {}

	local function cur()
		return tokens[pos]
	end

	local function advance()
		local t = tokens[pos]
		if pos < #tokens then
			pos = pos + 1
		end
		return t
	end

	local function skip_comments()
		while cur() and cur().type == M.TT.COMMENT do
			advance()
		end
	end

	local function add_error(msg, tok, severity)
		tok = tok or cur()
		table.insert(errors, {
			msg = msg,
			line = tok and tok.line or 0,
			col = tok and tok.col or 0,
			severity = severity or "error",
		})
	end

	local function parse_resource_id()
		skip_comments()
		local t = cur()
		if not t then
			return nil
		end

		-- String resource
		if t.type == M.TT.STRING then
			advance()
			local raw = t.value
			local inner = raw:sub(2, #raw - 1)
			local parts = {}
			for p in (inner .. ":"):gmatch("([^:]*):") do
				table.insert(parts, p)
			end
			local rid = {
				type_ns = "sfm",
				type_name = "item",
				res_ns = parts[1] or ".*",
				res_name = parts[2] or ".*",
				raw = raw,
				line = t.line,
				col = t.col,
			}
			if #parts == 4 then
				rid.type_ns = parts[1]
				rid.type_name = parts[2]
				rid.res_ns = parts[3]
				rid.res_name = parts[4]
			elseif #parts == 3 then
				rid.type_name = parts[1]
				rid.res_ns = parts[2]
				rid.res_name = parts[3]
			end
			return rid
		end

		if t.type ~= M.TT.IDENT then
			return nil
		end

		local start_line, start_col = t.line, t.col
		local parts = {}
		local raw_parts = {}

		local STOP_KEYWORDS = {
			FROM = true,
			TO = true,
			EACH = true,
			EXCEPT = true,
			WITH = true,
			WITHOUT = true,
			DO = true,
			END = true,
			IF = true,
			THEN = true,
			ELSE = true,
			FORGET = true,
			INPUT = true,
			OUTPUT = true,
			ROUND = true,
			SIDE = true,
			SLOT = true,
			SLOTS = true,
			EMPTY = true,
			RETAIN = true,
			AND = true,
			OR = true,
			HAS = true,
			NOT = true,
			OVERALL = true,
			SOME = true,
			ONE = true,
			LONE = true,
			EVERY = true,
			REDSTONE = true,
			PULSE = true,
			NAME = true,
			TRUE = true,
			FALSE = true,
			IN = true,
		}

		repeat
			skip_comments()
			local id_tok = cur()
			if not id_tok then
				break
			end

			if id_tok.type == M.TT.IDENT then
				if #parts > 0 and STOP_KEYWORDS[id_tok.upper] then
					break
				end
				table.insert(parts, id_tok.value:lower())
				table.insert(raw_parts, id_tok.value)
				advance()
			else
				table.insert(parts, "*")
				table.insert(raw_parts, "")
			end

			skip_comments()
			if cur() and cur().type == M.TT.COLON and #parts < 4 then
				advance()
				if cur() and cur().type == M.TT.COLON then
					advance()
					skip_comments()
					local following = cur()
					if following and following.type == M.TT.IDENT and not STOP_KEYWORDS[following.upper] then
					-- continue: e.g. fluid::minecraft:water
					else
						table.insert(parts, "*")
						table.insert(raw_parts, "")
						table.insert(parts, "*")
						table.insert(raw_parts, "")
						break
					end
				end
			else
				break
			end
		until #parts >= 4

		if #parts == 0 then
			return nil
		end

		local rid = { raw = table.concat(raw_parts, ":"), line = start_line, col = start_col }

		if #parts == 1 then
			rid.type_ns = "sfm"
			rid.type_name = "item"
			rid.res_ns = ".*"
			rid.res_name = parts[1]:gsub("%*", ".*")
		elseif #parts == 2 then
			rid.type_ns = "sfm"
			rid.type_name = "item"
			rid.res_ns = parts[1]:gsub("%*", ".*")
			rid.res_name = parts[2]:gsub("%*", ".*")
		elseif #parts == 3 then
			rid.type_ns = "sfm"
			rid.type_name = parts[1]:gsub("%*", ".*")
			rid.res_ns = parts[2]:gsub("%*", ".*")
			rid.res_name = parts[3]:gsub("%*", ".*")
		else
			rid.type_ns = parts[1]:gsub("%*", ".*")
			rid.type_name = parts[2]:gsub("%*", ".*")
			rid.res_ns = parts[3]:gsub("%*", ".*")
			rid.res_name = parts[4]:gsub("%*", ".*")
		end

		local aliases = { fe = true, rf = true, energy = true, power = true }
		if rid.type_ns == "sfm" and aliases[rid.type_name] then
			rid.type_name = "forge_energy"
		end

		return rid
	end

	local LABEL_STOP = {
		ROUND = true,
		ROBIN = true,
		BY = true,
		SIDE = true,
		END = true,
		ELSE = true,
		DO = true,
		THEN = true,
		TICKS = true,
		TICK = true,
		SECONDS = true,
		SECOND = true,
		-- LABEL and BLOCK are round-robin keywords, not valid label names
		LABEL = true,
		BLOCK = true,
		-- IO structural keywords
		INPUT = true,
		OUTPUT = true,
		FROM = true,
		TO = true,
		FORGET = true,
		IF = true,
		EVERY = true,
	}

	local function parse_label()
		skip_comments()
		local t = cur()
		if not t then
			return nil
		end
		if t.type == M.TT.STRING then
			advance()
			local s = t.value:sub(2, #t.value - 1)
			all_labels[s] = true
			return s
		end
		if t.type == M.TT.IDENT then
			if LABEL_STOP[t.upper] then
				-- Special helpful errors for common mistakes
				if t.upper == "LABEL" then
					add_error(
						"'LABEL' is a keyword (used in ROUND ROBIN BY LABEL), not a label name. Did you mean a specific label name?",
						t,
						"error"
					)
				elseif t.upper == "BLOCK" then
					add_error("'BLOCK' is a keyword (used in ROUND ROBIN BY BLOCK), not a label name.", t, "error")
				end
				return nil
			end
			advance()
			local name = t.value
			all_labels[name:lower()] = true
			return name
		end
		return nil
	end

	local function parse_resource_limits()
		local rids = {}
		local has_each_qty = false

		skip_comments()

		local function is_limit_start()
			local t = cur()
			if not t then
				return false
			end
			if t.type == M.TT.NUMBER or t.type == M.TT.NUMBER_G then
				return true
			end
			if t.type == M.TT.IDENT and t.upper == "RETAIN" then
				return true
			end
			if t.type == M.TT.IDENT and (t.upper == "WITH" or t.upper == "WITHOUT") then
				return true
			end
			if t.type == M.TT.IDENT then
				local kw = t.upper
				if
					kw == "FROM"
					or kw == "TO"
					or kw == "EACH"
					or kw == "EXCEPT"
					or kw == "DO"
					or kw == "END"
					or kw == "IF"
					or kw == "THEN"
					or kw == "ELSE"
					or kw == "FORGET"
					or kw == "INPUT"
					or kw == "OUTPUT"
					or kw == "ROUND"
					or kw == "TOP"
					or kw == "BOTTOM"
					or kw == "NORTH"
					or kw == "EAST"
					or kw == "SOUTH"
					or kw == "WEST"
					or kw == "LEFT"
					or kw == "RIGHT"
					or kw == "FRONT"
					or kw == "BACK"
					or kw == "SIDE"
					or kw == "SLOT"
					or kw == "SLOTS"
					or kw == "EMPTY"
					or kw == "NAME"
					or kw == "EVERY"
					or kw == "REDSTONE"
					or kw == "PULSE"
				then
					return false
				end
				return true
			end
			if t.type == M.TT.STRING then
				return true
			end
			return false
		end

		while is_limit_start() do
			if cur() and (cur().type == M.TT.NUMBER or cur().type == M.TT.NUMBER_G) then
				advance()
				skip_comments()
				if cur() and cur().type == M.TT.IDENT and cur().upper == "EACH" then
					has_each_qty = true
					advance()
				end
			end

			skip_comments()
			if cur() and cur().type == M.TT.IDENT and cur().upper == "RETAIN" then
				advance()
				skip_comments()
				if cur() and cur().type == M.TT.NUMBER then
					advance()
				end
				skip_comments()
				if cur() and cur().type == M.TT.IDENT and cur().upper == "EACH" then
					advance()
				end
			end

			skip_comments()
			repeat
				local rid = parse_resource_id()
				if rid then
					table.insert(rids, rid)
				end
				skip_comments()
				if cur() and cur().type == M.TT.IDENT and cur().upper == "OR" then
					advance()
					skip_comments()
				else
					break
				end
			until false

			skip_comments()
			if cur() and cur().type == M.TT.IDENT and (cur().upper == "WITH" or cur().upper == "WITHOUT") then
				advance()
				local depth = 0
				while cur() and cur().type ~= M.TT.EOF do
					local t = cur()
					if t.type == M.TT.LPAREN then
						depth = depth + 1
						advance()
					elseif t.type == M.TT.RPAREN then
						if depth == 0 then
							break
						end
						depth = depth - 1
						advance()
					elseif t.type == M.TT.IDENT then
						local u = t.upper
						if
							depth == 0
							and (
								u == "FROM"
								or u == "TO"
								or u == "EXCEPT"
								or u == "EACH"
								or u == "ROUND"
								or u == "SLOT"
								or u == "SLOTS"
								or u == "EMPTY"
							)
						then
							break
						end
						advance()
					elseif t.type == M.TT.COMMA then
						if depth == 0 then
							break
						end
						advance()
					else
						advance()
					end
					skip_comments()
				end
			end

			skip_comments()
			if cur() and cur().type == M.TT.IDENT and cur().upper == "EXCEPT" then
				advance()
				repeat
					parse_resource_id()
					skip_comments()
				until not (cur() and cur().type == M.TT.COMMA and (advance() or true))
			end

			skip_comments()
			if cur() and cur().type == M.TT.COMMA then
				advance()
				skip_comments()
			else
				break
			end
		end

		return { resource_ids = rids, has_each_qty = has_each_qty }
	end

	local function parse_label_access()
		local labels = {}
		local round_robin = nil

		skip_comments()
		local lbl = parse_label()
		if lbl then
			table.insert(labels, lbl)
		end

		skip_comments()
		while cur() and cur().type == M.TT.COMMA do
			advance()
			skip_comments()
			local t = cur()
			if not t then
				break
			end
			if t.type == M.TT.IDENT then
				local u = t.upper
				if
					u == "ROUND"
					or u == "SIDE"
					or u == "SLOT"
					or u == "SLOTS"
					or u == "TOP"
					or u == "BOTTOM"
					or u == "NORTH"
					or u == "EAST"
					or u == "SOUTH"
					or u == "WEST"
					or u == "LEFT"
					or u == "RIGHT"
					or u == "FRONT"
					or u == "BACK"
					or u == "NULL"
					or u == "EACH"
				then
					break
				end
			end
			lbl = parse_label()
			if lbl then
				table.insert(labels, lbl)
			end
			skip_comments()
		end

		skip_comments()
		if cur() and cur().type == M.TT.IDENT and cur().upper == "ROUND" then
			advance()
			skip_comments()
			if cur() and cur().type == M.TT.IDENT and cur().upper == "ROBIN" then
				advance()
				skip_comments()
				if cur() and cur().type == M.TT.IDENT and cur().upper == "BY" then
					advance()
					skip_comments()
					if cur() and cur().type == M.TT.IDENT then
						round_robin = cur().upper == "BLOCK" and "BY_BLOCK" or "BY_LABEL"
						advance()
					end
				end
			end
		end

		-- Side qualifier
		skip_comments()
		if cur() and cur().type == M.TT.IDENT then
			local u = cur().upper
			local SIDES = {
				TOP = true,
				BOTTOM = true,
				NORTH = true,
				EAST = true,
				SOUTH = true,
				WEST = true,
				LEFT = true,
				RIGHT = true,
				FRONT = true,
				BACK = true,
				NULL = true,
			}
			if u == "EACH" then
				local save = pos
				advance()
				skip_comments()
				if cur() and cur().type == M.TT.IDENT and cur().upper == "SIDE" then
					advance()
				else
					pos = save
				end
			elseif SIDES[u] then
				while cur() and cur().type == M.TT.IDENT and SIDES[cur().upper] do
					advance()
					skip_comments()
					if cur() and cur().type == M.TT.COMMA then
						advance()
						skip_comments()
					end
				end
				if cur() and cur().type == M.TT.IDENT and cur().upper == "SIDE" then
					advance()
				end
			end
		end

		-- Slot qualifier
		skip_comments()
		if cur() and cur().type == M.TT.IDENT and (cur().upper == "SLOT" or cur().upper == "SLOTS") then
			advance()
			skip_comments()
			repeat
				if cur() and cur().type == M.TT.NUMBER then
					advance()
				end
				skip_comments()
				if cur() and cur().type == M.TT.DASH then
					advance()
					skip_comments()
					if cur() and cur().type == M.TT.NUMBER then
						advance()
					end
				end
				skip_comments()
				if cur() and cur().type == M.TT.COMMA then
					advance()
					skip_comments()
				else
					break
				end
			until false
		end

		return { labels = labels, round_robin = round_robin }
	end

	local function parse_io_statement(kind, stmt_line, stmt_col, reversed)
		local stmt = {
			kind = kind,
			each = false,
			each_on_quantity = false,
			labels = {},
			resource_ids = {},
			round_robin = nil,
			empty_slots = false,
			line = stmt_line,
			col = stmt_col,
		}

		local function parse_limits_section()
			skip_comments()
			local limits = parse_resource_limits()
			stmt.resource_ids = limits.resource_ids
			stmt.each_on_quantity = limits.has_each_qty
		end

		local function parse_from_to_section()
			skip_comments()
			if kind == "output" and cur() and cur().type == M.TT.IDENT and cur().upper == "EMPTY" then
				advance()
				skip_comments()
				if cur() and cur().type == M.TT.IDENT and (cur().upper == "SLOTS" or cur().upper == "SLOT") then
					advance()
					skip_comments()
				end
				if cur() and cur().type == M.TT.IDENT and cur().upper == "IN" then
					advance()
					skip_comments()
				end
				stmt.empty_slots = true
			end

			if cur() and cur().type == M.TT.IDENT and cur().upper == "EACH" then
				local save = pos
				advance()
				skip_comments()
				if cur() and cur().type == M.TT.IDENT and cur().upper == "SIDE" then
					pos = save
				else
					stmt.each = true
				end
			end

			local la = parse_label_access()
			stmt.labels = la.labels
			stmt.round_robin = la.round_robin
		end

		if kind == "input" then
			if reversed then
				parse_from_to_section()
				skip_comments()
				if cur() and cur().type == M.TT.IDENT and cur().upper == "INPUT" then
					advance()
				end
				parse_limits_section()
			else
				parse_limits_section()
				skip_comments()
				if cur() and cur().type == M.TT.IDENT and cur().upper == "FROM" then
					advance()
				end
				parse_from_to_section()
			end
		else
			if reversed then
				parse_from_to_section()
				skip_comments()
				if cur() and cur().type == M.TT.IDENT and cur().upper == "OUTPUT" then
					advance()
				end
				parse_limits_section()
			else
				parse_limits_section()
				skip_comments()
				if cur() and cur().type == M.TT.IDENT and cur().upper == "TO" then
					advance()
				end
				parse_from_to_section()
			end
		end

		return stmt
	end

	local function parse_block_contents(depth)
		local stmts = {}
		local forget_points = {}

		while cur() and cur().type ~= M.TT.EOF do
			skip_comments()
			local t = cur()
			if not t or t.type == M.TT.EOF then
				break
			end
			if t.type == M.TT.IDENT and (t.upper == "END" or t.upper == "ELSE") then
				break
			end

			if t.type == M.TT.IDENT and t.upper == "INPUT" then
				local ln, cl = t.line, t.col
				advance()
				table.insert(stmts, parse_io_statement("input", ln, cl, false))
			elseif t.type == M.TT.IDENT and t.upper == "FROM" then
				local ln, cl = t.line, t.col
				advance()
				table.insert(stmts, parse_io_statement("input", ln, cl, true))
			elseif t.type == M.TT.IDENT and t.upper == "OUTPUT" then
				local ln, cl = t.line, t.col
				advance()
				table.insert(stmts, parse_io_statement("output", ln, cl, false))
			elseif t.type == M.TT.IDENT and t.upper == "TO" then
				local ln, cl = t.line, t.col
				advance()
				table.insert(stmts, parse_io_statement("output", ln, cl, true))
			elseif t.type == M.TT.IDENT and t.upper == "FORGET" then
				advance()
				local forget_labels = {}
				skip_comments()
				local FORGET_STOP = {
					END = true,
					ELSE = true,
					INPUT = true,
					OUTPUT = true,
					FROM = true,
					TO = true,
					IF = true,
					EVERY = true,
					FORGET = true,
					DO = true,
					THEN = true,
				}
				local function is_forget_label()
					local ft = cur()
					if not ft then
						return false
					end
					if ft.type == M.TT.STRING then
						return true
					end
					if ft.type == M.TT.IDENT then
						return not FORGET_STOP[ft.upper]
					end
					return false
				end
				if is_forget_label() then
					local lbl = parse_label()
					if lbl then
						table.insert(forget_labels, lbl)
						skip_comments()
						while cur() and cur().type == M.TT.COMMA do
							advance()
							skip_comments()
							if is_forget_label() then
								local nl = parse_label()
								if nl then
									table.insert(forget_labels, nl)
								end
							else
								break
							end
							skip_comments()
						end
					end
				end
				table.insert(forget_points, { labels = forget_labels, stmt_index = #stmts })
			elseif t.type == M.TT.IDENT and t.upper == "IF" then
				local if_tok = t
				advance()

				-- ── Parse & validate the boolean expression ──────────────────────
				-- Grammar (simplified):
				--   boolexpr = boolAtom ((AND|OR) boolAtom)*
				--   boolAtom = NOT? (TRUE | FALSE | label HAS hasExpr+)
				--   hasExpr  = setOp? cmpOp? NUMBER resourceId
				--            | cmpOp NUMBER resourceId
				-- We validate:
				--   1. Label names are not reserved keywords (like LABEL, BLOCK, etc.)
				--   2. HAS must be followed by a comparison operator or quantity, not bare resource
				--   3. AND/OR must be followed by a complete atom (label HAS ...)
				--   4. Condition must end with THEN

				-- Keywords that CANNOT be label names in an IF condition
				local COND_LABEL_STOP = {
					HAS = true,
					AND = true,
					OR = true,
					NOT = true,
					THEN = true,
					END = true,
					ELSE = true,
					DO = true,
					TRUE = true,
					FALSE = true,
					OVERALL = true,
					SOME = true,
					EVERY = true,
					ONE = true,
					LONE = true,
					INPUT = true,
					OUTPUT = true,
					FROM = true,
					TO = true,
					FORGET = true,
					ROUND = true,
					ROBIN = true,
					BY = true,
					LABEL = true,
					BLOCK = true,
					SLOT = true,
					SLOTS = true,
					EMPTY = true,
					RETAIN = true,
					EXCEPT = true,
					WITH = true,
					WITHOUT = true,
					TAG = true,
				}

				-- Comparison operator tokens
				local function is_cmp_op()
					local t2 = cur()
					if not t2 then
						return false
					end
					if
						t2.type == M.TT.GT
						or t2.type == M.TT.LT
						or t2.type == M.TT.GTE
						or t2.type == M.TT.LTE
						or t2.type == M.TT.EQ
					then
						return true
					end
					if t2.type == M.TT.IDENT then
						local u2 = t2.upper
						return u2 == "GT" or u2 == "LT" or u2 == "EQ" or u2 == "LE" or u2 == "GE"
					end
					return false
				end

				local function is_set_op()
					local t2 = cur()
					if not t2 or t2.type ~= M.TT.IDENT then
						return false
					end
					local u2 = t2.upper
					return u2 == "OVERALL"
						or u2 == "SOME"
						or u2 == "EVERY"
						or u2 == "ONE"
						or u2 == "LONE"
						or u2 == "EACH"
				end

				-- Parse one HAS clause: setOp? cmpOp? NUMBER? resourceId
				-- Returns true if successfully parsed at least something
				local function parse_has_clause(label_tok)
					skip_comments()
					-- optional set op
					if is_set_op() then
						advance()
						skip_comments()
					end

					-- must have cmp op OR number, not just bare resource name
					local has_cmp = is_cmp_op()
					local has_num = cur() and (cur().type == M.TT.NUMBER or cur().type == M.TT.NUMBER_G)

					if not has_cmp and not has_num then
						-- bare resource without quantity/operator is only valid with 0 implicit
						-- but the game requires an explicit operator with 0
						-- peek: is next token a resource-like ident?
						local t2 = cur()
						if
							t2
							and t2.type == M.TT.IDENT
							and not COND_LABEL_STOP[t2.upper]
							and t2.upper ~= "THEN"
							and t2.upper ~= "AND"
							and t2.upper ~= "OR"
						then
							-- bare resource - this is actually valid (HAS any of this resource)
							-- don't error, just consume the resource id
						end
					end

					if has_cmp then
						advance()
						skip_comments()
					end

					-- optional number
					if cur() and (cur().type == M.TT.NUMBER or cur().type == M.TT.NUMBER_G) then
						if not has_cmp then
							add_error(
								("HAS %s requires a comparison operator (e.g. HAS = %s, HAS < %s, HAS <= %s)"):format(
									cur().value,
									cur().value,
									cur().value,
									cur().value
								),
								cur(),
								"error"
							)
						end
						advance()
						skip_comments()
					end

					-- consume resource id
					parse_resource_id()
					return true
				end

				-- Parse one bool atom: NOT? (TRUE|FALSE | label HAS hasClause+)
				local function parse_bool_atom()
					skip_comments()
					if not cur() or cur().type == M.TT.EOF then
						return
					end

					-- NOT
					if cur().type == M.TT.IDENT and cur().upper == "NOT" then
						advance()
						skip_comments()
					end

					-- TRUE / FALSE
					if cur() and cur().type == M.TT.IDENT and (cur().upper == "TRUE" or cur().upper == "FALSE") then
						advance()
						return
					end

					-- LPAREN grouping
					if cur() and cur().type == M.TT.LPAREN then
						advance()
						-- recurse: parse until RPAREN
						while cur() and cur().type ~= M.TT.EOF do
							local u2 = cur().type == M.TT.IDENT and cur().upper
							if cur().type == M.TT.RPAREN then
								advance()
								break
							end
							if u2 == "AND" or u2 == "OR" then
								advance()
								skip_comments()
							else
								parse_bool_atom()
							end
							skip_comments()
						end
						return
					end

					-- label
					local label_tok = cur()
					if not label_tok or label_tok.type == M.TT.EOF then
						return
					end

					-- Check label is not a reserved keyword that can't be a label
					if label_tok.type == M.TT.IDENT and COND_LABEL_STOP[label_tok.upper] then
						add_error(
							("'%s' is a reserved keyword and cannot be used as a label name"):format(label_tok.value),
							label_tok,
							"error"
						)
						-- don't advance, let the outer loop handle recovery
						return
					end

					-- consume label (string or ident)
					if label_tok.type == M.TT.STRING or label_tok.type == M.TT.IDENT then
						advance()
						all_labels[label_tok.value:lower()] = true
					end
					skip_comments()

					-- expect HAS
					if cur() and cur().type == M.TT.IDENT and cur().upper == "HAS" then
						advance()
						skip_comments()
						-- must be followed by a valid has clause, not AND/OR/THEN
						local next_t = cur()
						if not next_t or next_t.type == M.TT.EOF then
							add_error("Expected condition after HAS", next_t, "error")
							return
						end
						if
							next_t.type == M.TT.IDENT
							and (next_t.upper == "AND" or next_t.upper == "OR" or next_t.upper == "THEN")
						then
							add_error("Expected quantity or comparison after HAS", next_t, "error")
							return
						end
						parse_has_clause(label_tok)
					else
						-- label with no HAS: valid for redstone checks, but warn if followed
						-- by AND/OR/THEN since that almost always means a missing HAS clause
						local next_t = cur()
						if
							next_t
							and next_t.type == M.TT.IDENT
							and (next_t.upper == "AND" or next_t.upper == "OR" or next_t.upper == "THEN")
						then
							add_error(
								("Label '%s' has no HAS clause — did you mean '%s HAS ...'?"):format(
									label_tok.value,
									label_tok.value
								),
								label_tok,
								"error"
							)
						end
					end
				end

				-- Parse full boolexpr: atom (AND|OR atom)* THEN
				local found_then = false
				parse_bool_atom()
				skip_comments()

				while cur() and cur().type ~= M.TT.EOF do
					local u = cur().type == M.TT.IDENT and cur().upper
					if u == "THEN" then
						advance()
						found_then = true
						break
					elseif u == "AND" or u == "OR" then
						advance()
						skip_comments()
						-- next must be a valid atom start, not THEN
						if cur() and cur().type == M.TT.IDENT and cur().upper == "THEN" then
							add_error(("'%s' must be followed by a condition, not THEN"):format(u), cur(), "error")
							advance()
							found_then = true
							break
						end
						parse_bool_atom()
						skip_comments()
					elseif u == "END" or u == "ELSE" or u == "INPUT" or u == "OUTPUT" then
						-- probably missing THEN
						add_error("Expected THEN to close IF condition", cur(), "error")
						found_then = true
						break
					else
						-- skip unknown tokens in condition (recovery)
						advance()
						skip_comments()
					end
				end

				if not found_then then
					add_error("Expected THEN to close IF condition", if_tok, "error")
				end
				-- ── End boolexpr ─────────────────────────────────────────────────

				local if_block = parse_block_contents(depth + 1)
				local base_idx = #stmts
				for _, s in ipairs(if_block.statements) do
					table.insert(stmts, s)
				end
				for _, f in ipairs(if_block.forget_points) do
					table.insert(forget_points, { labels = f.labels, stmt_index = base_idx + f.stmt_index })
				end

				skip_comments()
				while cur() and cur().type == M.TT.IDENT and cur().upper == "ELSE" do
					advance()
					skip_comments()
					if cur() and cur().type == M.TT.IDENT and cur().upper == "IF" then
						advance()
						skip_comments()
						-- parse ELSE IF condition the same way
						parse_bool_atom()
						skip_comments()
						while cur() and cur().type ~= M.TT.EOF do
							local u2 = cur().type == M.TT.IDENT and cur().upper
							if u2 == "THEN" then
								advance()
								break
							elseif u2 == "AND" or u2 == "OR" then
								advance()
								skip_comments()
								parse_bool_atom()
								skip_comments()
							else
								advance()
								skip_comments()
							end
						end
					end
					local else_base_idx = #stmts
					local else_block = parse_block_contents(depth + 1)
					for _, s in ipairs(else_block.statements) do
						table.insert(stmts, s)
					end
					for _, f in ipairs(else_block.forget_points) do
						table.insert(forget_points, { labels = f.labels, stmt_index = else_base_idx + f.stmt_index })
					end
					skip_comments()
				end

				if cur() and cur().type == M.TT.IDENT and cur().upper == "END" then
					advance()
				else
					add_error("Expected END to close IF block", cur())
				end
			else
				advance()
			end

			skip_comments()
		end

		return { statements = stmts, forget_points = forget_points }
	end

	-- ── Top-level parse ─────────────────────────────────────────────────────────
	local triggers = {}
	skip_comments()

	if cur() and cur().type == M.TT.IDENT and cur().upper == "NAME" then
		advance()
		skip_comments()
		if cur() and cur().type == M.TT.STRING then
			advance()
		end
	end

	skip_comments()

	while cur() and cur().type ~= M.TT.EOF do
		skip_comments()
		local t = cur()
		if not t or t.type == M.TT.EOF then
			break
		end

		if t.type == M.TT.IDENT and t.upper == "EVERY" then
			local trigger_line = t.line
			advance()
			skip_comments()

			local trigger = {
				kind = "timer",
				interval_ticks = nil,
				interval_is_global = false,
				statements = {},
				forget_points = {},
				line = trigger_line,
			}

			if cur() and cur().type == M.TT.IDENT and cur().upper == "REDSTONE" then
				trigger.kind = "redstone"
				advance()
				skip_comments()
				if cur() and cur().type == M.TT.IDENT and cur().upper == "PULSE" then
					advance()
				end
			else
				local ticks = 1
				local is_global = false

				if cur() and cur().type == M.TT.NUMBER_G then
					local raw = cur().value
					ticks = tonumber(raw:sub(1, #raw - 1)) or 1
					is_global = true
					advance()
					skip_comments()
				elseif cur() and cur().type == M.TT.NUMBER then
					ticks = tonumber(cur().value) or 1
					advance()
					skip_comments()
					if cur() and cur().type == M.TT.IDENT and cur().upper == "GLOBAL" then
						is_global = true
						advance()
						skip_comments()
					end
				else
					if cur() and cur().type == M.TT.IDENT and cur().upper == "GLOBAL" then
						is_global = true
						advance()
						skip_comments()
					end
				end

				if cur() and (cur().type == M.TT.PLUS or (cur().type == M.TT.IDENT and cur().upper == "PLUS")) then
					advance()
					skip_comments()
					if cur() and cur().type == M.TT.NUMBER then
						advance()
						skip_comments()
					end
				end

				if cur() and cur().type == M.TT.IDENT then
					local u = cur().upper
					if u == "SECONDS" or u == "SECOND" then
						ticks = ticks * 20
					end
					if u == "TICKS" or u == "TICK" or u == "SECONDS" or u == "SECOND" then
						advance()
					end
				end

				trigger.interval_ticks = ticks
				trigger.interval_is_global = is_global
			end

			skip_comments()
			if cur() and cur().type == M.TT.IDENT and cur().upper == "DO" then
				advance()
			else
				add_error("Expected DO after interval", cur())
			end

			local block = parse_block_contents(1)
			trigger.statements = block.statements
			trigger.forget_points = block.forget_points

			skip_comments()
			if cur() and cur().type == M.TT.IDENT and cur().upper == "END" then
				advance()
			else
				add_error("Expected END to close EVERY...DO block", cur())
			end

			table.insert(triggers, trigger)
		else
			add_error("Unexpected token '" .. t.value .. "' at top level", t)
			advance()
		end

		skip_comments()
	end

	local label_list = {}
	for name, _ in pairs(all_labels) do
		table.insert(label_list, name)
	end

	return { triggers = triggers, errors = errors, labels = label_list }
end

return M
