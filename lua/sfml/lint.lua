-- lua/sfml/lint.lua
-- Static linter for SFML, mirroring the mod's own IProgramLinter suite.

local parser = require("sfml.parser")
local M = {}

local NS = vim.api.nvim_create_namespace("sfml_lint")

local VALID_RESOURCE_TYPES = {
	item = true,
	fluid = true,
	forge_energy = true,
	redstone = true,
	chemical = true,
	gas = true,
	infusion = true,
	mekanism_energy = true,
}
local FORGE_ENERGY_ALIASES = { fe = true, rf = true, energy = true, power = true }
local ENERGY_TYPES = { forge_energy = true, mekanism_energy = true }

local function is_energy_type(type_name)
	return ENERGY_TYPES[type_name] or false
end

local function uses_wildcard(rid)
	local function has_regex(s)
		return s:find("[%.%?%*%+%^%$%[%]%(%)%{%}%|\\]") ~= nil
	end
	return has_regex(rid.res_ns) or has_regex(rid.res_name)
end

local function lint(source)
	local result = parser.parse(source)
	local diags = {}

	for _, err in ipairs(result.errors) do
		table.insert(diags, {
			msg = err.msg,
			line = err.line,
			col = err.col,
			severity = err.severity or "error",
		})
	end

	for _, trigger in ipairs(result.triggers) do
		-- 1. Interval validation
		if trigger.kind == "timer" and trigger.interval_ticks ~= nil then
			local ticks = trigger.interval_ticks
			local only_energy = true
			local has_any_io = false

			for _, stmt in ipairs(trigger.statements) do
				has_any_io = true
				for _, rid in ipairs(stmt.resource_ids) do
					if not is_energy_type(rid.type_name) then
						only_energy = false
					end
				end
				if #stmt.resource_ids == 0 then
					only_energy = false
				end
			end
			if not has_any_io then
				only_energy = false
			end

			if ticks < 1 then
				table.insert(diags, {
					msg = "Minimum trigger interval is 1 tick",
					line = trigger.line,
					col = 0,
					severity = "error",
				})
			end

			if ticks == 1 and not only_energy and has_any_io then
				table.insert(diags, {
					msg = "EVERY TICK DO is only allowed for forge_energy/mekanism_energy resource transfers",
					line = trigger.line,
					col = 0,
					severity = "error",
				})
			end
		end

		-- 2. Per-statement linting
		for _, stmt in ipairs(trigger.statements) do
			-- Label length
			for _, lbl in ipairs(stmt.labels) do
				if #lbl > 256 then
					table.insert(diags, {
						msg = ("Label '%s' exceeds maximum length of 256 characters"):format(lbl),
						line = stmt.line,
						col = stmt.col or 0,
						severity = "error",
					})
				end
			end

			-- EACH without wildcard pattern
			if stmt.each_on_quantity then
				local any_wildcard = false
				for _, rid in ipairs(stmt.resource_ids) do
					if uses_wildcard(rid) then
						any_wildcard = true
						break
					end
				end
				if not any_wildcard then
					table.insert(diags, {
						msg = ("EACH used on quantity without a wildcard/pattern resource ID in %s statement"):format(
							stmt.kind:upper()
						),
						line = stmt.line,
						col = stmt.col or 0,
						severity = "warning",
					})
				end
			end

			-- Round robin checks
			if stmt.round_robin == "BY_BLOCK" and stmt.each then
				table.insert(diags, {
					msg = "ROUND ROBIN BY BLOCK should not be used together with EACH",
					line = stmt.line,
					col = stmt.col or 0,
					severity = "warning",
				})
			end

			if stmt.round_robin == "BY_LABEL" and #stmt.labels == 1 then
				table.insert(diags, {
					msg = "ROUND ROBIN BY LABEL should be used with more than one label",
					line = stmt.line,
					col = stmt.col or 0,
					severity = "warning",
				})
			end

			-- Unknown resource type
			for _, rid in ipairs(stmt.resource_ids) do
				local tn = rid.type_name
				if not VALID_RESOURCE_TYPES[tn] and not FORGE_ENERGY_ALIASES[tn] then
					if not tn:find("[%.%*]") then
						table.insert(diags, {
							msg = ("Unknown resource type '%s' (expected: item, fluid, forge_energy, chemical, redstone)"):format(
								tn
							),
							line = stmt.line,
							col = stmt.col or 0,
							severity = "warning",
						})
					end
				end
			end
		end

		-- 3. Incomplete IO flow analysis (IncompleteIOProgramLinter)
		local events = {}
		for i, stmt in ipairs(trigger.statements) do
			table.insert(events, { kind = "stmt", stmt = stmt, idx = i })
		end
		for _, fp in ipairs(trigger.forget_points) do
			table.insert(events, { kind = "forget", labels = fp.labels, after_idx = fp.stmt_index })
		end
		table.sort(events, function(a, b)
			local ai = a.idx or (a.after_idx + 0.5)
			local bi = b.idx or (b.after_idx + 0.5)
			return ai < bi
		end)

		local function get_type_names(stmt)
			local types = {}
			if #stmt.resource_ids == 0 then
				types["item"] = true
			else
				for _, rid in ipairs(stmt.resource_ids) do
					types[rid.type_name] = true
				end
			end
			return types
		end

		local inputted_types = {}
		local outputted_types = {}

		for _, ev in ipairs(events) do
			if ev.kind == "stmt" then
				local stmt = ev.stmt
				local type_names = get_type_names(stmt)

				if stmt.kind == "input" then
					for tn, _ in pairs(type_names) do
						if not inputted_types[tn] then
							inputted_types[tn] = {}
						end
						for _, lbl in ipairs(stmt.labels) do
							inputted_types[tn][lbl] = true
						end
					end
				elseif stmt.kind == "output" then
					for tn, _ in pairs(type_names) do
						if not inputted_types[tn] then
							table.insert(diags, {
								msg = ("OUTPUT uses resource type '%s' but no preceding INPUT provides it"):format(tn),
								line = stmt.line,
								col = stmt.col or 0,
								severity = "warning",
							})
						end
						outputted_types[tn] = true
					end
				end
			elseif ev.kind == "forget" then
				if #ev.labels == 0 then
					for tn, labels in pairs(inputted_types) do
						if not outputted_types[tn] then
							for lbl, _ in pairs(labels) do
								table.insert(diags, {
									msg = ("INPUT from '%s' with type '%s' is forgotten but never OUTPUT'd"):format(
										lbl,
										tn
									),
									line = trigger.line,
									col = 0,
									severity = "warning",
								})
							end
						end
					end
					inputted_types = {}
					outputted_types = {}
				else
					local forget_set = {}
					for _, lbl in ipairs(ev.labels) do
						forget_set[lbl] = true
					end
					for tn, labels in pairs(inputted_types) do
						for lbl, _ in pairs(labels) do
							if forget_set[lbl] then
								if not outputted_types[tn] then
									table.insert(diags, {
										msg = ("INPUT from '%s' with type '%s' is forgotten but never OUTPUT'd"):format(
											lbl,
											tn
										),
										line = trigger.line,
										col = 0,
										severity = "warning",
									})
								end
								labels[lbl] = nil
							end
						end
						if next(labels) == nil then
							inputted_types[tn] = nil
						end
					end
				end
			end
		end

		-- End-of-trigger: un-outputted inputs
		for tn, labels in pairs(inputted_types) do
			if not outputted_types[tn] then
				for lbl, _ in pairs(labels) do
					table.insert(diags, {
						msg = ("INPUT from '%s' with type '%s' is never OUTPUT'd in this trigger"):format(lbl, tn),
						line = trigger.line,
						col = 0,
						severity = "warning",
					})
				end
			end
		end
	end -- for each trigger

	return diags
end

-- ─── Public API ───────────────────────────────────────────────────────────────

local function to_vim_severity(s)
	if s == "error" then
		return vim.diagnostic.severity.ERROR
	elseif s == "warning" then
		return vim.diagnostic.severity.WARN
	elseif s == "info" then
		return vim.diagnostic.severity.INFO
	else
		return vim.diagnostic.severity.HINT
	end
end

function M.run_and_set_diagnostics(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local source = table.concat(lines, "\n")

	local ok, diags = pcall(lint, source)
	if not ok then
		vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
		vim.notify("[sfml] Linter internal error: " .. tostring(diags), vim.log.levels.ERROR)
		return
	end

	local vim_diags = {}
	for _, d in ipairs(diags) do
		local lnum = math.max(0, (d.line or 1) - 1)
		local col = math.max(0, d.col or 0)
		table.insert(vim_diags, {
			lnum = lnum,
			col = col,
			message = d.msg,
			severity = to_vim_severity(d.severity),
			source = "sfml",
		})
	end

	vim.diagnostic.set(NS, bufnr, vim_diags, {})
end

function M.run_and_populate_qf(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local source = table.concat(lines, "\n")

	local ok, diags = pcall(lint, source)
	if not ok then
		vim.notify("[sfml] Linter error: " .. tostring(diags), vim.log.levels.ERROR)
		return
	end

	if #diags == 0 then
		vim.notify("[sfml] No problems found.", vim.log.levels.INFO)
		return
	end

	local qf_items = {}
	local fname = vim.api.nvim_buf_get_name(bufnr)
	for _, d in ipairs(diags) do
		table.insert(qf_items, {
			filename = fname,
			lnum = d.line or 1,
			col = (d.col or 0) + 1,
			text = ("[%s] %s"):format((d.severity or "error"):upper(), d.msg),
			type = d.severity == "error" and "E" or "W",
		})
	end

	vim.fn.setqflist(qf_items, "r")
	vim.cmd("copen")
end

return M
