" Vim syntax file for Super Factory Manager Language (SFML)
" Based on actual mod source: SFML.g4 (1.21.1 branch)
" Maintainer: nvim-sfml

if exists("b:current_syntax")
  finish
endif

" Case insensitive matching - the grammar uses case-insensitive lexer rules
syntax case ignore

" ─── Comments ────────────────────────────────────────────────────────────────
syntax match sfmlComment "--.*$" contains=sfmlTodo
syntax keyword sfmlTodo TODO FIXME NOTE HACK contained

" ─── Strings ─────────────────────────────────────────────────────────────────
syntax region sfmlString start='"' end='"' skip='\\"' oneline

" ─── Numbers ─────────────────────────────────────────────────────────────────
" NUMBER_WITH_G_SUFFIX (global alignment): 20g, 100G
syntax match sfmlNumberG '\<[0-9]\+[gG]\>'
" Plain numbers
syntax match sfmlNumber  '\<[0-9]\+\>'

" ─── Program-level keywords ──────────────────────────────────────────────────
syntax keyword sfmlProgramKw NAME

" ─── Trigger keywords ────────────────────────────────────────────────────────
syntax keyword sfmlTrigger EVERY DO END REDSTONE PULSE

" ─── Interval keywords ───────────────────────────────────────────────────────
syntax keyword sfmlInterval TICKS TICK SECONDS SECOND GLOBAL PLUS

" ─── IO Statement keywords ───────────────────────────────────────────────────
syntax keyword sfmlIO INPUT OUTPUT FROM TO EACH RETAIN FORGET EXCEPT
syntax keyword sfmlIO EMPTY SLOTS SLOT IN WHERE

" ─── Resource type prefixes ──────────────────────────────────────────────────
syntax match sfmlResourceType '\<\(item\|fluid\|forge_energy\|fe\|rf\|energy\|power\|chemical\|gas\|infusion\|mekanism_energy\|redstone\)\s*::'
" Full resource identifier: namespace:name or type::ns:name
syntax match sfmlResourceId '\<[a-zA-Z_*][a-zA-Z0-9_*]*\(\s*:\s*[a-zA-Z_*][a-zA-Z0-9_*]*\)\{1,3\}'

" ─── WITH / WITHOUT / TAG clause ─────────────────────────────────────────────
syntax keyword sfmlWith WITH WITHOUT TAG
syntax match   sfmlHashtag '#'

" ─── Condition keywords ──────────────────────────────────────────────────────
syntax keyword sfmlCondition IF THEN ELSE
syntax keyword sfmlBoolLit   TRUE FALSE
syntax keyword sfmlBoolOp    NOT AND OR
syntax keyword sfmlHas       HAS
syntax keyword sfmlSetOp     OVERALL SOME ONE LONE

" ─── Comparison operators ────────────────────────────────────────────────────
syntax keyword sfmlCompKw GT LT EQ LE GE
syntax match   sfmlCompSym '[><=][=]\?'

" ─── Round-robin ─────────────────────────────────────────────────────────────
syntax keyword sfmlRoundRobin ROUND ROBIN BY LABEL BLOCK

" ─── Side qualifiers ─────────────────────────────────────────────────────────
syntax keyword sfmlSide TOP BOTTOM NORTH EAST SOUTH WEST LEFT RIGHT FRONT BACK NULL SIDE

" ─── Punctuation ─────────────────────────────────────────────────────────────
syntax match sfmlPunct '[,:/\-()]'
syntax match sfmlWildcard '\*'

" ─── Highlight links ─────────────────────────────────────────────────────────
highlight default link sfmlComment       Comment
highlight default link sfmlTodo          Todo
highlight default link sfmlString        String
highlight default link sfmlNumber        Number
highlight default link sfmlNumberG       Special
highlight default link sfmlProgramKw     Statement
highlight default link sfmlTrigger       Keyword
highlight default link sfmlInterval      Constant
highlight default link sfmlIO            Statement
highlight default link sfmlResourceType  Type
highlight default link sfmlResourceId    Identifier
highlight default link sfmlWith          Keyword
highlight default link sfmlHashtag       Operator
highlight default link sfmlCondition     Conditional
highlight default link sfmlBoolLit       Boolean
highlight default link sfmlBoolOp        Operator
highlight default link sfmlHas           Keyword
highlight default link sfmlSetOp         Keyword
highlight default link sfmlCompKw        Operator
highlight default link sfmlCompSym       Operator
highlight default link sfmlRoundRobin    Keyword
highlight default link sfmlSide          Constant
highlight default link sfmlPunct         Delimiter
highlight default link sfmlWildcard      Special

let b:current_syntax = "sfml"
