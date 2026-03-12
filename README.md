# nvim-sfml

A smart Neovim plugin for **Super Factory Manager Language** (`.sfml` / `.sfm` files).

Built from the actual mod source code (1.21.1 branch SFML.g4 + linter Java sources) — not from the VSCode extension.

## Features

- **Syntax highlighting** — full keyword coverage, resource IDs, strings, comments, numbers, operators
- **Static linting** (`:SFMLLint`) — mirrors the mod's own `IProgramLinter` suite:
  - `EACH` used without a wildcard pattern → warning
  - `ROUND ROBIN BY BLOCK` + `EACH` together → warning
  - `ROUND ROBIN BY LABEL` with only 1 label → warning
  - OUTPUT resource type with no matching INPUT → warning
  - INPUT resource type with no matching OUTPUT → warning
  - `EVERY TICK DO` with non-energy resources → error
  - Timer interval below minimum → error
  - Unknown resource type prefix → warning
  - Label names exceeding 256 characters → error
  - Unclosed `DO`/`END` / `IF`/`END` blocks → error
  - INPUT forgotten (via `FORGET`) without being OUTPUT'd → warning
- **Live diagnostics** — lints on every text change (debounced 400ms) and on save
- **Completions** (via `nvim-cmp` or built-in `omnifunc`):
  - All keywords with context-awareness
  - Resource type prefixes (`item::`, `fluid::`, `forge_energy::`, `fe::`, etc.)
  - Label names collected from the current buffer
  - Snippet-style insertion for `EVERY...DO...END`, `IF...THEN...END`
- **Folding** — `EVERY...END` and `IF...END` blocks fold naturally
- **Indentation** — 4-space, auto-configured
- **Formatter** (`:SFMLFormat`) — normalizes all keywords to uppercase, preserves resource IDs and strings

## Requirements

- Neovim ≥ 0.8
- Optional: [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) for completion integration

## Installation

```lua
-- lazy.nvim
{
  dir = "~/path/to/nvim-sfml",
  ft  = { "sfml", "sfm" },
  config = function()
    require("sfml").setup({
      -- All options are optional
      auto_lint      = true,    -- live lint on change
      lint_delay_ms  = 400,     -- debounce ms
      format_on_save = false,   -- auto-uppercase keywords on write
      register_cmp   = true,    -- register nvim-cmp source
    })
  end,
}
```

If using `nvim-cmp`, add `"sfml"` to your sources:

```lua
require("cmp").setup({
  sources = {
    { name = "sfml" },
    -- ... your other sources
  },
})
```

## Commands

| Command       | Description                           |
| ------------- | ------------------------------------- |
| `:SFMLLint`   | Run linter and populate quickfix list |
| `:SFMLFormat` | Normalize all keywords to uppercase   |

## Resource Type Reference

| SFML syntax         | Aliases                               |
| ------------------- | ------------------------------------- |
| `item::`            | _(default, implicit)_                 |
| `fluid::`           | —                                     |
| `forge_energy::`    | `fe::`, `rf::`, `energy::`, `power::` |
| `chemical::`        | `gas::`, `infusion::`                 |
| `mekanism_energy::` | —                                     |
| `redstone::`        | —                                     |

## Grammar Notes (from actual mod source)

- Keywords are **case-insensitive** (formatter normalizes to uppercase)
- Resource IDs use `*` as a glob wildcard (converted to `.*` regex internally)
- `::` suffix means "match all of this type" (e.g., `fluid::` = all fluids)
- `fluid::minecraft:water` = specific fluid with namespace
- Labels can be bare identifiers or quoted strings
- Labels named `TOP`, `BOTTOM`, `LEFT`, `RIGHT`, `FRONT`, `BACK`, `REDSTONE`, `GLOBAL`, `SECOND`, `SECONDS` are valid (included in the grammar's `identifier` rule)
- `FORGET` with no labels forgets **all** tracked labels
- `EVERY TICK DO` only allows `forge_energy` / `mekanism_energy` resource types
- Both `INPUT x FROM label` and `FROM label INPUT x` forms are valid
- Both `OUTPUT x TO label` and `TO label OUTPUT x` forms are valid
